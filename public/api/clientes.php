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
            'SELECT id_cliente, nombre_cliente, ap_paterno_cliente, ap_materno_cliente,
                    telefono_cliente, email_cliente
             FROM CLIENTE WHERE id_cliente = :id'
        );
        $stmt->execute(['id' => $id]);
        $cliente = $stmt->fetch();

        if (!$cliente) {
            json_error(404, 'Cliente no encontrado.');
        }

        json_response(200, $cliente);
    }

    $stmt = $pdo->query(
        'SELECT id_cliente, nombre_cliente, ap_paterno_cliente, ap_materno_cliente,
                telefono_cliente, email_cliente
         FROM CLIENTE ORDER BY id_cliente'
    );
    $clientes = $stmt->fetchAll();

    json_response(200, $clientes);
} catch (Throwable $e) {
    json_error(500, 'Error interno del servidor.');
}
