# Ejemplos de JSON para Sorteos

## Ejemplo 1: Sorteo Simple
```json
{
  "tipo": "SORTEO",
  "id": "sorteo_simple_001",
  "copias": "1",
  "orden": "1",
  "fecha": "2025-06-10",
  "hora": "15:45:00",
  "evento": "Sorteo del Día",  "nombres": "Carlos",
  "apellidos": "Mendoza",
  "cedula": "1234567890",
  "telefono": "0987654321",
  "numeroSorteo": "001",
  "mensaje": "Gracias por participar en nuestro sorteo diario.",
  "pie": "Anfibius Restaurant"
}
```

## Ejemplo 2: Sorteo con Impresora Específica
```json
{
  "tipo": "SORTEO",
  "id": "sorteo_mesa_vip",
  "copias": "3",
  "orden": "1",
  "printerName": "Impresora Mesa VIP",
  "fecha": "2025-12-24",
  "hora": "20:00:00",
  "evento": "GRAN SORTEO NAVIDEÑO - PREMIO ESPECIAL",  "nombres": "Ana Sofía",
  "apellidos": "Vargas Castillo",
  "cedula": "0987654321",
  "telefono": "0991234567",
  "numeroSorteo": "12345",
  "mensaje": "¡FELICIDADES! Participas en nuestro Gran Sorteo Navideño con premios de hasta $5,000. El sorteo se realizará en vivo el 25 de diciembre a las 8:00 PM.",
  "pie": "Anfibius Restaurant & Bar - Dirección: Av. Principal 123 - Tel: (04) 123-4567 - www.anfibius.com"
}
```

## Ejemplo 3: Sorteo Promocional
```json
{
  "tipo": "SORTEO",
  "id": "promo_verano_2025",
  "copias": "2",
  "orden": "1",
  "fecha": "2025-07-15",
  "hora": "18:30:00",
  "evento": "Promoción Verano 2025 - Weekend en la Playa",  "nombres": "Luis Fernando",
  "apellidos": "Torres Ramírez",
  "cedula": "1357924680",
  "telefono": "0998765432",
  "numeroSorteo": "VER2025-0892",
  "mensaje": "¡Participas por un increíble weekend en la playa! Incluye hospedaje para 2 personas en hotel 4 estrellas. Sorteo: 31 de julio.",
  "pie": "Promoción válida para clientes frecuentes - Anfibius Restaurant"
}
```

## Ejemplo 4: Sorteo Mínimo (Solo campos requeridos)
```json
{
  "tipo": "SORTEO",
  "id": "mini_sorteo",
  "copias": "1",
  "orden": "1",
  "fecha": "",
  "hora": "",
  "evento": "",  "nombres": "",
  "apellidos": "",
  "cedula": "",
  "telefono": "",
  "numeroSorteo": "999",
  "mensaje": "",
  "pie": ""
}
```

## Estructura de datos para SorteoData:

### Campos obligatorios (en el código):
- `fecha`: string - Fecha del sorteo
- `hora`: string - Hora del sorteo  
- `evento`: string - Nombre/descripción del evento
- `nombres`: string - Nombres del participante
- `apellidos`: string - Apellidos del participante
- `cedula`: string - Número de cédula/documento
- `telefono`: string - Número de teléfono del participante
- `numeroSorteo`: string - Número único del sorteo
- `mensaje`: string - Mensaje personalizado (puede estar vacío)
- `pie`: string - Pie de página (puede estar vacío)

### Campos del PrintRequest:
- `tipo`: "SORTEO"
- `id`: string único para identificar la solicitud
- `copias`: string con número de copias a imprimir
- `orden`: string con orden de impresión
- `printerName`: (opcional) nombre específico de impresora

### Métodos adicionales disponibles:
- `nombreCompleto`: getter que concatena nombres + apellidos
