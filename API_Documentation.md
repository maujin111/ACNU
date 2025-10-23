# API Documentation for AnfibiusBack Client Agent

This document outlines how to interact with the AnfibiusBack API endpoints.

## 1. Authentication (Login)

To access most API endpoints, you first need to authenticate and obtain an authorization token.

### Endpoint

`POST /anfibiusback/api/usuarios/login` (Assuming a standard login endpoint)

### Request

**Headers:**

* `Content-Type: application/json`

**Body (JSON):**

```json
{
    "empr_ruc": "ruc_empresa",
    "usua_nombre": "nombre_usuario",
    "usua_password": "your_password",
    "ubicacion": "" //siempre vacio,
    "sistema": "" // siempre vacio
}
```

### Response

**Status:** `200 OK` on success.
**Headers:**

* `Content-Type: application/json`

**Body (JSON):**

```json
{"status" : "ok", 
  "code" : 200, 
  "data": 
    { "JWT":"nHyuf8y9l0ijGNMs4tpmaVv0HvuOLo0KuvQCM73lUNnQ3nh25KXmBGvLnXqwPipcMRBfbgYMSU1N/JxOWeE2uYAJ4X1/gOGP9p+RGfmKiHKVs3lWyLwOVhsYtuo2LdcHa5txEgZMkkWUQBPG2S6VOTkuUK0ZA/5bIXMA4WDdKmYBgeJ8vTee2Z+ogA9S1Z0R/KQ4Vm5U6fbwKep6ow0xUtQEkAv/ujPU5xaJ4ovqVxXgjfbmHCeA2mzivqRjjnAiwEmqJ1DTchZ/LrmCZAJucA3+M/ClHp4WBbTgIdJ0R+AX5j6s7DGowY7xO01hvOar",
"usuario":"{\r\n  \"usua_id\" : 1,\r\n  \"empl_id\" : 1,\r\n  \"usua_nombre\" : \"ADMINISTRADOR\",\r\n  \"usua_password\" : null,\r\n  \"usua_confirmppss\" : null,\r\n  \"usua_estado\" : false,\r\n  \"usua_config\" : null,\r\n  \"usua_imagenperf\" : \"estacion_241/imagenes/personas/1752770101075.jpg\",\r\n  \"perf_id\" : 1,\r\n  \"name\" : \"hola\"\r\n}",
"deuda":true,
"tiempo":20,"intervalo":30},  
"message" : "Sesión Iniciada Correctamente", 
"table" : "usuarios"
}

```

* JWT: This is the JWT (JSON Web Token) that you must include in the `Authorization` header of subsequent requests.
* **`usuario.usua_id`**: The ID of the authenticated user.

### Subsequent Authenticated Requests

For all other secured endpoints, you must include the `token` obtained from login in the `Authorization` header:

**Headers:**

* `Authorization: YOUR_AUTH_TOKEN_HERE`

---

## 2. Get All Employees

This endpoint allows you to retrieve a list of all employees, with optional filtering and pagination.

### Endpoint

`GET /anfibiusback/api/empleados`

### Request

**Headers:**

* `Authorization: YOUR_AUTH_TOKEN_HERE`

**Query Parameters (Optional):**

* `id`: `int` - Filter by a specific employee ID.
* `busqueda`: `string` - Search term for employees.
* `tipoconsul`: `string` - siempre "CExNA".
* `limit`: `int` - Maximum number of results to return.
* `offset`: `int` - Number of results to skip (for pagination).

**Example Request:**
`GET /anfibiusBack/api/empleados?id=&limit=10&offset=0&busqueda=&tipoconsul=CExNA`

### Response

**Status:** `200 OK` on success.
**Headers:**

* `Content-Type: application/json`

**Body (JSON):**

```json
{
  "status": "ok",
  "code": 200,
  "message": "consulta realizada Correctamente",
  "data": [
    {
      "empl_id": 3,
      "pers_nombres": "JORDY ALEXANDER",
      "pers_apellidos": "CALDERON MONTERO",
      "pers_documento": "2350740045",
      "empl_afiliado": false,
      "carg_nombre": "SIN CARGO",
      "area_nombre": "SIN AREA",
      "pers_id": 9,
      "empl_estado": true
    },
    {
      "empl_id": 4,
      "pers_nombres": "ALCIDES ANTONIO",
      "pers_apellidos": "ZAMBRANO CEDEÃO",
      "pers_documento": "1315939247",
      "empl_afiliado": false,
      "carg_nombre": "SIN CARGO",
      "area_nombre": "SIN AREA",
      "pers_id": 18,
      "empl_estado": true
    },
    {
      "empl_id": 2,
      "pers_nombres": "RENE ALEJANDRO",
      "pers_apellidos": "ZAMBRANO CEDEÑO",
      "pers_documento": "1315939239",
      "empl_afiliado": false,
      "carg_nombre": "VENDEDOR",
      "area_nombre": "SIN AREA",
      "pers_id": 3,
      "empl_estado": true
    }
  ],
  "contar": 4,
  "table": "empleados"
}
```

### Models

#### `Empleado` (Simplified)

```json
{
    "empl_id": 1,
    "pers_nombres": "string",
    "pers_apellidos": "string",
    "pers_documento": "string",
    "pers_imagen": "string" // Base64 encoded image, if applicable
    // ... other fields as returned by the API
}
```

---

## 3. Register Fingerprint for an Employee

This endpoint allows you to register a fingerprint (huella) for a specific employee.

### Endpoint

`POST /anfibiusback/api/empleados/registarbiometrico`

### Request

**Headers:**

* `Authorization: YOUR_AUTH_TOKEN_HERE`
* `Content-Type: application/octet-stream`

**Query Parameters:**

* `id`: `int` - The ID of the employee to register the fingerprint for. (e.g., `?id=123`)

**Body (Raw Binary Data):**
The request body should contain the raw binary data of the fingerprint. Do **not** Base64 encode it.

**Example Request (Conceptual):**
`POST /anfibiusback/api/empleados/registarbiometrico?id=123`
(Body contains raw binary fingerprint data)

### Response

**Status:** `200 OK` on success.
**Headers:**

* `Content-Type: application/json`

**Body (JSON):**

```json
{
    "status": "ok",
    "code": 200,
    "message": "consulta realizada Correctamente",
    "data": "Response from DAO (e.g., success message or updated status)"
}
```

**Error Responses:**

* `400 Bad Request`: If the `id` is missing or invalid.
* `500 Internal Server Error`: If there's an error processing the fingerprint data or reading the input stream.

---
