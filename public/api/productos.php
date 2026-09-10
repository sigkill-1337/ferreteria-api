<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

/** SELECT con categoria y proveedor ya resueltos. Misma forma que la v1. */
function producto_select(): string
{
    return 'SELECT p.id_producto, p.nombre_producto, p.descripcion_producto,
                   p.precio_compra, p.precio_venta, p.stock,
                   c.id_categoria, c.nombre_categoria,
                   pr.id_proveedor, pr.nombre_empresa AS proveedor
            FROM PRODUCTO p
            JOIN CATEGORIA c ON c.id_categoria = p.id_categoria
            JOIN PROVEEDOR pr ON pr.id_proveedor = p.id_proveedor';
}

/** Relee un producto ya escrito para devolverlo con sus JOINs. */
function fetch_producto(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(producto_select() . ' WHERE p.id_producto = :id');
    $stmt->execute(['id' => $id]);
    $producto = $stmt->fetch();

    if (!$producto) {
        json_error(404, 'Producto no encontrado.');
    }

    return $producto;
}

/** Campos validados del cuerpo, compartidos por POST y PUT. */
function producto_input(): array
{
    $body = read_json_body();

    return [
        'nombre_producto' => field_string($body, 'nombre_producto', 100),
        'descripcion_producto' => field_string($body, 'descripcion_producto', 200, false),
        'precio_compra' => field_decimal($body, 'precio_compra'),
        'precio_venta' => field_decimal($body, 'precio_venta'),
        'stock' => field_int($body, 'stock', true, 0),
        'id_categoria' => field_int($body, 'id_categoria', true, 1),
        'id_proveedor' => field_int($body, 'id_proveedor', true, 1),
    ];
}

try {
    $pdo = db();
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_producto($pdo, $id));
        }

        $stmt = $pdo->query(producto_select() . ' ORDER BY p.id_producto');
        json_response(200, $stmt->fetchAll());
    }

    if ($method === 'POST') {
        $data = producto_input();

        assert_exists($pdo, 'CATEGORIA', 'id_categoria', $data['id_categoria'], 'La categoria indicada');
        assert_exists($pdo, 'PROVEEDOR', 'id_proveedor', $data['id_proveedor'], 'El proveedor indicado');

        $stmt = $pdo->prepare(
            'INSERT INTO PRODUCTO (nombre_producto, descripcion_producto, precio_compra,
                                   precio_venta, stock, id_categoria, id_proveedor)
             VALUES (:nombre_producto, :descripcion_producto, :precio_compra,
                     :precio_venta, :stock, :id_categoria, :id_proveedor)'
        );
        $stmt->execute($data);

        json_response(201, fetch_producto($pdo, (int) $pdo->lastInsertId()));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $data = producto_input();

        assert_exists($pdo, 'PRODUCTO', 'id_producto', $id, 'El producto indicado');
        assert_exists($pdo, 'CATEGORIA', 'id_categoria', $data['id_categoria'], 'La categoria indicada');
        assert_exists($pdo, 'PROVEEDOR', 'id_proveedor', $data['id_proveedor'], 'El proveedor indicado');

        $stmt = $pdo->prepare(
            'UPDATE PRODUCTO
                SET nombre_producto = :nombre_producto,
                    descripcion_producto = :descripcion_producto,
                    precio_compra = :precio_compra,
                    precio_venta = :precio_venta,
                    stock = :stock,
                    id_categoria = :id_categoria,
                    id_proveedor = :id_proveedor
              WHERE id_producto = :id_producto'
        );
        $stmt->execute($data + ['id_producto' => $id]);

        json_response(200, fetch_producto($pdo, $id));
    }

    // DELETE
    $id = require_query_id();

    $stmt = $pdo->prepare('DELETE FROM PRODUCTO WHERE id_producto = :id');
    $stmt->execute(['id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error(404, 'Producto no encontrado.');
    }

    json_response(200, ['mensaje' => 'Producto eliminado.', 'id_producto' => $id]);
} catch (Throwable $e) {
    pdo_error($e);
}
