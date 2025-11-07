# Soporte para Múltiples Impresoras

## Problema Resuelto

✅ **CORREGIDO v2**: 
1. **Windows enviaba todo a la misma impresora**: Ahora el sistema reconecta a cada impresora específica antes de imprimir, asegurando que los bytes se envíen a la impresora correcta.
2. **Mensajes de error del sistema**: Se eliminaron los mensajes de error cuando una impresora no está conectada. El sistema ahora maneja los errores silenciosamente y continúa funcionando.

## Cómo Funciona la Corrección

### Problema Anterior (Windows)
- Windows permite múltiples impresoras USB conectadas
- El `PrinterManager` solo distinguía por tipo (USB/Bluetooth/Red)
- **Resultado**: Todos los bytes USB se enviaban a la última impresora USB conectada

### Solución Implementada
- **Reconexión activa**: Antes de cada impresión, el sistema se conecta específicamente a la impresora objetivo usando sus parámetros únicos:
  - USB: `vendorId` + `productId` + `deviceName`
  - Bluetooth: `address` + `deviceName`
  - Red: `ipAddress` + `port`
- **Manejo silencioso de errores**: Si una impresora no está conectada, el sistema registra el error en logs pero no muestra mensajes de error del sistema
- **Estado actualizado**: El estado de conexión de cada impresora se actualiza automáticamente

## Características

### 1. Gestión de Múltiples Impresoras
- **Conectar múltiples impresoras**: Puedes tener varias impresoras conectadas al mismo tiempo
- **Identificación por nombre**: Cada impresora se identifica por su nombre único
- **Tamaño de papel individual**: Cada impresora tiene su configuración de tamaño (58mm, 72mm, 80mm)
- **Estado independiente**: Cada impresora mantiene su propio estado de conexión
- **Impresión dirigida**: Las peticiones especifican exactamente a qué impresora enviar

### 2. Selección de Impresora

#### **IMPORTANTE**: Especificar Impresora en el JSON

El mensaje JSON **debe incluir** el campo que identifica la impresora. Campos soportados:
- `"printer"` ⭐ (recomendado)
- `"impresora"`
- `"printerName"`
- `"printer_name"`
- `"nombreImpresora"`

#### Comportamiento del Sistema:

**✅ Caso 1: Impresora especificada**
```json
{
  "tipo": "COMANDA",
  "printer": "cocina",
  "data": {...}
}
```
→ Imprime en la impresora "cocina"

**✅ Caso 2: Una sola impresora conectada (sin especificar)**
```json
{
  "tipo": "COMANDA",
  "data": {...}
}
```
→ Auto-selecciona la única impresora disponible

**❌ Caso 3: Múltiples impresoras sin especificar**
```json
{
  "tipo": "COMANDA",
  "data": {...}
}
```
→ **ERROR**: "Hay múltiples impresoras conectadas. Debes especificar cuál usar"

## Uso

### Formato del JSON con Impresora Específica:

```json
{
  "tipo": "COMANDA",
  "printer": "cocina",
  "id": "CMD-001",
  "copias": "1",
  "data": {
    "hameName": "Mesa 5",
    "pisoName": "Primer Piso",
    "detalles": [
      {
        "cant": 2,
        "descripcion": "Hamburguesa Especial",
        "observacion": "Sin cebolla"
      }
    ]
  }
}
```

### Ejemplos Prácticos

**Restaurante con 3 Impresoras:**

```javascript
// Comanda para cocina
{
  "tipo": "COMANDA",
  "printer": "cocina",  // ← Impresora USB 80mm
  "data": {...}
}

// Comanda para bar  
{
  "tipo": "COMANDA",
  "printer": "bar",     // ← Impresora Bluetooth 58mm
  "data": {...}
}

// Factura en caja
{
  "tipo": "VENTA",
  "printer": "caja",    // ← Impresora de Red 80mm
  "data": {...}
}
```

## Flujo de Impresión (Técnico)

### 1. Recepción del Mensaje
```
Mensaje JSON → PrintJobService.processPrintRequest()
```

### 2. Identificación de la Impresora
```
Extrae campo "printer" del JSON → Busca en _connectedPrinters
```

### 3. Reconexión Específica (CRÍTICO para Windows)
```
printBytesToPrinter() → printerManager.connect() con parámetros específicos:
  - USB: vendorId + productId + deviceName
  - Bluetooth: address + deviceName  
  - Red: ipAddress + port
```

### 4. Envío de Bytes
```
printerManager.send(type: tipoPrinter, bytes: bytes)
```

### 5. Actualización de Estado
```
_connectionStatus[printerName] = true/false
notifyListeners()
```

## Logs del Sistema

### Impresión Exitosa
```
🔍 Impresora extraída del JSON: cocina
🔎 Buscando impresora: "cocina"
📊 Impresoras conectadas disponibles: cocina, parrilla, bar
🎯 Imprimiendo en impresora específica: cocina
📄 Tamaño de papel para cocina: 80mm
🖨️ Imprimiendo en: cocina (PrinterType.usb)
🔌 Conectado a impresora USB: cocina
✅ Impresión enviada exitosamente a: cocina
```

### Impresora No Conectada (Sin mensaje de error del sistema)
```
🔍 Impresora extraída del JSON: parrilla
🔎 Buscando impresora: "parrilla"
🖨️ Imprimiendo en: parrilla (PrinterType.usb)
⚠️ Error al conectar impresora USB parrilla: [error interno]
❌ No se pudo conectar a la impresora: parrilla
```
**Nota**: El error se registra en logs pero NO se muestra mensaje de error al usuario

### Impresora No Existe
```
🔍 Impresora extraída del JSON: bodega
🔎 Buscando impresora: "bodega"
📊 Impresoras conectadas disponibles: cocina, parrilla, bar
❌ Impresora "bodega" no está conectada o no existe
💡 Sugerencia: Verifica que el nombre coincida exactamente
```
```
En este caso usará la impresora principal (retrocompatibilidad).

### Para Usuarios

#### Agregar una nueva impresora:
1. Ir a "Configuración" → "Impresoras"
2. En la sección "Impresoras Conectadas", hacer clic en "Agregar"
3. Seleccionar la impresora de la lista de dispositivos disponibles
4. La impresora se agregará automáticamente y se intentará conectar

#### Gestionar impresoras existentes:
- **Ver estado**: Verde = conectada, Rojo = desconectada
- **Conectar/Desconectar**: Usar el botón de enlace (🔗/🔗✂️)
- **Eliminar**: Usar el botón de eliminar (🗑️)

## Comportamiento del Sistema

### Carga al Iniciar
- Se cargan todas las impresoras guardadas anteriormente
- Se intenta conectar automáticamente a cada una
- Se mantiene retrocompatibilidad con la impresora principal

### Procesamiento de Peticiones
1. **Con nombre específico**: 
   - Verifica que la impresora exista y esté conectada
   - Imprime solo en esa impresora
   - Falla si la impresora no está disponible

2. **Sin nombre específico**:
   - Usa la impresora principal (comportamiento original)
   - Mantiene retrocompatibilidad completa

### Gestión de Conexiones
- Cada impresora mantiene su propio estado de conexión
- Verificación automática periódica del estado
- Reconexión automática cuando es posible

## Configuración Persistente
- Las impresoras agregadas se guardan automáticamente
- Se restauran al reiniciar la aplicación
- Configuración independiente para cada impresora

## Casos de Uso

### Restaurante con múltiples estaciones:
- **Impresora Cocina**: "EPSON Kitchen"
- **Impresora Bar**: "STAR Bar Printer" 
- **Impresora Caja**: "HP Receipt"

Petición para cocina:
```json
{
  "tipo": "COMANDA",
  "printerName": "EPSON Kitchen",
  "data": { /* datos de comanda */ }
}
```

Petición para caja:
```json
{
  "tipo": "VENTA", 
  "printerName": "HP Receipt",
  "data": { /* datos de factura */ }
}
```

### Oficina con impresoras compartidas:
- Cada solicitud puede dirigirse a una impresora específica
- Balanceo de carga manual según disponibilidad
- Respaldo automático a impresora principal

## Beneficios
1. **Mayor flexibilidad**: Múltiples puntos de impresión
2. **Mejor rendimiento**: Distribución de carga de trabajo
3. **Redundancia**: Respaldo si una impresora falla
4. **Organización**: Impresoras dedicadas por función
5. **Escalabilidad**: Fácil agregar más impresoras

## Retrocompatibilidad
- ✅ **100% compatible** con código existente
- ✅ **Sin cambios requeridos** en aplicaciones actuales  
- ✅ **Migración gradual** posible
- ✅ **Configuración existente** se mantiene
