<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    handleGet();
} elseif ($method === 'POST') {
    handlePost();
} else {
    json_error(400, 'Metodo no soportado. Use GET o POST.');
}

function handleGet(): void
{
    if (!isset($_GET['id'])) {
        json_error(400, 'Debe especificar el parametro id.');
    }
    if (!ctype_digit($_GET['id'])) {
        json_error(400, 'El parametro id debe ser numerico.');
    }
    $id = (int) $_GET['id'];

    try {
        $pdo = db();

        $stmt = $pdo->prepare(
            'SELECT v.id_venta, v.fecha, v.total,
                    c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente,
                    e.id_empleado, e.nombre_empleado, e.ap_paterno_empleado
             FROM VENTA v
             JOIN CLIENTE c ON c.id_cliente = v.id_cliente
             JOIN EMPLEADO e ON e.id_empleado = v.id_empleado
             WHERE v.id_venta = :id'
        );
        $stmt->execute(['id' => $id]);
        $venta = $stmt->fetch();

        if (!$venta) {
            json_error(404, 'Venta no encontrada.');
        }

        $stmt = $pdo->prepare(
            'SELECT d.id_detalle, d.cantidad, d.precio_unitario, d.subtotal,
                    p.id_producto, p.nombre_producto
             FROM DETALLE_VENTA d
             JOIN PRODUCTO p ON p.id_producto = d.id_producto
             WHERE d.id_venta = :id'
        );
        $stmt->execute(['id' => $id]);
        $venta['productos'] = $stmt->fetchAll();

        json_response(200, $venta);
    } catch (Throwable $e) {
        json_error(500, 'Error interno del servidor.');
    }
}

function handlePost(): void
{
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);

    if (!is_array($body)) {
        json_error(400, 'Cuerpo JSON invalido.');
    }

    if (!isset($body['id_cliente']) || !isset($body['id_empleado']) || !isset($body['productos'])) {
        json_error(400, 'Se requieren id_cliente, id_empleado y productos.');
    }

    $idCliente = filter_var($body['id_cliente'], FILTER_VALIDATE_INT);
    $idEmpleado = filter_var($body['id_empleado'], FILTER_VALIDATE_INT);
    $productos = $body['productos'];

    if ($idCliente === false || $idEmpleado === false) {
        json_error(400, 'id_cliente e id_empleado deben ser numericos.');
    }

    if (!is_array($productos) || count($productos) === 0) {
        json_error(400, 'productos debe ser un arreglo no vacio.');
    }

    foreach ($productos as $item) {
        if (!is_array($item) || !isset($item['id_producto']) || !isset($item['cantidad'])) {
            json_error(400, 'Cada producto requiere id_producto y cantidad.');
        }
        $cantidad = filter_var($item['cantidad'], FILTER_VALIDATE_INT);
        $idProducto = filter_var($item['id_producto'], FILTER_VALIDATE_INT);
        if ($cantidad === false || $cantidad <= 0 || $idProducto === false) {
            json_error(400, 'id_producto y cantidad deben ser numericos validos (cantidad > 0).');
        }
    }

    $pdo = db();

    try {
        $pdo->beginTransaction();

        $stmtCliente = $pdo->prepare('SELECT id_cliente FROM CLIENTE WHERE id_cliente = :id');
        $stmtCliente->execute(['id' => $idCliente]);
        if (!$stmtCliente->fetch()) {
            $pdo->rollBack();
            json_error(400, 'id_cliente no existe.');
        }

        $stmtEmpleado = $pdo->prepare('SELECT id_empleado FROM EMPLEADO WHERE id_empleado = :id');
        $stmtEmpleado->execute(['id' => $idEmpleado]);
        if (!$stmtEmpleado->fetch()) {
            $pdo->rollBack();
            json_error(400, 'id_empleado no existe.');
        }

        $stmtProducto = $pdo->prepare(
            'SELECT id_producto, precio_venta, stock FROM PRODUCTO WHERE id_producto = :id FOR UPDATE'
        );

        $detalles = [];
        $total = '0.00';

        foreach ($productos as $item) {
            $idProducto = (int) $item['id_producto'];
            $cantidad = (int) $item['cantidad'];

            $stmtProducto->execute(['id' => $idProducto]);
            $producto = $stmtProducto->fetch();

            if (!$producto) {
                $pdo->rollBack();
                json_error(400, "El producto id {$idProducto} no existe.");
            }

            if ((int) $producto['stock'] < $cantidad) {
                $pdo->rollBack();
                json_error(400, "Stock insuficiente para el producto id {$idProducto}. Disponible: {$producto['stock']}.");
            }

            $precioUnitario = $producto['precio_venta'];
            $subtotal = bcmul((string) $precioUnitario, (string) $cantidad, 2);
            $total = bcadd($total, $subtotal, 2);

            $detalles[] = [
                'id_producto' => $idProducto,
                'cantidad' => $cantidad,
                'precio_unitario' => $precioUnitario,
                'subtotal' => $subtotal,
            ];
        }

        $stmtVenta = $pdo->prepare(
            'INSERT INTO VENTA (fecha, total, id_cliente, id_empleado) VALUES (NOW(), :total, :id_cliente, :id_empleado)'
        );
        $stmtVenta->execute([
            'total' => $total,
            'id_cliente' => $idCliente,
            'id_empleado' => $idEmpleado,
        ]);
        $idVenta = (int) $pdo->lastInsertId();

        $stmtDetalle = $pdo->prepare(
            'INSERT INTO DETALLE_VENTA (cantidad, precio_unitario, subtotal, id_venta, id_producto)
             VALUES (:cantidad, :precio_unitario, :subtotal, :id_venta, :id_producto)'
        );
        $stmtStock = $pdo->prepare(
            'UPDATE PRODUCTO SET stock = stock - :cantidad WHERE id_producto = :id_producto'
        );

        foreach ($detalles as $d) {
            $stmtDetalle->execute([
                'cantidad' => $d['cantidad'],
                'precio_unitario' => $d['precio_unitario'],
                'subtotal' => $d['subtotal'],
                'id_venta' => $idVenta,
                'id_producto' => $d['id_producto'],
            ]);
            $stmtStock->execute([
                'cantidad' => $d['cantidad'],
                'id_producto' => $d['id_producto'],
            ]);
        }

        $pdo->commit();

        json_response(201, [
            'id_venta' => $idVenta,
            'id_cliente' => $idCliente,
            'id_empleado' => $idEmpleado,
            'total' => $total,
            'productos' => $detalles,
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        json_error(500, 'Error interno del servidor al registrar la venta.');
    }
}
