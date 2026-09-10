-- =========================================================
-- Ferreteria - 04: consultas avanzadas
--
-- Una consulta por cada estructura que pide el reto: JOIN, UNION, ORDER BY,
-- GROUP BY y manejo de fechas. No se ejecuta como script de instalacion; es
-- para correr consulta por consulta y mostrar los resultados.
-- =========================================================

USE ferreteria;

-- ---------------------------------------------------------
-- JOIN
-- ---------------------------------------------------------

-- 1. INNER JOIN de cuatro tablas: que se vendio, a quien y quien lo atendio.
SELECT
    v.id_venta,
    v.fecha,
    CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente)   AS cliente,
    CONCAT_WS(' ', e.nombre_empleado, e.ap_paterno_empleado) AS empleado,
    p.nombre_producto,
    d.cantidad,
    d.precio_unitario,
    d.subtotal
FROM VENTA v
INNER JOIN CLIENTE       c ON c.id_cliente  = v.id_cliente
INNER JOIN EMPLEADO      e ON e.id_empleado = v.id_empleado
INNER JOIN DETALLE_VENTA d ON d.id_venta    = v.id_venta
INNER JOIN PRODUCTO      p ON p.id_producto = d.id_producto
ORDER BY v.fecha DESC, d.id_detalle ASC;

-- 2. LEFT JOIN: catalogo completo incluyendo lo que NUNCA se ha vendido.
--    Con INNER JOIN esos productos desaparecerian del resultado, que es
--    justamente la informacion que interesa para decidir que dejar de surtir.
SELECT
    p.id_producto,
    p.nombre_producto,
    cat.nombre_categoria,
    p.stock,
    COALESCE(SUM(d.cantidad), 0) AS piezas_vendidas
FROM PRODUCTO p
INNER JOIN CATEGORIA cat ON cat.id_categoria = p.id_categoria
LEFT  JOIN DETALLE_VENTA d ON d.id_producto = p.id_producto
GROUP BY p.id_producto, p.nombre_producto, cat.nombre_categoria, p.stock
ORDER BY piezas_vendidas ASC;

-- ---------------------------------------------------------
-- UNION
-- ---------------------------------------------------------

-- 3. Directorio unico de personas: junta clientes y empleados, que viven en
--    tablas distintas, en una sola lista. La columna "tipo" dice de donde
--    salio cada renglon. UNION (sin ALL) ademas elimina duplicados exactos.
SELECT
    'Cliente'  AS tipo,
    c.id_cliente AS id,
    CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente) AS nombre,
    c.telefono_cliente AS telefono,
    c.email_cliente    AS email
FROM CLIENTE c
UNION
SELECT
    'Empleado',
    e.id_empleado,
    CONCAT_WS(' ', e.nombre_empleado, e.ap_paterno_empleado, e.ap_materno_empleado),
    e.telefono_empleado,
    e.email_empleado
FROM EMPLEADO e
ORDER BY tipo ASC, nombre ASC;

-- 4. UNION ALL con etiqueta: movimientos de dinero que entra (ventas) contra
--    dinero que sale (nomina). UNION ALL no descarta duplicados, y aqui si
--    interesa conservarlos: dos empleados pueden ganar lo mismo.
SELECT 'Ingreso por venta' AS concepto, v.fecha AS momento, v.total AS monto
FROM VENTA v
UNION ALL
SELECT CONCAT('Sueldo de ', e.nombre_empleado), NULL, -e.sueldo
FROM EMPLEADO e
ORDER BY monto DESC;

-- ---------------------------------------------------------
-- ORDER BY
-- ---------------------------------------------------------

-- 5. Ventas de la mas reciente a la mas antigua.
SELECT id_venta, fecha, canal, total
FROM VENTA
ORDER BY fecha DESC;

-- 6. Las mismas, de la mas antigua a la mas reciente, y con criterio de
--    desempate: si dos ventas cayeran en el mismo instante, gana la de mayor
--    monto. Sin el segundo criterio el orden de esos casos seria impredecible.
SELECT id_venta, fecha, canal, total
FROM VENTA
ORDER BY fecha ASC, total DESC;

-- ---------------------------------------------------------
-- GROUP BY
-- ---------------------------------------------------------

-- 7. Ventas agrupadas por dia.
SELECT
    DATE(v.fecha)     AS dia,
    COUNT(*)          AS num_ventas,
    SUM(v.total)      AS monto_total,
    ROUND(AVG(v.total), 2) AS ticket_promedio
FROM VENTA v
GROUP BY DATE(v.fecha)
ORDER BY dia DESC;

-- 8. Productos mas vendidos: agrupa el detalle por producto.
SELECT
    p.id_producto,
    p.nombre_producto,
    cat.nombre_categoria,
    SUM(d.cantidad)  AS piezas_vendidas,
    SUM(d.subtotal)  AS importe_vendido,
    COUNT(DISTINCT d.id_venta) AS aparece_en_ventas
FROM DETALLE_VENTA d
INNER JOIN PRODUCTO  p   ON p.id_producto   = d.id_producto
INNER JOIN CATEGORIA cat ON cat.id_categoria = p.id_categoria
GROUP BY p.id_producto, p.nombre_producto, cat.nombre_categoria
ORDER BY piezas_vendidas DESC;

-- 9. GROUP BY con HAVING: solo los empleados que han vendido mas de $1,000.
--    HAVING filtra despues de agrupar; WHERE no sirve aqui porque SUM() todavia
--    no existe cuando WHERE se evalua.
SELECT
    e.id_empleado,
    CONCAT_WS(' ', e.nombre_empleado, e.ap_paterno_empleado) AS empleado,
    e.puesto,
    COUNT(v.id_venta) AS ventas_atendidas,
    SUM(v.total)      AS monto_vendido
FROM EMPLEADO e
INNER JOIN VENTA v ON v.id_empleado = e.id_empleado
GROUP BY e.id_empleado, e.nombre_empleado, e.ap_paterno_empleado, e.puesto
HAVING SUM(v.total) > 1000
ORDER BY monto_vendido DESC;

-- 10. Agrupado por canal de compra: cuanto entra por la app, por la web y por
--     mostrador.
SELECT
    v.canal,
    COUNT(*)     AS num_ventas,
    SUM(v.total) AS monto_total,
    ROUND(100 * SUM(v.total) / (SELECT SUM(total) FROM VENTA), 1) AS porcentaje
FROM VENTA v
GROUP BY v.canal
ORDER BY monto_total DESC;

-- ---------------------------------------------------------
-- Fechas y horas
-- ---------------------------------------------------------

-- 11. Ventas por mes con nombre del mes.
SELECT
    YEAR(v.fecha)                      AS anio,
    MONTH(v.fecha)                     AS mes,
    DATE_FORMAT(v.fecha, '%M')         AS nombre_mes,
    COUNT(*)                           AS num_ventas,
    SUM(v.total)                       AS monto_total
FROM VENTA v
GROUP BY YEAR(v.fecha), MONTH(v.fecha), DATE_FORMAT(v.fecha, '%M')
ORDER BY anio ASC, mes ASC;

-- 12. Ventas del primer trimestre con intervalo semiabierto.
--     Ojo: BETWEEN '2026-01-01' AND '2026-03-31' se leeria como
--     "hasta 2026-03-31 00:00:00" y dejaria fuera todo el 31 de marzo.
SELECT id_venta, fecha, total, canal
FROM VENTA
WHERE fecha >= '2026-01-01'
  AND fecha <  '2026-04-01'
ORDER BY fecha ASC;

-- 13. Antiguedad de cada cliente: cuantos dias han pasado desde su ultima
--     compra y en que horario suele comprar.
SELECT
    c.id_cliente,
    CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente) AS cliente,
    MAX(v.fecha)                              AS ultima_compra,
    DATEDIFF(CURDATE(), DATE(MAX(v.fecha)))   AS dias_sin_comprar,
    CASE
        WHEN HOUR(MAX(v.fecha)) < 12 THEN 'Manana'
        WHEN HOUR(MAX(v.fecha)) < 18 THEN 'Tarde'
        ELSE 'Noche'
    END AS horario_habitual
FROM CLIENTE c
INNER JOIN VENTA v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente
ORDER BY dias_sin_comprar ASC;

-- 14. Ventas por dia de la semana: sirve para saber que dias conviene tener
--     mas gente en el mostrador.
SELECT
    DAYOFWEEK(v.fecha)                 AS num_dia,
    DATE_FORMAT(v.fecha, '%W')         AS dia_semana,
    COUNT(*)                           AS num_ventas,
    SUM(v.total)                       AS monto_total
FROM VENTA v
GROUP BY DAYOFWEEK(v.fecha), DATE_FORMAT(v.fecha, '%W')
ORDER BY monto_total DESC;

-- 15. Movimientos de los ultimos 90 dias, contando hacia atras desde hoy.
SELECT
    v.id_venta,
    v.fecha,
    v.total,
    TIMESTAMPDIFF(DAY, v.fecha, NOW()) AS hace_dias
FROM VENTA v
WHERE v.fecha >= DATE_SUB(NOW(), INTERVAL 90 DAY)
ORDER BY v.fecha DESC;

-- ---------------------------------------------------------
-- Pruebas de los procedimientos y triggers
-- ---------------------------------------------------------

-- 16. Reporte de ventas de un dia (devuelve dos resultados: desglose y resumen).
CALL sp_ventas_del_dia('2026-08-10');

-- 17. Clientes vigentes del primer trimestre.
CALL sp_clientes_vigentes_trimestre(2026);

-- 18. Alta de cliente correcta.
CALL sp_alta_cliente('Mariana', 'Salinas', 'Vega', '8999602298',
                     'mariana.salinas@mail.com', @id, @codigo, @mensaje);
SELECT @id AS id_cliente, @codigo AS codigo, @mensaje AS mensaje;

-- 19. Alta con correo repetido: el HANDLER lo atrapa y devuelve codigo 1062
--     en lugar de tronar la sesion.
CALL sp_alta_cliente('Otra', 'Persona', NULL, '8999602299',
                     'ana.lopez@mail.com', @id, @codigo, @mensaje);
SELECT @id AS id_cliente, @codigo AS codigo, @mensaje AS mensaje;

-- 20. Trigger de inventario: este INSERT debe fallar con el error 1644 porque
--     Truper ya surte un producto llamado 'Martillo'.
-- INSERT INTO PRODUCTO (nombre_producto, descripcion_producto, precio_compra, precio_venta, stock, id_categoria, id_proveedor)
-- VALUES ('Martillo', 'Intento duplicado', 80.00, 140.00, 5, 1, 1);

-- 21. Bitacora que llena el trigger de atencion a clientes.
SELECT
    s.id_seguimiento,
    s.nombre_cliente,
    s.canal,
    s.total_compra,
    s.fecha_hora,
    DATE_FORMAT(s.fecha_hora, '%d/%m/%Y %H:%i') AS fecha_legible,
    s.atendido
FROM SEGUIMIENTO_CLIENTE s
ORDER BY s.fecha_hora DESC;

-- 22. Comprobacion de que el trigger discrimina por canal: no debe haber
--     ninguna fila de MOSTRADOR en la bitacora.
SELECT COUNT(*) AS mostrador_en_bitacora
FROM SEGUIMIENTO_CLIENTE
WHERE canal = 'MOSTRADOR';
