<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_error(400, 'Metodo no soportado. Use GET.');
}

try {
    $pdo = db();

    if (isset($_GET['id'])) {
        if (!ctype_digit($_GET['id'])) {
            json_error(400, 'El parametro id debe ser numerico.');
        }
        $id = (int) $_GET['id'];

        $stmt = $pdo->prepare(
            'SELECT p.id_producto, p.nombre_producto, p.descripcion_producto,
                    p.precio_compra, p.precio_venta, p.stock,
                    c.id_categoria, c.nombre_categoria,
                    pr.id_proveedor, pr.nombre_empresa AS proveedor
             FROM PRODUCTO p
             JOIN CATEGORIA c ON c.id_categoria = p.id_categoria
             JOIN PROVEEDOR pr ON pr.id_proveedor = p.id_proveedor
             WHERE p.id_producto = :id'
        );
        $stmt->execute(['id' => $id]);
        $producto = $stmt->fetch();

        if (!$producto) {
            json_error(404, 'Producto no encontrado.');
        }

        json_response(200, $producto);
    }

    $stmt = $pdo->query(
        'SELECT p.id_producto, p.nombre_producto, p.descripcion_producto,
                p.precio_compra, p.precio_venta, p.stock,
                c.id_categoria, c.nombre_categoria,
                pr.id_proveedor, pr.nombre_empresa AS proveedor
         FROM PRODUCTO p
         JOIN CATEGORIA c ON c.id_categoria = p.id_categoria
         JOIN PROVEEDOR pr ON pr.id_proveedor = p.id_proveedor
         ORDER BY p.id_producto'
    );
    $productos = $stmt->fetchAll();

    json_response(200, $productos);
} catch (Throwable $e) {
    json_error(500, 'Error interno del servidor.');
}
