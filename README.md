# Ferretería API

Backend REST en PHP puro (PDO + prepared statements) para el proyecto de la ferretería. Expone CRUD completo sobre productos, clientes, empleados, categorías, proveedores y ventas, más un endpoint de reportes que ejecuta procedimientos almacenados y consultas agrupadas, contra una base de datos MariaDB.

Este repo tiene **solo el código fuente**. Las credenciales reales (password de la base de datos y API key) están en `inc/db.php` como placeholders y nunca se suben aquí: viven únicamente en el servidor. Eso se mantiene aunque el repositorio sea privado, para que abrirlo al público más adelante no obligue a reescribir el historial.

Repos del proyecto:

| Repo | Contiene |
|---|---|
| `ferreteria-api` | Este: backend PHP y scripts SQL |
| `ferreteria-app` | App Android (Kotlin + Jetpack Compose) |
| `ferreteria-api-docs` | Documentación de integración y modelo de datos |

## Stack

- Apache 2 + PHP 8.5 (`pdo_mysql`, `bcmath`, `mbstring`)
- MariaDB 11.8
- Sin frameworks — PHP plano con PDO

## Estructura

```
inc/
  db.php               # conexión PDO + helpers JSON + validación de API key
  helpers.php          # validación de campos, cuerpo JSON, mapeo de errores PDO → HTTP
public/
  api/
    productos.php      # CRUD de productos
    clientes.php       # CRUD de clientes (el alta pasa por sp_alta_cliente)
    empleados.php      # CRUD de empleados
    categorias.php     # CRUD de categorías
    proveedores.php    # CRUD de proveedores
    ventas.php         # CRUD de ventas (transaccional, mueve stock)
    reportes.php       # procedimientos almacenados y consultas agrupadas
sql/
  01-esquema.sql          # DDL de las 8 tablas
  02-programabilidad.sql  # procedimientos almacenados y triggers
  03-datos-muestra.sql    # datos de prueba (5+ registros por tabla)
  04-consultas-avanzadas.sql  # JOIN, UNION, ORDER BY, GROUP BY y fechas
  05-migracion-servidor.sql   # solo para una base que ya está en producción
```

`public/` es el DocumentRoot de Apache; `inc/` queda fuera del webroot.

## Configurar credenciales locales

Antes de usar este código en un servidor, edita `inc/db.php` y reemplaza:

```php
const API_KEY = 'REEMPLAZA_CON_TU_API_KEY';
// ...
$pass = 'REEMPLAZA_CON_TU_PASSWORD';
```

Genera una API key nueva con:

```bash
openssl rand -hex 32
```

**No commitees ninguno de los dos valores.**

## Base de datos

Instalación desde cero, en este orden:

```bash
mysql -u root -p < sql/01-esquema.sql
mysql -u root -p ferreteria < sql/02-programabilidad.sql
mysql -u root -p ferreteria < sql/03-datos-muestra.sql
```

El orden importa: los triggers se crean **antes** de cargar los datos, así el de
seguimiento se dispara con las ventas de muestra y la bitácora queda poblada
sola. Al terminar, `03` imprime cuántas filas dejó en `SEGUIMIENTO_CLIENTE`.

Si la base **ya está corriendo con datos**, no uses `03`: aplica en su lugar

```bash
mysql -u root -p ferreteria < sql/05-migracion-servidor.sql
mysql -u root -p ferreteria < sql/02-programabilidad.sql
```

Crea un usuario dedicado para la API (no uses `root`):

```sql
CREATE USER 'ferreteria_api'@'localhost' IDENTIFIED BY 'tu_password_aqui';
GRANT SELECT, INSERT, UPDATE, DELETE ON ferreteria.* TO 'ferreteria_api'@'localhost';
-- Imprescindible: sin EXECUTE el usuario no puede hacer CALL a los
-- procedimientos, y tanto reportes.php como el alta de clientes fallarian.
GRANT EXECUTE ON ferreteria.* TO 'ferreteria_api'@'localhost';
FLUSH PRIVILEGES;
```

Si el usuario ya existía de antes, basta con darle el permiso que falta:

```sql
GRANT EXECUTE ON ferreteria.* TO 'ferreteria_api'@'localhost';
FLUSH PRIVILEGES;
```

## Instalar en el servidor

```bash
git clone https://github.com/sigkill-1337/ferreteria-api.git
cd ferreteria-api

# copia a tu ruta real de despliegue
sudo cp -r inc /var/www/ferreteria-api/
sudo cp -r public /var/www/ferreteria-api/

# pon las credenciales reales (este archivo NO se sobrescribe en actualizaciones)
sudo nano /var/www/ferreteria-api/inc/db.php

sudo chown -R www-data:www-data /var/www/ferreteria-api
sudo find /var/www/ferreteria-api -type f -exec chmod 644 {} \;

# verifica sintaxis antes de dar el deploy por bueno
php -l /var/www/ferreteria-api/inc/helpers.php
for f in /var/www/ferreteria-api/public/api/*.php; do php -l "$f"; done
```

### Actualizar un servidor que ya está corriendo

Respalda y copia **todo menos `inc/db.php`**, que guarda las credenciales del servidor:

```bash
sudo cp -r /var/www/ferreteria-api/public/api /var/www/ferreteria-api/public/api.bak
sudo cp inc/helpers.php   /var/www/ferreteria-api/inc/
sudo cp public/api/*.php  /var/www/ferreteria-api/public/api/
```

No hace falta reiniciar Apache. Con opcache activo: `sudo systemctl reload apache2`.

### Requisitos del entorno

- `pdo_mysql` y `bcmath`.
- `mbstring` — lo usan las validaciones de longitud y el RFC. Verifica con `php -m | grep mbstring`.
- Apache debe dejar pasar `PUT` y `DELETE`. La configuración por defecto lo hace; solo falla si hay un `<LimitExcept GET POST>` en el vhost o un `.htaccess` que los bloquee.

## Endpoints

Todos requieren el header `X-API-Key`. Todas las respuestas son JSON.

| Recurso | GET lista | GET uno | POST crear | PUT editar | DELETE |
|---|---|---|---|---|---|
| `/api/productos.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |
| `/api/clientes.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |
| `/api/empleados.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |
| `/api/categorias.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |
| `/api/proveedores.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |
| `/api/ventas.php` | ✅ | `?id=` | ✅ | `?id=` | `?id=` |

`/api/reportes.php` es de solo lectura y se selecciona con `?tipo=`:

| `tipo` | Qué devuelve | De dónde sale |
|---|---|---|
| `ventas-dia&fecha=AAAA-MM-DD` | Desglose de las ventas del día y su suma | `sp_ventas_del_dia` |
| `clientes-trimestre&anio=2026` | Clientes con pedidos del 1 de enero al 31 de marzo | `sp_clientes_vigentes_trimestre` |
| `top-productos` | Productos ordenados por piezas vendidas | `GROUP BY` sobre `DETALLE_VENTA` |
| `ventas-por-canal` | Monto y porcentaje por canal de compra | `GROUP BY` sobre `VENTA.canal` |
| `directorio` | Clientes y empleados en una sola lista | `UNION` |
| `seguimiento&limite=50` | Bitácora de compras en línea | Trigger `trg_venta_seguimiento` |

Sin `tipo`, devuelve la lista de reportes disponibles.

`PUT` es reemplazo completo: manda todos los campos editables, no solo los que cambiaron.

### Ventas

`ventas.php` es el único endpoint que no es un CRUD plano sobre una tabla:

- `GET` sin `id` lista todas las ventas con `num_productos`, sin el arreglo `productos`, más reciente primero.
- `GET ?id=` devuelve la venta con su arreglo `productos` completo.
- `POST` recibe solo `id_cliente`, `id_empleado` y una lista de `{id_producto, cantidad}`. El servidor busca los precios, calcula subtotales y total con `bcmath`, inserta en `VENTA` y `DETALLE_VENTA` y descuenta el stock, todo dentro de una transacción.
- `PUT ?id=` repone al inventario el stock del detalle anterior, valida el nuevo detalle y reescribe la venta. La `fecha` original no se toca.
- `DELETE ?id=` cancela la venta: devuelve el stock al inventario, borra el detalle y borra la venta.

Ejemplo de `POST /api/ventas.php`:

```json
{
  "id_cliente": 2,
  "id_empleado": 3,
  "canal": "APP",
  "productos": [
    { "id_producto": 1, "cantidad": 3 },
    { "id_producto": 5, "cantidad": 2 }
  ]
}
```

Responde `201` con la venta completa, igual que `GET ?id=`.

`canal` acepta `APP`, `WEB` o `MOSTRADOR`; si no se manda, se asume `APP`. Las
ventas de `APP` y `WEB` disparan el trigger que las registra en la bitácora de
seguimiento.

## Códigos de error

Los errores siempre tienen la forma `{"error": "mensaje"}`.

| Código | Significado |
|---|---|
| `200` | GET, PUT o DELETE exitoso |
| `201` | Recurso creado |
| `400` | Campo faltante o inválido, JSON malformado, stock insuficiente, referencia inexistente |
| `401` | Falta el header `X-API-Key` o no coincide |
| `404` | El recurso consultado no existe |
| `405` | Método no permitido; la respuesta incluye el header `Allow` |
| `409` | Valor único duplicado (correo, RFC), o borrado bloqueado por registros que dependen de él |
| `500` | Error interno del servidor |

## Procedimientos almacenados y triggers

Viven en `sql/02-programabilidad.sql`.

| Objeto | Qué hace |
|---|---|
| `sp_ventas_del_dia(fecha)` | Devuelve dos resultados: el desglose de las ventas de esa fecha y el resumen con la suma, el ticket promedio y la venta mayor |
| `sp_clientes_vigentes_trimestre(anio)` | Clientes que compraron entre el 1 de enero y el 31 de marzo, con su número de pedidos y monto |
| `sp_alta_cliente(...)` | Da de alta un cliente y **atrapa la violación de la restricción única** de `email_cliente`: devuelve `codigo = 1062` y un mensaje en vez de tronar |
| `trg_producto_no_duplicado_ins/upd` | Impiden que un mismo proveedor tenga dos productos con el mismo nombre, al insertar y al actualizar |
| `trg_venta_seguimiento` | Con cada venta de canal `APP` o `WEB`, escribe nombre del cliente, fecha y hora en `SEGUIMIENTO_CLIENTE` |

Tres decisiones que vale la pena conocer:

- **`TRY/CATCH` es sintaxis de SQL Server.** En MariaDB el equivalente es
  `DECLARE ... HANDLER` para atrapar y `SIGNAL` para lanzar. Es lo que usan
  `sp_alta_cliente` y los triggers de inventario.
- **Los duplicados de producto se controlan con trigger, no con `UNIQUE`.**
  Un índice único sería la solución normal, pero entonces el trigger nunca
  llegaría a dispararse. El trigger lanza `SQLSTATE '45000'`, que llega a PHP
  como error 1644 y sale al cliente como `409` con el texto del `MESSAGE_TEXT`.
- **`SEGUIMIENTO_CLIENTE` guarda el nombre del cliente además de su id.** Es
  una foto del dato al momento de la compra, igual que `precio_unitario` en
  `DETALLE_VENTA`: no es redundancia, es dato histórico.

## Notas de diseño

- Todos los queries usan *prepared statements* — nunca se concatena SQL.
- La API key se valida con `hash_equals()` para evitar timing attacks.
- Las escrituras de venta corren dentro de una transacción (`BEGIN`/`COMMIT`/`ROLLBACK`): si falta stock o el cliente/empleado no existe, no se escribe nada.
- Los productos se bloquean con `SELECT ... FOR UPDATE` antes de verificar stock, para que dos ventas simultáneas no vendan el mismo último artículo.
- `POST` y `PUT` de ventas **agrupan cantidades por producto** antes de validar. Si el carrito manda el mismo `id_producto` en dos líneas, se suman: sin eso, cada línea pasaba la validación por separado y el `CHECK (stock >= 0)` reventaba con un `500`.
- Los importes se calculan con `bcmath`, nunca con floats.
- Los errores de MariaDB se traducen a códigos HTTP con mensaje útil; el detalle interno del driver nunca sale al cliente.
- `VENTA.canal` distingue si la compra entró por la app, por el sitio web o en el mostrador. El trigger de seguimiento solo registra las dos primeras: a la de mostrador ya se le atendió en persona.
- `SEGUIMIENTO_CLIENTE` referencia a `VENTA` con `ON DELETE SET NULL`. Con la regla por defecto, cancelar una venta fallaría por llave foránea; así la bitácora sobrevive a la cancelación sin bloquearla.
