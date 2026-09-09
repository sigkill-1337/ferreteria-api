# Ferretería API

Backend REST en PHP puro (PDO + prepared statements) para el proyecto de la ferretería. Sirve productos, clientes y ventas sobre una base de datos MariaDB.

Este repo es **público** y solo tiene el código fuente. Las credenciales reales (password de la base de datos y API key) están en `inc/db.php` como placeholders — nunca se suben aquí. Viven únicamente en el servidor y en un repo privado de documentación.

## Stack

- Apache 2 + PHP 8.5 (`pdo_mysql`, `bcmath`)
- MariaDB 11.8
- Sin frameworks — PHP plano con PDO

## Estructura

```
inc/
  db.php              # conexión PDO + helpers JSON + validación de API key
public/
  api/
    productos.php      # GET /api/productos.php[?id=]
    clientes.php        # GET /api/clientes.php[?id=]
    ventas.php           # GET /api/ventas.php?id= | POST /api/ventas.php
schema.sql            # esquema completo + datos de muestra
```

`public/` es el DocumentRoot de Apache; `inc/` queda fuera del webroot.

## Configurar credenciales locales

Antes de usar este código en un servidor, edita `inc/db.php` y reemplaza:

```php
const API_KEY = 'REEMPLAZA_CON_TU_API_KEY';
// ...
$pass = 'REEMPLAZA_CON_TU_PASSWORD';
```

por los valores reales de tu entorno. **No los commitees.**

## Base de datos

Carga el esquema y los datos de muestra:

```bash
mysql -u root -p < schema.sql
```

Crea un usuario dedicado para la API (no uses `root`):

```sql
CREATE USER 'ferreteria_api'@'localhost' IDENTIFIED BY 'tu_password_aqui';
GRANT SELECT, INSERT, UPDATE, DELETE ON ferreteria.* TO 'ferreteria_api'@'localhost';
FLUSH PRIVILEGES;
```

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/productos.php` | Lista productos con categoría y proveedor |
| `GET` | `/api/productos.php?id=` | Un producto específico |
| `GET` | `/api/clientes.php` | Lista de clientes |
| `GET` | `/api/ventas.php?id=` | Detalle de una venta con sus productos |
| `POST` | `/api/ventas.php` | Registra una venta (transaccional: calcula totales, inserta detalle, descuenta stock) |

Todas las respuestas son JSON. Todos los endpoints requieren el header `X-API-Key`.

Para la guía completa de integración desde Kotlin (modelos, Retrofit, ejemplos de request/response, códigos de error) ver el repo privado de documentación del proyecto.

## Notas de diseño

- Todos los queries usan *prepared statements* — nunca se concatena SQL.
- `POST /api/ventas.php` corre dentro de una transacción (`BEGIN`/`COMMIT`/`ROLLBACK`): si falta stock o el cliente/empleado no existe, no se escribe nada.
- La API key se valida con `hash_equals()` para evitar timing attacks.
