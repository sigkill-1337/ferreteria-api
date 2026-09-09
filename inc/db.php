<?php
declare(strict_types=1);

/**
 * NOTA: este repo es público. Los valores de abajo son placeholders.
 * Las credenciales reales (password de BD y API key) NO se suben a git:
 * viven únicamente en el servidor y en el repo privado de documentación.
 */
const API_KEY = 'REEMPLAZA_CON_TU_API_KEY';

function require_api_key(): void
{
    $provided = $_SERVER['HTTP_X_API_KEY'] ?? '';

    if ($provided === '' || !hash_equals(API_KEY, $provided)) {
        json_error(401, 'API key invalida o ausente. Envie el header X-API-Key.');
    }
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $host = '127.0.0.1';
        $dbname = 'ferreteria';
        $user = 'ferreteria_api';
        $pass = 'REEMPLAZA_CON_TU_PASSWORD';

        $dsn = "mysql:host={$host};dbname={$dbname};charset=utf8mb4";
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $pdo;
}

function json_response(int $statusCode, $data): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

function json_error(int $statusCode, string $message): void
{
    json_response($statusCode, ['error' => $message]);
}
