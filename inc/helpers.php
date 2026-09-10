<?php
declare(strict_types=1);

/**
 * Helpers compartidos por los endpoints REST.
 *
 * Este archivo es NUEVO: no toca inc/db.php, que en el servidor guarda las
 * credenciales reales. Requiere que db.php ya este cargado (usa json_error).
 */

/**
 * Rechaza cualquier metodo que no este en la lista con 405 y header Allow.
 * Devuelve el metodo verificado.
 */
function require_method(array $allowed): string
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if (!in_array($method, $allowed, true)) {
        header('Allow: ' . implode(', ', $allowed));
        json_error(405, 'Metodo no soportado. Use: ' . implode(', ', $allowed) . '.');
    }

    return $method;
}

/**
 * Lee el ?id= de la query string.
 * Devuelve null si no viene, o corta con 400 si no es un entero positivo.
 */
function query_id(): ?int
{
    if (!isset($_GET['id'])) {
        return null;
    }
    if (!ctype_digit((string) $_GET['id']) || (int) $_GET['id'] < 1) {
        json_error(400, 'El parametro id debe ser un entero positivo.');
    }
    return (int) $_GET['id'];
}

/** Igual que query_id() pero el id es obligatorio. */
function require_query_id(): int
{
    $id = query_id();
    if ($id === null) {
        json_error(400, 'Debe especificar el parametro id.');
    }
    return $id;
}

/** Decodifica el cuerpo JSON de la peticion o corta con 400. */
function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        json_error(400, 'El cuerpo de la peticion esta vacio. Envie JSON.');
    }

    $body = json_decode($raw, true);
    if (!is_array($body)) {
        json_error(400, 'Cuerpo JSON invalido.');
    }

    return $body;
}

/**
 * Texto obligatorio u opcional, recortado y con limite de longitud.
 * Un campo opcional ausente devuelve null; presente pero vacio -> 400.
 */
function field_string(array $body, string $key, int $max, bool $required = true): ?string
{
    if (!array_key_exists($key, $body) || $body[$key] === null) {
        if ($required) {
            json_error(400, "El campo {$key} es obligatorio.");
        }
        return null;
    }

    if (!is_string($body[$key]) && !is_numeric($body[$key])) {
        json_error(400, "El campo {$key} debe ser texto.");
    }

    $value = trim((string) $body[$key]);

    if ($value === '') {
        if ($required) {
            json_error(400, "El campo {$key} no puede estar vacio.");
        }
        return null;
    }

    if (mb_strlen($value) > $max) {
        json_error(400, "El campo {$key} no puede exceder {$max} caracteres.");
    }

    return $value;
}

/** Entero con minimo opcional. */
function field_int(array $body, string $key, bool $required = true, int $min = 0): ?int
{
    if (!array_key_exists($key, $body) || $body[$key] === null || $body[$key] === '') {
        if ($required) {
            json_error(400, "El campo {$key} es obligatorio.");
        }
        return null;
    }

    $value = filter_var($body[$key], FILTER_VALIDATE_INT);
    if ($value === false) {
        json_error(400, "El campo {$key} debe ser un numero entero.");
    }
    if ($value < $min) {
        json_error(400, "El campo {$key} no puede ser menor que {$min}.");
    }

    return $value;
}

/**
 * Decimal no negativo compatible con DECIMAL(10,2).
 * Se devuelve como string para no perder precision en el camino a la BD.
 */
function field_decimal(array $body, string $key, bool $required = true): ?string
{
    if (!array_key_exists($key, $body) || $body[$key] === null || $body[$key] === '') {
        if ($required) {
            json_error(400, "El campo {$key} es obligatorio.");
        }
        return null;
    }

    $value = trim((string) $body[$key]);

    if (!preg_match('/^\d{1,8}(\.\d{1,2})?$/', $value)) {
        json_error(400, "El campo {$key} debe ser un decimal no negativo con maximo 2 decimales (ej. 150.00).");
    }

    return number_format((float) $value, 2, '.', '');
}

/** Correo valido con limite de longitud. */
function field_email(array $body, string $key, int $max, bool $required = true): ?string
{
    $value = field_string($body, $key, $max, $required);
    if ($value === null) {
        return null;
    }
    if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
        json_error(400, "El campo {$key} no es un correo valido.");
    }
    return $value;
}

/**
 * Traduce errores de MariaDB a codigos HTTP con mensaje util para la app.
 * Nunca expone el detalle interno del driver.
 */
function pdo_error(Throwable $e): void
{
    $code = 0;
    if ($e instanceof PDOException && isset($e->errorInfo[1])) {
        $code = (int) $e->errorInfo[1];
    }

    switch ($code) {
        case 1644: // SIGNAL SQLSTATE '45000' lanzado por un trigger nuestro.
            // errorInfo[2] trae el MESSAGE_TEXT que escribimos en el trigger,
            // no detalle interno del driver, asi que es seguro devolverlo.
            $texto = $e instanceof PDOException && isset($e->errorInfo[2])
                ? (string) $e->errorInfo[2]
                : 'La operacion viola una regla de negocio.';
            json_error(409, $texto);
            // no break: json_error termina la ejecucion
        case 1062: // Duplicate entry
            json_error(409, 'Ya existe un registro con ese valor unico (correo, RFC, etc.).');
        case 1451: // Cannot delete or update a parent row
            json_error(409, 'No se puede eliminar: el registro esta referenciado por otros datos.');
        case 1452: // Cannot add or update a child row
            json_error(400, 'Referencia invalida: el registro relacionado no existe.');
        case 4025: // CHECK constraint failed
        case 3819:
            json_error(400, 'Algun valor viola una restriccion de la tabla (revise cantidades y precios).');
        default:
            json_error(500, 'Error interno del servidor.');
    }
}

/** Verifica que exista una fila por id; corta con 400 si no. */
function assert_exists(PDO $pdo, string $table, string $pk, int $id, string $label): void
{
    $stmt = $pdo->prepare("SELECT {$pk} FROM {$table} WHERE {$pk} = :id");
    $stmt->execute(['id' => $id]);
    if (!$stmt->fetch()) {
        json_error(400, "{$label} no existe.");
    }
}

/** Valor de una lista cerrada (columna ENUM). Si no viene, usa el predeterminado. */
function field_enum(array $body, string $key, array $permitidos, string $porDefecto): string
{
    if (!array_key_exists($key, $body) || $body[$key] === null || $body[$key] === '') {
        return $porDefecto;
    }

    $value = strtoupper(trim((string) $body[$key]));

    if (!in_array($value, $permitidos, true)) {
        json_error(400, "El campo {$key} solo acepta: " . implode(', ', $permitidos) . '.');
    }

    return $value;
}

/** Telefono: solo digitos, +, guiones y espacios; 7 a 15 caracteres (VARCHAR(15)). */
function field_phone(array $body, string $key, bool $required = true): ?string
{
    $value = field_string($body, $key, 15, $required);
    if ($value === null) {
        return null;
    }
    if (!preg_match('/^[0-9+\- ]{7,15}$/', $value)) {
        json_error(400, "El campo {$key} debe tener entre 7 y 15 caracteres y solo digitos, +, - o espacios.");
    }
    return $value;
}
