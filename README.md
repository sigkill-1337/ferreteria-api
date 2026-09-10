# Ferretería API

Backend REST en PHP puro (PDO + prepared statements) para el proyecto de la ferretería. Expone CRUD completo sobre productos, clientes, empleados, categorías, proveedores y ventas, contra una base de datos MariaDB.

Este repo es **público** y solo tiene el código fuente. Las credenciales reales (password de la base de datos y API key) están en `inc/db.php` como placeholders — nunca se suben aquí. Viven únicamente en el servidor.

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
    clientes.php       # CRUD de clientes
    empleados.php      # CRUD de empleados
    categorias.php     # CRUD de categorías
    proveedores.php    # CRUD de proveedores
    ventas.php         # CRUD de ventas (transaccional, mueve stock)
schema.sql             # esquema completo
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

Carga el esquema:

```bash
mysql -u root -p < schema.sql
```

Crea un usuario dedicado para la API (no uses `root`):

```sql
CREATE USER 'ferreteria_api'@'localhost' IDENTIFIED BY 'tu_password_aqui';
GRANT SELECT, INSERT, UPDATE, DELETE ON ferreteria.* TO 'ferreteria_api'@'localhost';
FLUSH PRIVILEGES;
```

## Instalar en el servidor

```bash
git clone https://github.com/sigkill-1337/ferreteria-api.git
cd ferreteria-api

# copia a tu ruta real de despliegue
sudo cp -r inc /var/www/ferreteria/
sudo cp -r public /var/www/ferreteria/

# pon las credenciales reales (este archivo NO se sobrescribe en actualizaciones)
sudo nano /var/www/ferreteria/inc/db.php

sudo chown -R www-data:www-data /var/www/ferreteria
sudo find /var/www/ferreteria -type f -exec chmod 644 {} \;

# verifica sintaxis antes de dar el deploy por bueno
php -l /var/www/ferreteria/inc/helpers.php
for f in /var/www/ferreteria/public/api/*.php; do php -l "$f"; done
```

### Actualizar un servidor que ya está corriendo

Respalda y copia **todo menos `inc/db.php`**, que guarda las credenciales del servidor:

```bash
sudo cp -r /var/www/ferreteria/public/api /var/www/ferreteria/public/api.bak
sudo cp inc/helpers.php   /var/www/ferreteria/inc/
sudo cp public/api/*.php  /var/www/ferreteria/public/api/
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
  "productos": [
    { "id_producto": 1, "cantidad": 3 },
    { "id_producto": 5, "cantidad": 2 }
  ]
}
```

Responde `201` con la venta completa, igual que `GET ?id=`.

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

## Notas de diseño

- Todos los queries usan *prepared statements* — nunca se concatena SQL.
- La API key se valida con `hash_equals()` para evitar timing attacks.
- Las escrituras de venta corren dentro de una transacción (`BEGIN`/`COMMIT`/`ROLLBACK`): si falta stock o el cliente/empleado no existe, no se escribe nada.
- Los productos se bloquean con `SELECT ... FOR UPDATE` antes de verificar stock, para que dos ventas simultáneas no vendan el mismo último artículo.
- `POST` y `PUT` de ventas **agrupan cantidades por producto** antes de validar. Si el carrito manda el mismo `id_producto` en dos líneas, se suman: sin eso, cada línea pasaba la validación por separado y el `CHECK (stock >= 0)` reventaba con un `500`.
- Los importes se calculan con `bcmath`, nunca con floats.
- Los errores de MariaDB se traducen a códigos HTTP con mensaje útil; el detalle interno del driver nunca sale al cliente.
