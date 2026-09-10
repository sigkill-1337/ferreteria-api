<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

function venta_select(): string
{
    return 'SELECT v.id_venta, v.fecha, v.total,
                   c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente,
                   e.id_empleado, e.nombre_empleado, e.ap_paterno_empleado
            FROM VENTA v
            JOIN CLIENTE c ON c.id_cliente = v.id_cliente
            JOIN EMPLEADO e ON e.id_empleado = v.id_empleado';
}

/** Venta con su arreglo de productos. Misma forma que la v1 de la API. */
function fetch_venta(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(venta_select() . ' WHERE v.id_venta = :id');
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
         WHERE d.id_venta = :id
         ORDER BY d.id_detalle'
    );
    $stmt->execute(['id' => $id]);
    $venta['productos'] = $stmt->fetchAll();

    return $venta;
}

/**
 * Valida el arreglo productos del cuerpo y devuelve cantidades agrupadas por
 * id_producto. Agrupar evita que dos lineas del mismo producto pasen la
 * validacion de stock por separado y luego revienten el CHECK (stock >= 0).
 */
function productos_solicitados(array $body): array
{
    if (!isset($body['productos']) || !is_array($body['productos']) || count($body['productos']) === 0) {
        json_error(400, 'productos debe ser un arreglo no vacio.');
    }

    $cantidades = [];

    foreach ($body['productos'] as $item) {
        if (!is_array($item)) {
            json_error(400, 'Cada elemento de productos debe ser un objeto.');
        }

        $idProducto = field_int($item, 'id_producto', true, 1);
        $cantidad = field_int($item, 'cantidad', true, 1);

        $cantidades[$idProducto] = ($cantidades[$idProducto] ?? 0) + $cantidad;
    }

    return $cantidades;
}

/**
 * Bloquea los productos, verifica stock y calcula subtotales y total.
 * Debe llamarse dentro de una transaccion ya abierta.
 */
function calcular_detalles(PDO $pdo, array $cantidades): array
{
    $stmtProducto = $pdo->prepare(
        'SELECT id_producto, precio_venta, stock FROM PRODUCTO WHERE id_producto = :id FOR UPDATE'
    );

    $detalles = [];
    $total = '0.00';

    foreach ($cantidades as $idProducto => $cantidad) {
        $stmtProducto->execute(['id' => $idProducto]);
        $producto = $stmtProducto->fetch();

        if (!$producto) {
            $pdo->rollBack();
            json_error(400, "El producto id {$idProducto} no existe.");
        }

        if ((int) $producto['stock'] < $cantidad) {
            $pdo->rollBack();
            json_error(400, "Stock insuficiente para el producto id {$idProducto}. Disponible: {$producto['stock']}, solicitado: {$cantidad}.");
        }

        $subtotal = bcmul((string) $producto['precio_venta'], (string) $cantidad, 2);
        $total = bcadd($total, $subtotal, 2);

        $detalles[] = [
            'id_producto' => (int) $idProducto,
            'cantidad' => $cantidad,
            'precio_unitario' => $producto['precio_venta'],
            'subtotal' => $subtotal,
        ];
    }

    return [$detalles, $total];
}

/** Inserta el detalle de una venta y descuenta el stock correspondiente. */
function guardar_detalles(PDO $pdo, int $idVenta, array $detalles): void
{
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
}

/** Devuelve al inventario el stock del detalle actual y borra las lineas. */
function revertir_detalles(PDO $pdo, int $idVenta): void
{
    $stmt = $pdo->prepare('SELECT cantidad, id_producto FROM DETALLE_VENTA WHERE id_venta = :id');
    $stmt->execute(['id' => $idVenta]);
    $lineas = $stmt->fetchAll();

    $stmtStock = $pdo->prepare(
        'UPDATE PRODUCTO SET stock = stock + :cantidad WHERE id_producto = :id_producto'
    );

    foreach ($lineas as $linea) {
        $stmtStock->execute([
            'cantidad' => (int) $linea['cantidad'],
            'id_producto' => (int) $linea['id_producto'],
        ]);
    }

    $stmt = $pdo->prepare('DELETE FROM DETALLE_VENTA WHERE id_venta = :id');
    $stmt->execute(['id' => $idVenta]);
}

$pdo = db();

try {
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_venta($pdo, $id));
        }

        $stmt = $pdo->query(
            'SELECT v.id_venta, v.fecha, v.total,
                    c.id_cliente, c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente,
                    e.id_empleado, e.nombre_empleado, e.ap_paterno_empleado,
                    (SELECT COUNT(*) FROM DETALLE_VENTA d WHERE d.id_venta = v.id_venta) AS num_productos
             FROM VENTA v
             JOIN CLIENTE c ON c.id_cliente = v.id_cliente
             JOIN EMPLEADO e ON e.id_empleado = v.id_empleado
             ORDER BY v.id_venta DESC'
        );

        // COUNT(*) puede llegar como string segun el driver; la app espera un
        // entero, asi que se normaliza aqui y no en Kotlin.
        $ventas = $stmt->fetchAll();
        foreach ($ventas as &$venta) {
            $venta['num_productos'] = (int) $venta['num_productos'];
        }
        unset($venta);

        json_response(200, $ventas);
    }

    if ($method === 'POST') {
        $body = read_json_body();
        $idCliente = field_int($body, 'id_cliente', true, 1);
        $idEmpleado = field_int($body, 'id_empleado', true, 1);
        $cantidades = productos_solicitados($body);

        // Se valida fuera de la transaccion para poder cortar con 400 limpio;
        // si alguien borra la fila entre medias, la FK lo atrapa igual.
        assert_exists($pdo, 'CLIENTE', 'id_cliente', $idCliente, 'El id_cliente indicado');
        assert_exists($pdo, 'EMPLEADO', 'id_empleado', $idEmpleado, 'El id_empleado indicado');

        $pdo->beginTransaction();

        [$detalles, $total] = calcular_detalles($pdo, $cantidades);

        $stmt = $pdo->prepare(
            'INSERT INTO VENTA (fecha, total, id_cliente, id_empleado)
             VALUES (NOW(), :total, :id_cliente, :id_empleado)'
        );
        $stmt->execute([
            'total' => $total,
            'id_cliente' => $idCliente,
            'id_empleado' => $idEmpleado,
        ]);
        $idVenta = (int) $pdo->lastInsertId();

        guardar_detalles($pdo, $idVenta, $detalles);

        $pdo->commit();

        json_response(201, fetch_venta($pdo, $idVenta));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $body = read_json_body();
        $idCliente = field_int($body, 'id_cliente', true, 1);
        $idEmpleado = field_int($body, 'id_empleado', true, 1);
        $cantidades = productos_solicitados($body);

        assert_exists($pdo, 'CLIENTE', 'id_cliente', $idCliente, 'El id_cliente indicado');
        assert_exists($pdo, 'EMPLEADO', 'id_empleado', $idEmpleado, 'El id_empleado indicado');

        $pdo->beginTransaction();

        $stmt = $pdo->prepare('SELECT id_venta FROM VENTA WHERE id_venta = :id FOR UPDATE');
        $stmt->execute(['id' => $id]);
        if (!$stmt->fetch()) {
            $pdo->rollBack();
            json_error(404, 'Venta no encontrada.');
        }

        // Se repone el stock del detalle anterior antes de validar el nuevo,
        // asi editar una venta no se bloquea por su propio inventario reservado.
        revertir_detalles($pdo, $id);

        [$detalles, $total] = calcular_detalles($pdo, $cantidades);

        $stmt = $pdo->prepare(
            'UPDATE VENTA
                SET total = :total, id_cliente = :id_cliente, id_empleado = :id_empleado
              WHERE id_venta = :id_venta'
        );
        $stmt->execute([
            'total' => $total,
            'id_cliente' => $idCliente,
            'id_empleado' => $idEmpleado,
            'id_venta' => $id,
        ]);

        guardar_detalles($pdo, $id, $detalles);

        $pdo->commit();

        json_response(200, fetch_venta($pdo, $id));
    }

    // DELETE: cancela la venta y devuelve el stock al inventario.
    $id = require_query_id();

    $pdo->beginTransaction();

    $stmt = $pdo->prepare('SELECT id_venta FROM VENTA WHERE id_venta = :id FOR UPDATE');
    $stmt->execute(['id' => $id]);
    if (!$stmt->fetch()) {
        $pdo->rollBack();
        json_error(404, 'Venta no encontrada.');
    }

    revertir_detalles($pdo, $id);

    $stmt = $pdo->prepare('DELETE FROM VENTA WHERE id_venta = :id');
    $stmt->execute(['id' => $id]);

    $pdo->commit();

    json_response(200, [
        'mensaje' => 'Venta cancelada y stock devuelto al inventario.',
        'id_venta' => $id,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    pdo_error($e);
}
