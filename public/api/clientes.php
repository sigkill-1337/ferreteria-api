<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

function cliente_select(): string
{
    return 'SELECT id_cliente, nombre_cliente, ap_paterno_cliente, ap_materno_cliente,
                   telefono_cliente, email_cliente
            FROM CLIENTE';
}

function fetch_cliente(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(cliente_select() . ' WHERE id_cliente = :id');
    $stmt->execute(['id' => $id]);
    $cliente = $stmt->fetch();

    if (!$cliente) {
        json_error(404, 'Cliente no encontrado.');
    }

    return $cliente;
}

function cliente_input(): array
{
    $body = read_json_body();

    return [
        'nombre_cliente' => field_string($body, 'nombre_cliente', 50),
        'ap_paterno_cliente' => field_string($body, 'ap_paterno_cliente', 50),
        'ap_materno_cliente' => field_string($body, 'ap_materno_cliente', 50, false),
        'telefono_cliente' => field_phone($body, 'telefono_cliente'),
        'email_cliente' => field_email($body, 'email_cliente', 100),
    ];
}

try {
    $pdo = db();
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_cliente($pdo, $id));
        }

        $stmt = $pdo->query(cliente_select() . ' ORDER BY id_cliente');
        json_response(200, $stmt->fetchAll());
    }

    if ($method === 'POST') {
        $data = cliente_input();

        // El alta NO se hace con un INSERT directo: se delega al procedimiento
        // almacenado sp_alta_cliente, que lleva un EXIT HANDLER para el error
        // 1062. Asi la restriccion unica de email_cliente se atrapa dentro de
        // la base de datos y no depende de que PHP interprete la excepcion.
        $stmt = $pdo->prepare(
            'CALL sp_alta_cliente(:nombre, :ap_paterno, :ap_materno, :telefono, :email,
                                  @id_cliente, @codigo, @mensaje)'
        );
        $stmt->execute([
            'nombre' => $data['nombre_cliente'],
            'ap_paterno' => $data['ap_paterno_cliente'],
            'ap_materno' => $data['ap_materno_cliente'] ?? '',
            'telefono' => $data['telefono_cliente'],
            'email' => $data['email_cliente'],
        ]);
        // Hay que cerrar el cursor del CALL antes de leer las variables de
        // salida, o la siguiente consulta falla con "commands out of sync".
        $stmt->closeCursor();

        $salida = $pdo
            ->query('SELECT @id_cliente AS id_cliente, @codigo AS codigo, @mensaje AS mensaje')
            ->fetch();

        $codigo = (int) ($salida['codigo'] ?? 1);
        $mensaje = (string) ($salida['mensaje'] ?? 'No se pudo registrar el cliente.');

        if ($codigo === 1062) {
            json_error(409, $mensaje);
        }
        if ($codigo !== 0) {
            json_error(400, $mensaje);
        }

        json_response(201, fetch_cliente($pdo, (int) $salida['id_cliente']));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $data = cliente_input();

        assert_exists($pdo, 'CLIENTE', 'id_cliente', $id, 'El cliente indicado');

        $stmt = $pdo->prepare(
            'UPDATE CLIENTE
                SET nombre_cliente = :nombre_cliente,
                    ap_paterno_cliente = :ap_paterno_cliente,
                    ap_materno_cliente = :ap_materno_cliente,
                    telefono_cliente = :telefono_cliente,
                    email_cliente = :email_cliente
              WHERE id_cliente = :id_cliente'
        );
        $stmt->execute($data + ['id_cliente' => $id]);

        json_response(200, fetch_cliente($pdo, $id));
    }

    // DELETE
    $id = require_query_id();

    $stmt = $pdo->prepare('DELETE FROM CLIENTE WHERE id_cliente = :id');
    $stmt->execute(['id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error(404, 'Cliente no encontrado.');
    }

    json_response(200, ['mensaje' => 'Cliente eliminado.', 'id_cliente' => $id]);
} catch (Throwable $e) {
    pdo_error($e);
}
