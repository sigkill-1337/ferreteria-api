<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

$method = require_method(['GET', 'POST', 'PUT', 'DELETE']);

function categoria_select(): string
{
    return 'SELECT id_categoria, nombre_categoria, descripcion FROM CATEGORIA';
}

function fetch_categoria(PDO $pdo, int $id): array
{
    $stmt = $pdo->prepare(categoria_select() . ' WHERE id_categoria = :id');
    $stmt->execute(['id' => $id]);
    $categoria = $stmt->fetch();

    if (!$categoria) {
        json_error(404, 'Categoria no encontrada.');
    }

    return $categoria;
}

function categoria_input(): array
{
    $body = read_json_body();

    return [
        'nombre_categoria' => field_string($body, 'nombre_categoria', 50),
        'descripcion' => field_string($body, 'descripcion', 150, false),
    ];
}

try {
    $pdo = db();
    $id = query_id();

    if ($method === 'GET') {
        if ($id !== null) {
            json_response(200, fetch_categoria($pdo, $id));
        }

        $stmt = $pdo->query(categoria_select() . ' ORDER BY id_categoria');
        json_response(200, $stmt->fetchAll());
    }

    if ($method === 'POST') {
        $data = categoria_input();

        $stmt = $pdo->prepare(
            'INSERT INTO CATEGORIA (nombre_categoria, descripcion)
             VALUES (:nombre_categoria, :descripcion)'
        );
        $stmt->execute($data);

        json_response(201, fetch_categoria($pdo, (int) $pdo->lastInsertId()));
    }

    if ($method === 'PUT') {
        $id = require_query_id();
        $data = categoria_input();

        assert_exists($pdo, 'CATEGORIA', 'id_categoria', $id, 'La categoria indicada');

        $stmt = $pdo->prepare(
            'UPDATE CATEGORIA
                SET nombre_categoria = :nombre_categoria,
                    descripcion = :descripcion
              WHERE id_categoria = :id_categoria'
        );
        $stmt->execute($data + ['id_categoria' => $id]);

        json_response(200, fetch_categoria($pdo, $id));
    }

    // DELETE
    $id = require_query_id();

    $stmt = $pdo->prepare('DELETE FROM CATEGORIA WHERE id_categoria = :id');
    $stmt->execute(['id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error(404, 'Categoria no encontrada.');
    }

    json_response(200, ['mensaje' => 'Categoria eliminada.', 'id_categoria' => $id]);
} catch (Throwable $e) {
    pdo_error($e);
}
