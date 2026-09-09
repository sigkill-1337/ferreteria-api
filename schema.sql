-- =========================================================
-- Base de datos: Ferreteria
-- Avance de proyecto - Curso de Base de Datos
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
    id_cliente INT NOT NULL,
    id_empleado INT NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente),
    FOREIGN KEY (id_empleado) REFERENCES EMPLEADO(id_empleado)
);

CREATE TABLE DETALLE_VENTA (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal DECIMAL(10,2) NOT NULL CHECK (subtotal >= 0),
    id_venta INT NOT NULL,
    id_producto INT NOT NULL,
    FOREIGN KEY (id_venta) REFERENCES VENTA(id_venta),
    FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);
