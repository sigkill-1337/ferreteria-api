-- =========================================================
-- Ferreteria - 01: esquema (DDL)
--
-- Instalacion desde cero, en orden:
--   01-esquema.sql -> 02-programabilidad.sql -> 03-datos-muestra.sql
--
-- Los procedimientos y triggers se cargan ANTES que los datos a proposito:
-- asi el trigger de seguimiento se dispara con las ventas de muestra y la
-- bitacora queda poblada sola, que es la prueba de que funciona.
-- =========================================================

CREATE DATABASE IF NOT EXISTS ferreteria CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ferreteria;

CREATE TABLE CATEGORIA (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre_categoria VARCHAR(50) NOT NULL,
    descripcion VARCHAR(150)
);

CREATE TABLE PROVEEDOR (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
    rfc VARCHAR(13) NOT NULL UNIQUE,
    nombre_empresa VARCHAR(100) NOT NULL,
    telefono_proveedor VARCHAR(15) NOT NULL,
    email_proveedor VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE PRODUCTO (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre_producto VARCHAR(100) NOT NULL,
    descripcion_producto VARCHAR(200),
    precio_compra DECIMAL(10,2) NOT NULL CHECK (precio_compra >= 0),
    precio_venta DECIMAL(10,2) NOT NULL CHECK (precio_venta >= 0),
    stock INT NOT NULL CHECK (stock >= 0),
    id_categoria INT NOT NULL,
    id_proveedor INT NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES CATEGORIA(id_categoria),
    FOREIGN KEY (id_proveedor) REFERENCES PROVEEDOR(id_proveedor)
);

CREATE TABLE CLIENTE (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre_cliente VARCHAR(50) NOT NULL,
    ap_paterno_cliente VARCHAR(50) NOT NULL,
    ap_materno_cliente VARCHAR(50),
    telefono_cliente VARCHAR(15) NOT NULL,
    -- UNIQUE: es la restriccion que captura sp_alta_cliente con su HANDLER.
    email_cliente VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE EMPLEADO (
    id_empleado INT AUTO_INCREMENT PRIMARY KEY,
    nombre_empleado VARCHAR(50) NOT NULL,
    ap_paterno_empleado VARCHAR(50) NOT NULL,
    ap_materno_empleado VARCHAR(50),
    puesto VARCHAR(50) NOT NULL,
    sueldo DECIMAL(10,2) NOT NULL CHECK (sueldo >= 0),
    telefono_empleado VARCHAR(15) NOT NULL,
    email_empleado VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE VENTA (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME NOT NULL,
    total DECIMAL(10,2) NOT NULL CHECK (total >= 0),
    -- Por donde entro la compra. La app movil manda 'APP'; el trigger de
    -- seguimiento solo registra las que llegan por APP o WEB.
    canal ENUM('APP','WEB','MOSTRADOR') NOT NULL DEFAULT 'APP',
    id_cliente INT NOT NULL,
    id_empleado INT NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente),
    FOREIGN KEY (id_empleado) REFERENCES EMPLEADO(id_empleado)
);

-- Tabla puente de la relacion muchos a muchos VENTA <-> PRODUCTO.
CREATE TABLE DETALLE_VENTA (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    -- precio_unitario se guarda aunque exista en PRODUCTO: es una foto del
    -- precio al momento de la venta. Si manana sube el precio, los tickets
    -- viejos no deben cambiar. No es redundancia, es dato historico.
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    FOREIGN KEY (id_venta) REFERENCES VENTA(id_venta),
    FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);

-- Bitacora que llena el trigger de atencion a clientes.
CREATE TABLE SEGUIMIENTO_CLIENTE (
    id_seguimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    -- Igual que precio_unitario: foto del nombre al momento de la compra.
    -- El reto pide explicitamente el nombre en la tabla de seguimiento.
    nombre_cliente VARCHAR(160) NOT NULL,
    canal ENUM('APP','WEB','MOSTRADOR') NOT NULL,
    total_compra DECIMAL(10,2) NOT NULL,
    fecha_hora DATETIME NOT NULL,
    atendido TINYINT(1) NOT NULL DEFAULT 0,
    id_venta INT NULL,
    -- ON DELETE SET NULL: cancelar una venta NO debe borrar ni bloquear su
    -- registro de seguimiento. Con la regla por defecto, el DELETE de una
    -- venta fallaria por llave foranea.
    FOREIGN KEY (id_venta) REFERENCES VENTA(id_venta) ON DELETE SET NULL,
    -- ON DELETE CASCADE: si se da de baja al cliente, su bitacora se va con el
    -- y el borrado del cliente sigue funcionando.
    FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente) ON DELETE CASCADE
);

-- Indices para las consultas de reportes, que filtran y agrupan por fecha.
CREATE INDEX idx_venta_fecha ON VENTA (fecha);
CREATE INDEX idx_seguimiento_fecha ON SEGUIMIENTO_CLIENTE (fecha_hora);
