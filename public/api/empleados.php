<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

function empleado_select(): string
{
    return 'SELECT id_empleado, nombre_empleado, ap_paterno_empleado, ap_materno_empleado,
                   puesto, sueldo, telefono_empleado, email_empleado
            FROM EMPLEADO';
}

function fetch_empleado(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(empleado_select() . ' WHERE id_empleado = :id');
    $stmt->execute(['id' => $id]);
    $empleado = $stmt->fetch();

    if (!$empleado) {
        json_error(404, 'Empleado no encontrado.');
    }

    return $empleado;
}

function empleado_input(): array
{
    $body = read_json_body();

    return [
        'nombre_empleado' => field_string($body, 'nombre_empleado', 50),
        'ap_paterno_empleado' => field_string($body, 'ap_paterno_empleado', 50),
        'ap_materno_empleado' => field_string($body, 'ap_materno_empleado', 50, false),
        'puesto' => field_string($body, 'puesto', 50),
        'sueldo' => field_decimal($body, 'sueldo'),
        'telefono_empleado' => field_phone($body, 'telefono_empleado'),
        'email_empleado' => field_email($body, 'email_empleado', 100),
    ];
}

try {
    $pdo = db();
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_empleado($pdo, $id));
        }

        $stmt = $pdo->query(empleado_select() . ' ORDER BY id_empleado');
        json_response(200, $stmt->fetchAll());
    }

    if ($method === 'POST') {
        $data = empleado_input();

        $stmt = $pdo->prepare(
            'INSERT INTO EMPLEADO (nombre_empleado, ap_paterno_empleado, ap_materno_empleado,
                                   puesto, sueldo, telefono_empleado, email_empleado)
             VALUES (:nombre_empleado, :ap_paterno_empleado, :ap_materno_empleado,
                     :puesto, :sueldo, :telefono_empleado, :email_empleado)'
        );
        $stmt->execute($data);

        json_response(201, fetch_empleado($pdo, (int) $pdo->lastInsertId()));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $data = empleado_input();

        assert_exists($pdo, 'EMPLEADO', 'id_empleado', $id, 'El empleado indicado');

        $stmt = $pdo->prepare(
            'UPDATE EMPLEADO
                SET nombre_empleado = :nombre_empleado,
                    ap_paterno_empleado = :ap_paterno_empleado,
                    ap_materno_empleado = :ap_materno_empleado,
                    puesto = :puesto,
                    sueldo = :sueldo,
                    telefono_empleado = :telefono_empleado,
                    email_empleado = :email_empleado
              WHERE id_empleado = :id_empleado'
        );
        $stmt->execute($data + ['id_empleado' => $id]);

        json_response(200, fetch_empleado($pdo, $id));
    }

    // DELETE
    $id = require_query_id();

    $stmt = $pdo->prepare('DELETE FROM EMPLEADO WHERE id_empleado = :id');
    $stmt->execute(['id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error(404, 'Empleado no encontrado.');
    }

    json_response(200, ['mensaje' => 'Empleado eliminado.', 'id_empleado' => $id]);
} catch (Throwable $e) {
    pdo_error($e);
}
