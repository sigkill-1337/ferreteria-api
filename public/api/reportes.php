<?php
declare(strict_types=1);
require __DIR__ . '/../../inc/db.php';
require __DIR__ . '/../../inc/helpers.php';

header('Content-Type: application/json; charset=utf-8');

require_api_key();

require_method(['GET']);

/**
 * Reportes de solo lectura. Cada uno expone una de las estructuras de SQL que
 * pide el proyecto, para que la app pueda mostrarlas funcionando:
 *
 *   ventas-dia          -> procedimiento sp_ventas_del_dia
 *   clientes-trimestre  -> procedimiento sp_clientes_vigentes_trimestre
 *   top-productos       -> GROUP BY sobre DETALLE_VENTA
 *   directorio          -> UNION de CLIENTE y EMPLEADO
 *   seguimiento         -> bitacora que llena el trigger trg_venta_seguimiento
 *   ventas-por-canal    -> GROUP BY sobre VENTA.canal
 */
const TIPOS = [
    'ventas-dia',
    'clientes-trimestre',
    'top-productos',
    'directorio',
    'seguimiento',
    'ventas-por-canal',
];

$tipo = isset($_GET['tipo']) ? strtolower(trim((string) $_GET['tipo'])) : '';

if ($tipo === '') {
    json_response(200, [
        'reportes' => TIPOS,
        'uso' => 'GET /api/reportes.php?tipo=<reporte>',
    ]);
}

if (!in_array($tipo, TIPOS, true)) {
    json_error(400, 'Reporte no reconocido. Use uno de: ' . implode(', ', TIPOS) . '.');
}

try {
    $pdo = db();

    switch ($tipo) {
        case 'ventas-dia':
            json_response(200, ventasDelDia($pdo));

        case 'clientes-trimestre':
            json_response(200, clientesDelTrimestre($pdo));

        case 'top-productos':
            json_response(200, topProductos($pdo));

        case 'directorio':
            json_response(200, directorio($pdo));

        case 'seguimiento':
            json_response(200, seguimiento($pdo));

        case 'ventas-por-canal':
            json_response(200, ventasPorCanal($pdo));
    }
} catch (Throwable $e) {
    pdo_error($e);
}

/**
 * sp_ventas_del_dia devuelve DOS conjuntos de resultados: el desglose de las
 * ventas y el resumen con la suma del dia. PDO los recorre con nextRowset().
 */
function ventasDelDia(PDO $pdo): array
{
    $fecha = isset($_GET['fecha']) ? trim((string) $_GET['fecha']) : date('Y-m-d');

    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $fecha)) {
        json_error(400, 'El parametro fecha debe tener el formato AAAA-MM-DD.');
    }

    $partes = explode('-', $fecha);
    if (!checkdate((int) $partes[1], (int) $partes[2], (int) $partes[0])) {
        json_error(400, "La fecha {$fecha} no existe en el calendario.");
    }

    $stmt = $pdo->prepare('CALL sp_ventas_del_dia(:fecha)');
    $stmt->execute(['fecha' => $fecha]);

    $ventas = $stmt->fetchAll();

    $resumen = [];
    if ($stmt->nextRowset()) {
        $resumen = $stmt->fetchAll();
    }
    $stmt->closeCursor();

    $totales = $resumen[0] ?? [];

    return [
        'fecha' => $fecha,
        'num_ventas' => (int) ($totales['num_ventas'] ?? 0),
        'monto_total' => (string) ($totales['monto_total'] ?? '0.00'),
        'ticket_promedio' => (string) ($totales['ticket_promedio'] ?? '0.00'),
        'venta_mayor' => (string) ($totales['venta_mayor'] ?? '0.00'),
        'ventas' => array_map(static function (array $v): array {
            $v['id_venta'] = (int) $v['id_venta'];
            $v['renglones'] = (int) $v['renglones'];
            $v['piezas'] = (int) ($v['piezas'] ?? 0);
            $v['id_cliente'] = (int) $v['id_cliente'];
            return $v;
        }, $ventas),
    ];
}

/** sp_clientes_vigentes_trimestre: el trimestre pedido del anio pedido. */
function clientesDelTrimestre(PDO $pdo): array
{
    $anio = isset($_GET['anio']) ? (string) $_GET['anio'] : date('Y');

    if (!ctype_digit($anio) || (int) $anio < 2000 || (int) $anio > 2100) {
        json_error(400, 'El parametro anio debe ser un ano entre 2000 y 2100.');
    }

    $trimestre = isset($_GET['trimestre']) ? (string) $_GET['trimestre'] : '1';

    if (!ctype_digit($trimestre) || (int) $trimestre < 1 || (int) $trimestre > 4) {
        json_error(400, 'El parametro trimestre debe ser 1, 2, 3 o 4.');
    }

    $anio = (int) $anio;
    $trimestre = (int) $trimestre;

    $stmt = $pdo->prepare('CALL sp_clientes_vigentes_trimestre(:anio, :trimestre)');
    $stmt->execute(['anio' => $anio, 'trimestre' => $trimestre]);
    $filas = $stmt->fetchAll();
    $stmt->closeCursor();

    // El ultimo dia del trimestre se calcula con 't', que devuelve los dias del
    // mes: evita tener que recordar cual mes tiene 30, 31 o 28.
    $mesInicio = ($trimestre - 1) * 3 + 1;
    $inicio = sprintf('%04d-%02d-01', $anio, $mesInicio);
    $fin = date('Y-m-t', (int) strtotime(sprintf('%04d-%02d-01', $anio, $mesInicio + 2)));

    return [
        'anio' => $anio,
        'trimestre' => $trimestre,
        'periodo' => date('d/m/Y', (int) strtotime($inicio)) . ' al ' . date('d/m/Y', (int) strtotime($fin)),
        'clientes' => array_map(static function (array $c): array {
            $c['id_cliente'] = (int) $c['id_cliente'];
            $c['pedidos'] = (int) $c['pedidos'];
            $c['dias_desde_ultima'] = (int) $c['dias_desde_ultima'];
            return $c;
        }, $filas),
    ];
}

/** GROUP BY: que se vende mas, en piezas y en dinero. */
function topProductos(PDO $pdo): array
{
    $stmt = $pdo->query(
        'SELECT p.id_producto,
                p.nombre_producto,
                cat.nombre_categoria,
                SUM(d.cantidad)            AS piezas_vendidas,
                SUM(d.subtotal)            AS importe_vendido,
                COUNT(DISTINCT d.id_venta) AS aparece_en_ventas
         FROM DETALLE_VENTA d
         INNER JOIN PRODUCTO  p   ON p.id_producto   = d.id_producto
         INNER JOIN CATEGORIA cat ON cat.id_categoria = p.id_categoria
         GROUP BY p.id_producto, p.nombre_producto, cat.nombre_categoria
         ORDER BY piezas_vendidas DESC, importe_vendido DESC'
    );

    return array_map(static function (array $p): array {
        $p['id_producto'] = (int) $p['id_producto'];
        $p['piezas_vendidas'] = (int) $p['piezas_vendidas'];
        $p['aparece_en_ventas'] = (int) $p['aparece_en_ventas'];
        return $p;
    }, $stmt->fetchAll());
}

/** UNION: clientes y empleados en una sola lista, etiquetados por tipo. */
function directorio(PDO $pdo): array
{
    $stmt = $pdo->query(
        "SELECT 'Cliente' AS tipo,
                c.id_cliente AS id,
                CONCAT_WS(' ', c.nombre_cliente, c.ap_paterno_cliente, c.ap_materno_cliente) AS nombre,
                c.telefono_cliente AS telefono,
                c.email_cliente    AS email,
                ''                 AS detalle
         FROM CLIENTE c
         UNION
         SELECT 'Empleado',
                e.id_empleado,
                CONCAT_WS(' ', e.nombre_empleado, e.ap_paterno_empleado, e.ap_materno_empleado),
                e.telefono_empleado,
                e.email_empleado,
                e.puesto
         FROM EMPLEADO e
         ORDER BY tipo ASC, nombre ASC"
    );

    return array_map(static function (array $p): array {
        $p['id'] = (int) $p['id'];
        return $p;
    }, $stmt->fetchAll());
}

/** Bitacora del trigger de atencion a clientes. */
function seguimiento(PDO $pdo): array
{
    $limite = isset($_GET['limite']) && ctype_digit((string) $_GET['limite'])
        ? min(200, max(1, (int) $_GET['limite']))
        : 50;

    $stmt = $pdo->prepare(
        "SELECT s.id_seguimiento,
                s.id_cliente,
                s.nombre_cliente,
                s.canal,
                s.total_compra,
                s.fecha_hora,
                DATE_FORMAT(s.fecha_hora, '%d/%m/%Y %H:%i') AS fecha_legible,
                s.atendido,
                s.id_venta
         FROM SEGUIMIENTO_CLIENTE s
         ORDER BY s.fecha_hora DESC, s.id_seguimiento DESC
         LIMIT :limite"
    );
    // LIMIT no acepta un parametro con nombre en modo no emulado: hay que
    // enlazarlo explicitamente como entero.
    $stmt->bindValue(':limite', $limite, PDO::PARAM_INT);
    $stmt->execute();

    return array_map(static function (array $s): array {
        $s['id_seguimiento'] = (int) $s['id_seguimiento'];
        $s['id_cliente'] = (int) $s['id_cliente'];
        $s['atendido'] = (int) $s['atendido'];
        $s['id_venta'] = $s['id_venta'] === null ? null : (int) $s['id_venta'];
        return $s;
    }, $stmt->fetchAll());
}

/** GROUP BY sobre el canal de compra, con su porcentaje del total. */
function ventasPorCanal(PDO $pdo): array
{
    $stmt = $pdo->query(
        'SELECT v.canal,
                COUNT(*)     AS num_ventas,
                SUM(v.total) AS monto_total,
                ROUND(100 * SUM(v.total) / NULLIF((SELECT SUM(total) FROM VENTA), 0), 1) AS porcentaje
         FROM VENTA v
         GROUP BY v.canal
         ORDER BY monto_total DESC'
    );

    return array_map(static function (array $c): array {
        $c['num_ventas'] = (int) $c['num_ventas'];
        $c['porcentaje'] = (float) ($c['porcentaje'] ?? 0);
        return $c;
    }, $stmt->fetchAll());
}
