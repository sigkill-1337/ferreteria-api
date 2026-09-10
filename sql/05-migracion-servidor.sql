-- =========================================================
-- Ferreteria - 05: migracion del servidor que YA esta corriendo
--
-- Solo para la base que ya tiene datos en produccion. Una instalacion desde
-- cero NO necesita este archivo: usa 01 -> 02 -> 03.
--
-- Orden en el servidor:
--   1) mysql -u root -p ferreteria < sql/05-migracion-servidor.sql
--   2) mysql -u root -p ferreteria < sql/02-programabilidad.sql
--
-- Este archivo no depende de los triggers: la bitacora historica se llena con
-- un INSERT ... SELECT al final, asi el orden entre 05 y 02 no importa.
-- =========================================================

USE ferreteria;

-- ---------------------------------------------------------
-- 1. Canal de compra en VENTA
--
-- Ojo: ALTER TABLE y CREATE TABLE hacen COMMIT implicito en MariaDB, asi que
-- el DDL de los pasos 1 y 2 no se puede envolver en una transaccion. La parte
-- de datos (pasos 3 y 4) si va dentro de una.
-- ---------------------------------------------------------
ALTER TABLE VENTA
    ADD COLUMN IF NOT EXISTS canal ENUM('APP','WEB','MOSTRADOR') NOT NULL DEFAULT 'APP'
    AFTER total;

-- Las ventas que ya existian se reparten en los tres canales para que los
-- reportes agrupados por canal tengan algo que mostrar.
UPDATE VENTA SET canal = 'MOSTRADOR' WHERE id_venta IN (1, 4);
UPDATE VENTA SET canal = 'WEB'       WHERE id_venta IN (3);
UPDATE VENTA SET canal = 'APP'       WHERE id_venta IN (2, 5, 6);

-- ---------------------------------------------------------
-- 2. Tabla de seguimiento
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS SEGUIMIENTO_CLIENTE (
    id_seguimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    nombre_cliente VARCHAR(160) NOT NULL,
    canal ENUM('APP','WEB','MOSTRADOR') NOT NULL,
    total_compra DECIMAL(10,2) NOT NULL,
    fecha_hora DATETIME NOT NULL,
    atendido TINYINT(1) NOT NULL DEFAULT 0,
    id_venta INT NULL,
    FOREIGN KEY (id_venta) REFERENCES VENTA(id_venta) ON DELETE SET NULL,
    FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente) ON DELETE CASCADE
);

CREATE INDEX idx_venta_fecha ON VENTA (fecha);
CREATE INDEX idx_seguimiento_fecha ON SEGUIMIENTO_CLIENTE (fecha_hora);

START TRANSACTION;

-- ---------------------------------------------------------
-- 3. Ventas del primer trimestre
--
-- Sin ellas, sp_clientes_vigentes_trimestre devuelve lista vacia: todas las
-- ventas que hay en el servidor son de agosto y septiembre.
--
-- La venta 12 es del 31 de marzo a las 19:45 a proposito, para demostrar por
-- que el procedimiento usa "< 1 de abril" en lugar de BETWEEN.
-- ---------------------------------------------------------
INSERT INTO VENTA (id_venta, fecha, total, canal, id_cliente, id_empleado) VALUES
( 7, '2026-01-12 10:05:00',  480.00, 'APP',       1, 2),
( 8, '2026-01-28 17:40:00', 1000.00, 'WEB',       3, 5),
( 9, '2026-02-14 12:15:00', 1200.00, 'MOSTRADOR', 2, 3),
(10, '2026-02-27 09:30:00',  400.00, 'APP',       1, 2),
(11, '2026-03-10 16:00:00',  370.00, 'APP',       5, 5),
(12, '2026-03-31 19:45:00', 1000.00, 'WEB',       4, 3);

INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2,  150.00,  300.00,  7, 1),
(4,   45.00,  180.00,  7, 5),
(1,  850.00,  850.00,  8, 3),
(3,   50.00,  150.00,  8, 6),
(1, 1200.00, 1200.00,  9, 4),
(2,  200.00,  400.00, 10, 2),
(6,   45.00,  270.00, 11, 5),
(2,   50.00,  100.00, 11, 6),
(1,  150.00,  150.00, 12, 1),
(1,  850.00,  850.00, 12, 3);

-- El stock tiene que reflejar lo que acaban de consumir esas ventas, o el
-- inventario quedaria mintiendo.
UPDATE PRODUCTO SET stock = stock - 3  WHERE id_producto = 1;  -- Martillo:   ventas 7 y 12
UPDATE PRODUCTO SET stock = stock - 2  WHERE id_producto = 2;  -- Pintura:    venta 10
UPDATE PRODUCTO SET stock = stock - 2  WHERE id_producto = 3;  -- Taladro:    ventas 8 y 12
UPDATE PRODUCTO SET stock = stock - 1  WHERE id_producto = 4;  -- Sierra:     venta 9
UPDATE PRODUCTO SET stock = stock - 10 WHERE id_producto = 5;  -- Tubo PVC:   ventas 7 y 11
UPDATE PRODUCTO SET stock = stock - 5  WHERE id_producto = 6;  -- Tornillos:  ventas 8 y 11

-- ---------------------------------------------------------
-- 4. Bitacora historica
--
-- El trigger solo actua sobre ventas nuevas. Las que ya estaban se cargan aqui
-- una sola vez, con el mismo criterio que usa el trigger: solo APP y WEB.
-- ---------------------------------------------------------
INSERT INTO SEGUIMIENTO_CLIENTE (id_cliente, nombre_cliente, canal, total_compra, fecha_hora, id_venta)
SELECT
    v.id_cliente,
    CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente),
    v.canal,
    v.total,
    v.fecha,
    v.id_venta
FROM VENTA v
INNER JOIN CLIENTE c ON c.id_cliente = v.id_cliente
WHERE v.canal IN ('APP', 'WEB')
  AND NOT EXISTS (
      SELECT 1 FROM SEGUIMIENTO_CLIENTE s WHERE s.id_venta = v.id_venta
  );

COMMIT;

-- ---------------------------------------------------------
-- Comprobaciones
-- ---------------------------------------------------------
SELECT canal, COUNT(*) AS ventas FROM VENTA GROUP BY canal;
SELECT COUNT(*) AS filas_en_bitacora FROM SEGUIMIENTO_CLIENTE;
SELECT id_producto, nombre_producto, stock FROM PRODUCTO ORDER BY id_producto;

-- Descomenta despues de cargar 02-programabilidad.sql:
-- CALL sp_clientes_vigentes_trimestre(2026);
