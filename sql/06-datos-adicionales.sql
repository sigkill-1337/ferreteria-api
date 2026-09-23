-- =========================================================
-- Ferreteria - 06: catalogo ampliado y 30 ventas adicionales
--
-- Amplia los datos de muestra para que los reportes tengan volumen
-- suficiente: mas productos, clientes, empleados y proveedores, y treinta
-- ventas repartidas a lo largo del ano.
--
-- Se ejecuta DESPUES de 02-programabilidad.sql. El orden importa: al
-- insertarse cada venta, el trigger trg_venta_seguimiento anade por su
-- cuenta el registro correspondiente en SEGUIMIENTO_CLIENTE cuando el canal
-- es APP o WEB. Si se cargara antes de crear los triggers, la bitacora
-- quedaria vacia.
--
-- Las ventas no llevan id fijo: se insertan una por una y el detalle se
-- engancha con LAST_INSERT_ID(). Asi el script funciona sin importar
-- cuantas ventas existan ya en la base.
--
-- Las existencias de los productos nuevos vienen ya descontadas de las
-- ventas de este archivo. Las de los productos que ya existian se ajustan
-- al final con restas relativas.
-- =========================================================

USE ferreteria;

START TRANSACTION;

-- ---------------------------------------------------------
-- 1. Catalogos
-- ---------------------------------------------------------
INSERT INTO CATEGORIA (id_categoria, nombre_categoria, descripcion) VALUES
(6, 'Jardineria', 'Mangueras, aspersores y herramienta de jardin'),
(7, 'Seguridad', 'Equipo de proteccion personal'),
(8, 'Adhesivos', 'Pegamentos, siliconas y cintas');

INSERT INTO PROVEEDOR (id_proveedor, rfc, nombre_empresa, telefono_proveedor, email_proveedor) VALUES
(6, 'URR820415HJ7', 'Urrea', '8180006666', 'ventas@urrea.com'),
(7, 'FIE910722RT5', 'Fiero', '8180007777', 'contacto@fiero.com.mx'),
(8, 'SUR880110QW3', 'Surtek', '8180008888', 'info@surtek.com'),
(9, 'ROT750925ZX1', 'Rotoplas', '8180009999', 'ventas@rotoplas.com'),
(10, 'TRM900630PL8', '3M Mexico', '8180001010', 'contacto@3m.com.mx');

-- El stock ya viene descontado de las ventas de mas abajo.
INSERT INTO PRODUCTO (id_producto, nombre_producto, descripcion_producto, precio_compra, precio_venta, stock, id_categoria, id_proveedor) VALUES
(7, 'Desarmador de cruz', 'Desarmador punta cruz 6 pulgadas', 35.00, 65.00, 117, 1, 6),
(8, 'Llave ajustable 10', 'Llave perico de 10 pulgadas', 110.00, 185.00, 60, 1, 6),
(9, 'Cinta metrica 5m', 'Flexometro de 5 metros', 48.00, 85.00, 86, 1, 8),
(10, 'Pinzas de electricista', 'Pinzas aisladas 8 pulgadas', 95.00, 160.00, 47, 1, 7),
(11, 'Brocha 4 pulgadas', 'Brocha cerda natural', 28.00, 55.00, 134, 2, 2),
(12, 'Thinner 1L', 'Thinner estandar un litro', 42.00, 78.00, 107, 2, 10),
(13, 'Cable THW calibre 12', 'Rollo de 100 metros', 780.00, 1150.00, 19, 3, 5),
(14, 'Apagador sencillo', 'Apagador de pared una via', 22.00, 45.00, 169, 3, 7),
(15, 'Llave de paso media', 'Llave de paso 1/2 pulgada', 58.00, 105.00, 82, 4, 9),
(16, 'Cemento para PVC', 'Bote de 250 ml', 38.00, 72.00, 78, 8, 9),
(17, 'Guantes de carnaza', 'Par de guantes reforzados', 45.00, 88.00, 126, 7, 10),
(18, 'Manguera de jardin 15m', 'Manguera reforzada de 15 metros', 190.00, 310.00, 35, 6, 8);

INSERT INTO CLIENTE (id_cliente, nombre_cliente, ap_paterno_cliente, ap_materno_cliente, telefono_cliente, email_cliente) VALUES
(6, 'Roberto', 'Vargas', 'Nunez', '8999602301', 'roberto.vargas@mail.com'),
(7, 'Adriana', 'Cervantes', 'Rios', '8999602302', 'adriana.cervantes@mail.com'),
(8, 'Hector', 'Nava', 'Padilla', '8999602303', 'hector.nava@mail.com'),
(9, 'Lucia', 'Barrera', 'Ochoa', '8999602304', 'lucia.barrera@mail.com'),
(10, 'Ricardo', 'Esquivel', 'Ponce', '8999602305', 'ricardo.esquivel@mail.com'),
(11, 'Gabriela', 'Montes', 'Ibarra', '8999602306', 'gabriela.montes@mail.com'),
(12, 'Sergio', 'Quintero', 'Lara', '8999602307', 'sergio.quintero@mail.com'),
(13, 'Veronica', 'Arellano', 'Duran', '8999602308', 'veronica.arellano@mail.com'),
(14, 'Emilio', 'Zamudio', 'Vela', '8999602309', 'emilio.zamudio@mail.com'),
(15, 'Claudia', 'Renteria', 'Macias', '8999602310', 'claudia.renteria@mail.com');

INSERT INTO EMPLEADO (id_empleado, nombre_empleado, ap_paterno_empleado, ap_materno_empleado, puesto, sueldo, telefono_empleado, email_empleado) VALUES
(6, 'Mariana', 'Cordero', 'Salas', 'Vendedor', 9200.00, '8681113333', 'mariana.cordero@ferreteria.com'),
(7, 'Rodrigo', 'Paredes', 'Guzman', 'Cajero', 8600.00, '8681114444', 'rodrigo.paredes@ferreteria.com'),
(8, 'Ximena', 'Bautista', 'Ferrer', 'Vendedor', 9200.00, '8681115555', 'ximena.bautista@ferreteria.com'),
(9, 'Ignacio', 'Rosales', 'Trejo', 'Bodega', 8300.00, '8681116666', 'ignacio.rosales@ferreteria.com'),
(10, 'Fernanda', 'Olvera', 'Cantu', 'Supervisor', 11500.00, '8681117777', 'fernanda.olvera@ferreteria.com');

-- ---------------------------------------------------------
-- 2. Treinta ventas con su detalle
-- ---------------------------------------------------------

-- Venta 1 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-02-18 12:20:00', 2745.00, 'APP', 9, 7);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 850.00, 2550.00, @v, 3),
(3, 65.00, 195.00, @v, 7);

-- Venta 2 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-02-18 13:40:00', 2260.00, 'MOSTRADOR', 10, 5);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 185.00, 740.00, @v, 8),
(1, 1200.00, 1200.00, @v, 4),
(2, 160.00, 320.00, @v, 10);

-- Venta 3 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-02-18 14:45:00', 144.00, 'MOSTRADOR', 10, 8);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 72.00, 144.00, @v, 16);

-- Venta 4 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-03-05 09:50:00', 288.00, 'APP', 15, 3);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 72.00, 288.00, @v, 16);

-- Venta 5 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-03-05 13:30:00', 1700.00, 'WEB', 9, 10);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 185.00, 185.00, @v, 8),
(3, 105.00, 315.00, @v, 15),
(1, 1200.00, 1200.00, @v, 4);

-- Venta 6 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-04-22 10:30:00', 2345.00, 'APP', 11, 1);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 1150.00, 2300.00, @v, 13),
(1, 45.00, 45.00, @v, 5);

-- Venta 7 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-04-22 14:20:00', 341.00, 'APP', 2, 5);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 78.00, 156.00, @v, 12),
(1, 185.00, 185.00, @v, 8);

-- Venta 8 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-04-22 18:40:00', 1240.00, 'MOSTRADOR', 5, 7);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 310.00, 1240.00, @v, 18);

-- Venta 9 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-05-14 11:20:00', 1542.00, 'MOSTRADOR', 5, 4);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 78.00, 78.00, @v, 12),
(3, 88.00, 264.00, @v, 17),
(1, 1200.00, 1200.00, @v, 4);

-- Venta 10 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-05-14 19:15:00', 216.00, 'APP', 8, 1);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 72.00, 216.00, @v, 16);

-- Venta 11 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-06-09 11:40:00', 4672.00, 'MOSTRADOR', 2, 6);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 72.00, 72.00, @v, 16),
(4, 1150.00, 4600.00, @v, 13);

-- Venta 12 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-06-09 12:15:00', 329.00, 'WEB', 9, 5);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 72.00, 144.00, @v, 16),
(1, 185.00, 185.00, @v, 8);

-- Venta 13 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-06-09 18:50:00', 255.00, 'APP', 4, 6);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 85.00, 255.00, @v, 9);

-- Venta 14 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-06-09 19:50:00', 536.00, 'APP', 7, 7);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 72.00, 216.00, @v, 16),
(2, 160.00, 320.00, @v, 10);

-- Venta 15 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-07-03 09:05:00', 480.00, 'MOSTRADOR', 13, 8);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 150.00, 300.00, @v, 1),
(4, 45.00, 180.00, @v, 14);

-- Venta 16 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-07-03 17:30:00', 288.00, 'WEB', 9, 8);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 72.00, 288.00, @v, 16);

-- Venta 17 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-07-03 18:40:00', 55.00, 'APP', 3, 5);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 55.00, 55.00, @v, 11);

-- Venta 18 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-10 09:40:00', 480.00, 'APP', 2, 7);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 160.00, 480.00, @v, 10);

-- Venta 19 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-10 16:30:00', 1090.00, 'APP', 15, 2);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 45.00, 180.00, @v, 14),
(4, 150.00, 600.00, @v, 1),
(1, 310.00, 310.00, @v, 18);

-- Venta 20 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-10 18:30:00', 935.00, 'MOSTRADOR', 7, 1);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 45.00, 135.00, @v, 5),
(4, 200.00, 800.00, @v, 2);

-- Venta 21 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-21 13:20:00', 798.00, 'MOSTRADOR', 3, 1);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 88.00, 88.00, @v, 17),
(1, 310.00, 310.00, @v, 18),
(2, 200.00, 400.00, @v, 2);

-- Venta 22 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-21 14:20:00', 345.00, 'MOSTRADOR', 10, 9);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 45.00, 180.00, @v, 5),
(3, 55.00, 165.00, @v, 11);

-- Venta 23 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-08-21 19:20:00', 520.00, 'APP', 9, 1);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 160.00, 320.00, @v, 10),
(4, 50.00, 200.00, @v, 6);

-- Venta 24 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-15 09:15:00', 150.00, 'APP', 5, 9);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 50.00, 150.00, @v, 6);

-- Venta 25 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-15 13:50:00', 1240.00, 'MOSTRADOR', 10, 9);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 310.00, 1240.00, @v, 18);

-- Venta 26 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-15 15:20:00', 50.00, 'APP', 12, 9);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(1, 50.00, 50.00, @v, 6);

-- Venta 27 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-15 18:20:00', 810.00, 'WEB', 9, 8);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 160.00, 640.00, @v, 10),
(2, 85.00, 170.00, @v, 9);

-- Venta 28 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-18 11:50:00', 305.00, 'WEB', 14, 6);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2, 55.00, 110.00, @v, 11),
(1, 45.00, 45.00, @v, 14),
(3, 50.00, 150.00, @v, 6);

-- Venta 29 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-18 13:20:00', 646.00, 'WEB', 14, 2);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(4, 85.00, 340.00, @v, 9),
(2, 45.00, 90.00, @v, 14),
(3, 72.00, 216.00, @v, 16);

-- Venta 30 de 30
INSERT INTO VENTA (fecha, total, canal, id_cliente, id_empleado) VALUES
('2026-09-18 14:50:00', 935.00, 'APP', 15, 6);
SET @v = LAST_INSERT_ID();
INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(3, 185.00, 555.00, @v, 8),
(4, 45.00, 180.00, @v, 5),
(4, 50.00, 200.00, @v, 6);

-- ---------------------------------------------------------
-- 3. Ajuste de existencias de los productos que ya existian
-- ---------------------------------------------------------
UPDATE PRODUCTO SET stock = stock - 6  WHERE id_producto = 1;   -- Martillo
UPDATE PRODUCTO SET stock = stock - 6  WHERE id_producto = 2;   -- Pintura vinilica
UPDATE PRODUCTO SET stock = stock - 3  WHERE id_producto = 3;   -- Taladro inalambrico
UPDATE PRODUCTO SET stock = stock - 3  WHERE id_producto = 4;   -- Sierra circular
UPDATE PRODUCTO SET stock = stock - 12 WHERE id_producto = 5;   -- Tubo PVC
UPDATE PRODUCTO SET stock = stock - 15 WHERE id_producto = 6;   -- Tornillos surtidos

COMMIT;

-- ---------------------------------------------------------
-- Comprobaciones
-- ---------------------------------------------------------
SELECT COUNT(*) AS ventas_totales FROM VENTA;
SELECT canal, COUNT(*) AS ventas, SUM(total) AS monto FROM VENTA GROUP BY canal;
SELECT COUNT(*) AS filas_en_bitacora FROM SEGUIMIENTO_CLIENTE;
SELECT id_producto, nombre_producto, stock FROM PRODUCTO ORDER BY id_producto;

-- El total de cada venta debe coincidir con la suma de su detalle.
-- Esta consulta no debe devolver ninguna fila.
SELECT v.id_venta, v.total, SUM(d.subtotal) AS suma_detalle
FROM VENTA v JOIN DETALLE_VENTA d ON d.id_venta = v.id_venta
GROUP BY v.id_venta, v.total
HAVING v.total <> SUM(d.subtotal);
