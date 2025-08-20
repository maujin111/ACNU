# Documentación: PrintRequest con tipo SORTEO

## Estructura Completa del PrintRequest

Un `PrintRequest` con tipo SORTEO debe seguir esta estructura:

### Campos del PrintRequest Principal:
- `timestamp`: Marca de tiempo ISO 8601
- `deviceId`: Identificador del dispositivo
- `queuePosition`: Posición en la cola de impresión
- `status`: Estado de la solicitud (pending, processing, completed, error)
- `printJobs`: Array con los trabajos de impresión

### Campos Específicos para SORTEO:
Cada elemento en `printJobs` debe contener:

#### Campos Obligatorios:
- `tipo`: "SORTEO" (fijo)
- `id`: Identificador único del sorteo
- `copias`: Número de copias a imprimir (string)
- `orden`: Orden de impresión (string)
- `printerName`: Nombre de la impresora
- `fecha`: Fecha del sorteo (formato YYYY-MM-DD)
- `hora`: Hora del sorteo (formato HH:MM:SS)
- `evento`: Nombre del evento o sorteo
- `nombres`: Nombres del participante
- `apellidos`: Apellidos del participante
- `cedula`: Cédula/ID del participante
- `telefono`: Número de teléfono del participante
- `numeroSorteo`: Número del sorteo (string, se mostrará en grande)
- `mensaje`: Mensaje personalizado del sorteo
- `pie`: Información del pie de página

#### Ejemplo de Uso:

```json
{
  "timestamp": "2025-01-12T14:30:00.000Z",
  "deviceId": "DEVICE_001",
  "queuePosition": 1,
  "status": "pending",
  "printJobs": [
    {
      "tipo": "SORTEO",
      "id": "sorteo_001",
      "copias": "1",
      "orden": "1",
      "printerName": "Impresora_Termica_Principal",
      "fecha": "2025-01-12",
      "hora": "14:30:00",
      "evento": "Gran Sorteo de Aniversario",      "nombres": "María Elena",
      "apellidos": "González Rodríguez",
      "cedula": "1234567890",
      "telefono": "0987654321",
      "numeroSorteo": "00587",
      "mensaje": "¡Felicitaciones! Has sido seleccionado.",
      "pie": "Válido hasta el 30 de junio | www.empresa.com"
    }
  ]
}
```

## Formato de Impresión

El ticket de sorteo se imprimirá con el siguiente formato:

1. **Encabezado**: "SORTEO" centrado y destacado
2. **Separador**: Línea de asteriscos
3. **Información del evento**: Evento, fecha y hora
4. **Número del sorteo**: Mostrado en tamaño grande y centrado
5. **Información del participante**: Nombre completo, cédula y teléfono
6. **Mensaje personalizado**: Texto del campo mensaje
7. **Pie de página**: Información adicional
8. **Separadores**: Líneas para dividir las secciones

## Validaciones

El sistema validará que:
- Todos los campos obligatorios estén presentes
- El formato de fecha sea válido (YYYY-MM-DD)
- El formato de hora sea válido (HH:MM:SS)
- El número de sorteo sea un string válido
- El tipo sea exactamente "SORTEO"

## Iconografía

En la interfaz, los sorteos se identifican con el icono de casino (🎲) en color rojo.
