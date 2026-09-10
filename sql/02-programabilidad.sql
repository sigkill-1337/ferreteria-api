-- =========================================================
-- Ferreteria - 02: procedimientos almacenados y triggers
--
-- Nota sobre TRY/CATCH: es sintaxis de SQL Server. En MariaDB/MySQL el
-- equivalente es DECLARE ... HANDLER para atrapar el error y SIGNAL para
-- lanzarlo. Es lo que se usa aqui.
-- =========================================================

USE ferreteria;

DROP PROCEDURE IF EXISTS sp_ventas_del_dia;
DROP PROCEDURE IF EXISTS sp_clientes_vigentes_trimestre;
DROP PROCEDURE IF EXISTS sp_alta_cliente;
DROP TRIGGER IF EXISTS trg_producto_no_duplicado_ins;
DROP TRIGGER IF EXISTS trg_producto_no_duplicado_upd;
DROP TRIGGER IF EXISTS trg_venta_seguimiento;

DELIMITER $$

-- ---------------------------------------------------------
-- 1. Ventas de un dia
--
-- Recibe una fecha y devuelve DOS resultados:
--   a) el desglose de las ventas de ese dia
--   b) el resumen agrupado, con la suma de todos los montos
--
-- Se compara con DATE(v.fecha) = p_fecha para ignorar la hora: si se comparara
-- v.fecha = p_fecha solo entrarian las ventas hechas a las 00:00:00 exactas.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_ventas_del_dia(IN p_fecha DATE)
BEGIN
    -- (a) Desglose: una fila por venta
    SELECT
        v.id_venta,
        v.fecha,
        TIME_FORMAT(TIME(v.fecha), '%H:%i')                        AS hora,
        v.canal,
        v.total,
        c.id_cliente,
        CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente)     AS cliente,
        CONCAT_WS(' ', e.nombre_empleado, e.ap_paterno_empleado)   AS empleado,
        COUNT(d.id_detalle)                                        AS renglones,
        SUM(d.cantidad)                                            AS piezas
    FROM VENTA v
    INNER JOIN CLIENTE  c ON c.id_cliente  = v.id_cliente
    INNER JOIN EMPLEADO e ON e.id_empleado = v.id_empleado
    LEFT  JOIN DETALLE_VENTA d ON d.id_venta = v.id_venta
    WHERE DATE(v.fecha) = p_fecha
    GROUP BY v.id_venta, v.fecha, v.canal, v.total,
             c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente,
             e.nombre_empleado, e.ap_paterno_empleado
    ORDER BY v.fecha ASC;

    -- (b) Resumen del dia: es la suma que pide el reto
    SELECT
        p_fecha                              AS fecha,
        COUNT(*)                             AS num_ventas,
        COALESCE(SUM(v.total), 0)            AS monto_total,
        COALESCE(ROUND(AVG(v.total), 2), 0)  AS ticket_promedio,
        COALESCE(MAX(v.total), 0)            AS venta_mayor
    FROM VENTA v
    WHERE DATE(v.fecha) = p_fecha;
END$$

-- ---------------------------------------------------------
-- 2. Clientes vigentes del primer trimestre
--
-- "Del 1 de enero al 31 de marzo". Se usa un intervalo semiabierto
-- (>= 1-ene AND < 1-abr) en lugar de BETWEEN '01-01' AND '03-31': con BETWEEN
-- sobre un DATETIME se perderian las ventas del 31 de marzo despues de las
-- 00:00:00, porque '2026-03-31' equivale a '2026-03-31 00:00:00'.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_clientes_vigentes_trimestre(IN p_anio INT)
BEGIN
    DECLARE v_inicio DATE;
    DECLARE v_fin    DATE;

    SET v_inicio = MAKEDATE(p_anio, 1);
    SET v_fin    = DATE_ADD(v_inicio, INTERVAL 3 MONTH);

    SELECT
        c.id_cliente,
        CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente) AS cliente,
        c.email_cliente,
        c.telefono_cliente,
        COUNT(v.id_venta)                    AS pedidos,
        SUM(v.total)                         AS monto_total,
        MIN(v.fecha)                         AS primera_compra,
        MAX(v.fecha)                         AS ultima_compra,
        DATEDIFF(CURDATE(), DATE(MAX(v.fecha))) AS dias_desde_ultima
    FROM CLIENTE c
    INNER JOIN VENTA v ON v.id_cliente = c.id_cliente
    WHERE v.fecha >= v_inicio
      AND v.fecha <  v_fin
    GROUP BY c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente,
             c.ap_materno_cliente, c.email_cliente, c.telefono_cliente
    ORDER BY monto_total DESC, cliente ASC;
END$$

-- ---------------------------------------------------------
-- 3. Alta de cliente con excepcion de restriccion unica
--
-- email_cliente es UNIQUE. Si se intenta dar de alta un correo repetido,
-- MariaDB lanza el error 1062 y el EXIT HANDLER lo atrapa: en vez de tronar,
-- el procedimiento devuelve p_codigo = 1062 y un mensaje legible.
--
-- Los DECLARE ... HANDLER van siempre antes de cualquier sentencia ejecutable.
-- ---------------------------------------------------------
CREATE PROCEDURE sp_alta_cliente(
    IN  p_nombre     VARCHAR(50),
    IN  p_ap_paterno VARCHAR(50),
    IN  p_ap_materno VARCHAR(50),
    IN  p_telefono   VARCHAR(15),
    IN  p_email      VARCHAR(100),
    OUT p_id_cliente INT,
    OUT p_codigo     INT,
    OUT p_mensaje    VARCHAR(255)
)
BEGIN
    -- CATCH especifico: llave duplicada
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        SET p_id_cliente = NULL;
        SET p_codigo     = 1062;
        SET p_mensaje    = CONCAT('Ya existe un cliente registrado con el correo ', p_email, '.');
    END;

    -- CATCH general: cualquier otro error de SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_id_cliente = NULL;
        SET p_codigo     = 1;
        SET p_mensaje    = 'No se pudo registrar el cliente.';
    END;

    -- TRY
    INSERT INTO CLIENTE (
        nombre_cliente, ap_paterno_cliente, ap_materno_cliente,
        telefono_cliente, email_cliente
    ) VALUES (
        p_nombre, p_ap_paterno, NULLIF(p_ap_materno, ''),
        p_telefono, p_email
    );

    SET p_id_cliente = LAST_INSERT_ID();
    SET p_codigo     = 0;
    SET p_mensaje    = 'Cliente registrado correctamente.';
END$$

-- ---------------------------------------------------------
-- 4. Control de inventario: sin productos duplicados
--
-- Se considera duplicado el mismo nombre de producto para el mismo proveedor.
-- Lo normal seria un indice UNIQUE (nombre_producto, id_proveedor), pero el
-- reto pide resolverlo con un trigger que lance una excepcion, y con el UNIQUE
-- puesto el trigger nunca alcanzaria a dispararse.
--
-- SIGNAL SQLSTATE '45000' es la forma de lanzar un error propio: llega al
-- cliente como el error 1644 con el texto de MESSAGE_TEXT.
-- ---------------------------------------------------------
CREATE TRIGGER trg_producto_no_duplicado_ins
BEFORE INSERT ON PRODUCTO
FOR EACH ROW
BEGIN
    DECLARE v_repetidos INT;

    SELECT COUNT(*) INTO v_repetidos
    FROM PRODUCTO
    WHERE nombre_producto = NEW.nombre_producto
      AND id_proveedor    = NEW.id_proveedor;

    IF v_repetidos > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ese proveedor ya surte un producto con ese nombre. No se permiten duplicados en el inventario.';
    END IF;
END$$

CREATE TRIGGER trg_producto_no_duplicado_upd
BEFORE UPDATE ON PRODUCTO
FOR EACH ROW
BEGIN
    DECLARE v_repetidos INT;

    -- id_producto <> OLD.id_producto excluye al propio renglon: sin eso, cada
    -- descuento de stock de una venta chocaria consigo mismo y ninguna venta
    -- podria registrarse.
    SELECT COUNT(*) INTO v_repetidos
    FROM PRODUCTO
    WHERE nombre_producto = NEW.nombre_producto
      AND id_proveedor    = NEW.id_proveedor
      AND id_producto    <> OLD.id_producto;

    IF v_repetidos > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ese proveedor ya surte un producto con ese nombre. No se permiten duplicados en el inventario.';
    END IF;
END$$

-- ---------------------------------------------------------
-- 5. Atencion a clientes: bitacora de compras en linea
--
-- Se dispara con cada venta nueva que entre por la app o por el sitio web
-- (canal APP o WEB) y deja el nombre del cliente, la fecha y la hora en
-- SEGUIMIENTO_CLIENTE, para darle seguimiento despues.
-- Las ventas de MOSTRADOR no se registran: el cliente ya fue atendido en persona.
-- ---------------------------------------------------------
CREATE TRIGGER trg_venta_seguimiento
AFTER INSERT ON VENTA
FOR EACH ROW
BEGIN
    DECLARE v_nombre VARCHAR(160);

    IF NEW.canal IN ('APP', 'WEB') THEN
        SELECT CONCAT_WS(' ', nombre_cliente, ap_paterno_cliente, ap_materno_cliente)
        INTO v_nombre
        FROM CLIENTE
        WHERE id_cliente = NEW.id_cliente;

        INSERT INTO SEGUIMIENTO_CLIENTE (
            id_cliente, nombre_cliente, canal, total_compra, fecha_hora, id_venta
        ) VALUES (
            NEW.id_cliente, v_nombre, NEW.canal, NEW.total, NEW.fecha, NEW.id_venta
        );
    END IF;
END$$

DELIMITER ;
