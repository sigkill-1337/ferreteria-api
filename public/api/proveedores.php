<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

function proveedor_select(): string
{
    return 'SELECT id_proveedor, rfc, nombre_empresa, telefono_proveedor, email_proveedor
            FROM PROVEEDOR';
}

function fetch_proveedor(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(proveedor_select() . ' WHERE id_proveedor = :id');
    $stmt->execute(['id' => $id]);
    $proveedor = $stmt->fetch();

    if (!$proveedor) {
        json_error(404, 'Proveedor no encontrado.');
    }

    return $proveedor;
}

function proveedor_input(): array
{
    $body = read_json_body();

    $rfc = mb_strtoupper((string) field_string($body, 'rfc', 13));
    if (!preg_match('/^[\p{L}\p{N}&]{12,13}$/u', $rfc)) {
        json_error(400, 'El campo rfc debe tener 12 o 13 caracteres alfanumericos.');
    }

    return [
        'rfc' => $rfc,
        'nombre_empresa' => field_string($body, 'nombre_empresa', 100),
        'telefono_proveedor' => field_phone($body, 'telefono_proveedor'),
        'email_proveedor' => field_email($body, 'email_proveedor', 100),
    ];
}

try {
    $pdo = db();
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_proveedor($pdo, $id));
        }

        $stmt = $pdo->query(proveedor_select() . ' ORDER BY id_proveedor');
        json_response(200, $stmt->fetchAll());
    }

    if ($method === 'POST') {
        $data = proveedor_input();

        $stmt = $pdo->prepare(
            'INSERT INTO PROVEEDOR (rfc, nombre_empresa, telefono_proveedor, email_proveedor)
             VALUES (:rfc, :nombre_empresa, :telefono_proveedor, :email_proveedor)'
        );
        $stmt->execute($data);

        json_response(201, fetch_proveedor($pdo, (int) $pdo->lastInsertId()));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $data = proveedor_input();

        assert_exists($pdo, 'PROVEEDOR', 'id_proveedor', $id, 'El proveedor indicado');

        $stmt = $pdo->prepare(
            'UPDATE PROVEEDOR
                SET rfc = :rfc,
                    nombre_empresa = :nombre_empresa,
                    telefono_proveedor = :telefono_proveedor,
                    email_proveedor = :email_proveedor
              WHERE id_proveedor = :id_proveedor'
        );
        $stmt->execute($data + ['id_proveedor' => $id]);

        json_response(200, fetch_proveedor($pdo, $id));
    }

    // DELETE
    $id = require_query_id();

    $stmt = $pdo->prepare('DELETE FROM PROVEEDOR WHERE id_proveedor = :id');
    $stmt->execute(['id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error(404, 'Proveedor no encontrado.');
    }

    json_response(200, ['mensaje' => 'Proveedor eliminado.', 'id_proveedor' => $id]);
} catch (Throwable $e) {
    pdo_error($e);
}
