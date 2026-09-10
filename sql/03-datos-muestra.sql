-- =========================================================
-- Ferreteria - 03: datos de muestra
--
-- Al menos cinco registros por tabla. Se carga DESPUES de
-- 02-programabilidad.sql a proposito: las ventas con canal APP o WEB disparan
-- el trigger trg_venta_seguimiento, asi que SEGUIMIENTO_CLIENTE se llena sola
-- y queda demostrado que el trigger funciona.
--
-- Las ventas cubren dos periodos:
--   - enero a marzo, para sp_clientes_vigentes_trimestre
--   - agosto y septiembre, para sp_ventas_del_dia
-- =========================================================

USE ferreteria;

INSERT INTO CATEGORIA (id_categoria, nombre_categoria, descripcion) VALUES
(1, 'Herramientas', 'Herramientas manuales y electricas'),
(2, 'Pintura',      'Pinturas, brochas y solventes'),
(3, 'Electrico',    'Cableado, contactos, focos'),
(4, 'Plomeria',     'Tubos, conexiones y accesorios de agua'),
(5, 'Tornilleria',  'Tornillos, tuercas y anclajes');

INSERT INTO PROVEEDOR (id_proveedor, rfc, nombre_empresa, telefono_proveedor, email_proveedor) VALUES
(1, 'TRU850101AB1', 'Truper', '8180001111', 'ventas@truper.com'),
(2, 'PRE900215XY2', 'Pretul', '8180002222', 'contacto@pretul.com.mx'),
(3, 'MAK750620KL3', 'Makita', '8180003333', 'info@makita.com'),
(4, 'DEW880330MN4', 'DeWalt', '8180004444', 'ventas@dewalt.com'),
(5, 'BOS900202CD2', 'Bosch',  '8180005555', 'contacto@bosch.com');

-- El stock ya viene descontado de las ventas de muestra de abajo.
INSERT INTO PRODUCTO (id_producto, nombre_producto, descripcion_producto, precio_compra, precio_venta, stock, id_categoria, id_proveedor) VALUES
(1, 'Martillo',            'Martillo de una libra',        90.00,  150.00, 34, 1, 1),
(2, 'Pintura vinilica',    'Cubeta 19L color blanco',     140.00,  200.00, 23, 2, 2),
(3, 'Taladro inalambrico', 'Taladro 20V con bateria',     600.00,  850.00,  8, 3, 3),
(4, 'Sierra circular',     'Sierra circular 7 1/4 pulg',  900.00, 1200.00,  7, 1, 4),
(5, 'Tubo PVC',            'Tubo PVC hidraulico 1/2 pulg', 25.00,   45.00, 88, 4, 1),
(6, 'Tornillos surtidos',  'Caja de tornillos surtidos',   30.00,   50.00, 55, 5, 2);

INSERT INTO CLIENTE (id_cliente, nombre_cliente, ap_paterno_cliente, ap_materno_cliente, telefono_cliente, email_cliente) VALUES
(1, 'Ana',        'Lopez',   'Sanchez',  '8999602293', 'ana.lopez@mail.com'),
(2, 'Carlos',     'Ruiz',    'Martinez', '8999602294', 'carlos.ruiz@mail.com'),
(3, 'Fernanda',   'Torres',  'Molina',   '8999602295', 'fernanda.torres@mail.com'),
(4, 'Luis Angel', 'Mendoza', 'Cruz',     '8999602296', 'luisangel.mendoza@mail.com'),
(5, 'Patricia',   'Gomez',   'Reyes',    '8999602297', 'patricia.gomez@mail.com');

INSERT INTO EMPLEADO (id_empleado, nombre_empleado, ap_paterno_empleado, ap_materno_empleado, puesto, sueldo, telefono_empleado, email_empleado) VALUES
(1, 'Guillermo Daniel',   'Ramirez', 'Borrego',    'Gerente',  15000.00, '8681112222', 'guillermo.ramirez@ferreteria.com'),
(2, 'Jose Luis',          'Huerta',  'Perez',      'Vendedor',  9000.00, '8683334444', 'joseluis.huerta@ferreteria.com'),
(3, 'Christian Emmanuel', 'Angulo',  'Castillo',   'Cajero',    8500.00, '8685556666', 'christian.angulo@ferreteria.com'),
(4, 'Isaias',             'Delgado', 'Suarez',     'Bodega',    8200.00, '8687778888', 'isaias.delgado@ferreteria.com'),
(5, 'Alejandro',          'Ramirez', 'Dominguez',  'Vendedor',  9000.00, '8689990000', 'alejandro.ramirez@ferreteria.com');

-- ---------------------------------------------------------
-- Ventas del primer trimestre (para sp_clientes_vigentes_trimestre)
--
-- La venta 12 es del 31 de marzo a las 19:45 a proposito: sirve para demostrar
-- por que el procedimiento usa "< 1 de abril" y no BETWEEN hasta '2026-03-31'.
-- Con BETWEEN esa venta se perderia.
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

-- ---------------------------------------------------------
-- Ventas de agosto y septiembre (para sp_ventas_del_dia)
-- ---------------------------------------------------------
INSERT INTO VENTA (id_venta, fecha, total, canal, id_cliente, id_empleado) VALUES
(1, '2026-08-10 10:15:00', 1150.00, 'MOSTRADOR', 1, 1),
(2, '2026-08-11 12:30:00',  600.00, 'APP',       2, 2),
(3, '2026-08-12 09:00:00',  330.00, 'WEB',       3, 3),
(4, '2026-08-13 16:45:00', 1200.00, 'MOSTRADOR', 4, 1),
(5, '2026-08-14 11:20:00', 1000.00, 'APP',       5, 5),
(6, '2026-09-09 21:36:52',  540.00, 'APP',       2, 3);

INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto) VALUES
(2,  150.00,  300.00, 1, 1),
(1,  850.00,  850.00, 1, 3),
(3,  200.00,  600.00, 2, 2),
(4,   45.00,  180.00, 3, 5),
(3,   50.00,  150.00, 3, 6),
(1, 1200.00, 1200.00, 4, 4),
(1,  850.00,  850.00, 5, 3),
(1,  150.00,  150.00, 5, 1),
(3,  150.00,  450.00, 6, 1),
(2,   45.00,   90.00, 6, 5);

-- Comprobacion: el trigger debio dejar una fila por cada venta APP/WEB
-- (7, 8, 10, 11, 12, 2, 3, 5 y 6 = nueve registros) y ninguna de MOSTRADOR.
SELECT COUNT(*) AS filas_en_bitacora FROM SEGUIMIENTO_CLIENTE;
