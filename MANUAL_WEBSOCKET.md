# Manual de Conexión y Uso del WebSocket

## Descripción
La aplicación Anfibius Connect Nexus Utility utiliza un sistema de WebSocket para recibir solicitudes de impresión en tiempo real desde sistemas externos. Este manual explica cómo conectarse, configurar y usar todas las funcionalidades disponibles.

## Configuración Inicial

### 1. Obtener el Token de Conexión
Para conectarse al WebSocket, necesitas un **token único** proporcionado por el sistema Anfibius:

- **Formato**: Token alfanumérico único
- **Ejemplo**: `abc123xyz789token`
- **Fuente**: Solicitar al administrador del sistema Anfibius

### 2. Configurar la Conexión

#### Desde la Aplicación:
1. Abrir la aplicación
2. Ir a **"Configuración"** → **"Conexión"**
3. Introducir el token en el campo **"Token"**
4. Hacer clic en el botón de **enlace (🔗)** para conectar
5. Verificar que el estado cambie a **"Conectado"** (ícono verde ✅)

#### Programáticamente:
```dart
// Conectar al WebSocket
final webSocketService = WebSocketService();
await webSocketService.connect("tu_token_aqui");

// Verificar estado de conexión
if (webSocketService.isConnected) {
  print("✅ Conectado exitosamente");
}
```

## URLs de Conexión del WebSocket

El sistema intenta conectarse automáticamente a múltiples endpoints en el siguiente orden:

1. **`wss://soporte.anfibius.net:3300/[TOKEN]`** (Preferido - HTTPS seguro)
2. **`ws://soporte.anfibius.net:3300/[TOKEN]`** (HTTP sin cifrar)
3. **`wss://soporte.anfibius.net/[TOKEN]`** (HTTPS puerto por defecto)
4. **`ws://soporte.anfibius.net/[TOKEN]`** (HTTP puerto por defecto)

### Características de Conexión:
- **Reconexión automática**: Se reconecta cada 5 segundos si se pierde la conexión
- **Certificados SSL**: Ignora errores de certificado para conexiones seguras
- **Múltiples puertos**: Prueba puerto 3300 y puerto por defecto
- **Fallback HTTP**: Si HTTPS falla, intenta HTTP

## Tipos de Documentos Soportados

La aplicación puede procesar diferentes tipos de documentos de impresión:

### 1. VENTA (Facturas)
```json
{
  "tipo": "VENTA",
  "id": "001-002-123456789",
  "copias": "1",
  "printerName": "EPSON TM-T88V",
  "data": {
    "numeroFactura": "001-002-123456789",
    "sucursal": "MATRIZ",
    "empresa": "MI EMPRESA S.A.",
    "nombre": "Mi Empresa",
    "ruc": "1234567890001",
    "direccion": "Av. Principal 123",
    "telefono": "02-234-5678",
    "cliente": "JUAN PEREZ",
    "fecha": "2025-01-15",
    "subtotal": "10.00",
    "iva": "1.20",
    "total": "11.20",
    "detalles": [
      {
        "cantidad": 2,
        "descripcion": "Producto 1",
        "valorUnitario": "5.00",
        "valorTotal": "10.00"
      }
    ],
    "formas_pago": [
      {
        "detalle": "EFECTIVO",
        "importe": 11.20
      }
    ]
  }
}
```

### 2. COMANDA (Órdenes de Cocina)
```json
{
  "tipo": "COMANDA",
  "id": "CMD_001",
  "copias": "1", 
  "printerName": "COCINA_PRINTER",
  "data": {
    "hameName": "Mesa 5",
    "pisoName": "Planta Baja",
    "empleado": "Maria Rodriguez",
    "fecha": "2025-01-15",
    "hora": "14:30",
    "detalles": [
      {
        "producto": "Hamburguesa Clásica",
        "cantidad": 2,
        "observaciones": "Sin cebolla"
      },
      {
        "producto": "Papas Fritas",
        "cantidad": 1,
        "observaciones": "Extra sal"
      }
    ]
  }
}
```

### 3. REPORTE (Reportes Varios)
```json
{
  "tipo": "REPORTE",
  "id": "RPT_VENTAS_001",
  "copias": "1",
  "printerName": "HP_RECEIPT",
  "data": {
    "titulo": "REPORTE DE VENTAS DIARIAS",
    "fecha": "2025-01-15",
    "contenido": [
      "Total Ventas: $1,250.00",
      "Número de Transacciones: 45",
      "Promedio por Venta: $27.78"
    ]
  }
}
```

### 4. PRUEBA (Documentos de Prueba)
```json
{
  "tipo": "PRUEBA",
  "id": "TEST_001",
  "copias": "1",
  "printerName": "TEST_PRINTER",
  "data": {
    "mensaje": "Este es un documento de prueba",
    "timestamp": "2025-01-15 14:30:00"
  }
}
```

## Funcionalidades del Sistema

### 1. Soporte para Múltiples Impresoras

#### Conectar múltiples impresoras:
1. Ir a **"Configuración"** → **"Impresoras"**
2. En la sección **"Impresoras Conectadas"**, hacer clic en **"Agregar"**
3. Seleccionar la impresora de la lista
4. La impresora se conectará automáticamente

#### Especificar impresora en solicitudes:
```json
{
  "tipo": "VENTA",
  "id": "12345",
  "printerName": "EPSON Kitchen",
  "copias": "1",
  "data": { ... }
}
```

#### Comportamiento sin especificar impresora:
- Usa la **impresora principal** (retrocompatibilidad)
- Mantiene compatibilidad con código existente

### 2. Gestión del Historial

#### Ver historial de impresiones:
1. Ir a **"Dispositivos"**
2. Sección **"Historial de Impresión"**
3. Lista de todas las solicitudes recibidas

#### Reimprimir desde historial:
- Hacer clic en el botón **🖨️** junto a cualquier elemento
- Se reimprimirá usando la impresora actual

#### Limpiar historial:
- Botón **"Limpiar Historial"** en la sección de historial
- Elimina todos los registros guardados

### 3. Estados de Conexión

#### Indicadores Visuales:
- **Verde ✅**: WebSocket conectado
- **Rojo ❌**: WebSocket desconectado
- **Botón Reconectar**: Disponible cuando hay token configurado

#### Verificación de Estado:
```dart
// Verificar conexión
bool isConnected = webSocketService.isConnected;

// Obtener token actual
String? currentToken = webSocketService.token;

// Obtener historial
List<PrintHistoryItem> history = webSocketService.historyItems;
```

### 4. Configuración de Papel

#### Tamaños soportados:
- **58mm**: 34 caracteres por línea
- **72mm**: 42 caracteres por línea  
- **80mm**: 48 caracteres por línea
- **Personalizado**: Ancho configurable

#### Configurar desde la aplicación:
1. **"Configuración"** → **"Impresoras"**
2. Sección **"Configuración de Papel"**
3. Seleccionar tamaño o configurar ancho personalizado

## Integración con Sistemas Externos

### 1. Envío de Solicitudes via WebSocket

#### Estructura básica del mensaje:
```javascript
// JavaScript - Cliente WebSocket
const ws = new WebSocket('wss://soporte.anfibius.net:3300/tu_token');

ws.onopen = function() {
    console.log('Conectado al WebSocket');
    
    // Enviar solicitud de impresión
    const solicitud = {
        tipo: "VENTA",
        id: "FAC_001",
        copias: "1",
        printerName: "EPSON_COCINA",
        data: {
            // ... datos de la factura
        }
    };
    
    ws.send(JSON.stringify(solicitud));
};

ws.onmessage = function(event) {
    console.log('Respuesta recibida:', event.data);
};
```

#### Estructura desde aplicación PHP:
```php
<?php
// PHP - Cliente WebSocket usando ReactPHP
use Ratchet\Client\WebSocket;
use Ratchet\Client\Connector;

$connector = new Connector();
$connector('wss://soporte.anfibius.net:3300/tu_token')
    ->then(function (WebSocket $conn) {
        $solicitud = [
            'tipo' => 'VENTA',
            'id' => 'FAC_001',
            'copias' => '1',
            'printerName' => 'EPSON_PRINCIPAL',
            'data' => [
                'numeroFactura' => '001-002-123456',
                'total' => '25.50',
                // ... más datos
            ]
        ];
        
        $conn->send(json_encode($solicitud));
    });
?>
```

### 2. Validación de Solicitudes

#### Campos Requeridos:
- **`tipo`**: Tipo de documento (VENTA, COMANDA, REPORTE, PRUEBA)
- **`id`**: Identificador único del documento
- **`copias`**: Número de copias a imprimir (opcional, default: "1")

#### Campos Opcionales:
- **`printerName`**: Nombre específico de la impresora
- **`orden`**: Orden de procesamiento (opcional)
- **`data`**: Datos específicos del documento

#### Validaciones automáticas:
```dart
// La aplicación valida automáticamente:
if (request.tipo.isEmpty || request.id.isEmpty) {
    print('❌ Solicitud inválida: faltan campos requeridos');
    return false;
}

// Genera ID automático para ventas directas sin ID
if (request.id.isEmpty && request.tipo.toUpperCase() == 'VENTA') {
    request.id = DateTime.now().millisecondsSinceEpoch.toString();
}
```

## Formato de Mensajes del WebSocket

### 1. Formato de Recepción
Los mensajes pueden llegar en diferentes formatos:

#### Formato Broadcast:
```
Broadcast [estacion_1/cocina]: {"tipo":"COMANDA","id":"CMD_001",...}
```

#### Formato JSON Directo:
```json
{"tipo":"VENTA","id":"FAC_001","copias":"1","data":{...}}
```

#### Procesamiento Automático:
La aplicación extrae automáticamente el JSON válido independientemente del formato de llegada.

### 2. Respuestas y Confirmaciones

#### Estados de Procesamiento:
- **✅ Procesado**: Documento enviado a la impresora
- **❌ Error**: Fallo en el procesamiento
- **⏳ Pendiente**: En cola de impresión

#### Logs del Sistema:
```
✅ Conectado exitosamente a: wss://soporte.anfibius.net:3300/token
📝 Mensaje recibido - Raw: Broadcast [estacion_1]: {"tipo":"VENTA"...}
📝 JSON extraído: {"tipo":"VENTA","id":"FAC_001"...}
🖨️ Imprimiendo documento: VENTA - ID: FAC_001
```

## Casos de Uso Comunes

### 1. Restaurante con Múltiples Estaciones

#### Configuración:
- **Impresora Cocina**: "EPSON_COCINA"
- **Impresora Bar**: "STAR_BAR"
- **Impresora Caja**: "HP_CAJA"

#### Solicitudes:
```json
// Comando a cocina
{
  "tipo": "COMANDA",
  "printerName": "EPSON_COCINA",
  "data": { /* datos de comanda */ }
}

// Factura en caja  
{
  "tipo": "VENTA",
  "printerName": "HP_CAJA", 
  "data": { /* datos de factura */ }
}

// Ticket de bar
{
  "tipo": "COMANDA",
  "printerName": "STAR_BAR",
  "data": { /* bebidas */ }
}
```

### 2. Oficina con Impresoras Compartidas

#### Balanceo Manual:
```json
// Solicitud con impresora específica
{
  "tipo": "REPORTE",
  "printerName": "HP_OFICINA_1",
  "data": { /* reporte */ }
}

// Solicitud con fallback a principal
{
  "tipo": "REPORTE", 
  "data": { /* reporte */ }
}
```

### 3. Sistema de Punto de Venta

#### Integración Completa:
```javascript
// Sistema POS enviando facturas
class AnfibiusPrinter {
    constructor(token) {
        this.token = token;
        this.ws = null;
        this.connect();
    }
    
    connect() {
        this.ws = new WebSocket(`wss://soporte.anfibius.net:3300/${this.token}`);
        
        this.ws.onopen = () => {
            console.log('🔗 Conectado a Anfibius Printer');
        };
        
        this.ws.onerror = (error) => {
            console.error('❌ Error de conexión:', error);
        };
    }
    
    printInvoice(invoiceData, printerName = null) {
        const request = {
            tipo: "VENTA",
            id: invoiceData.numero,
            copias: "1",
            printerName: printerName || "",
            data: invoiceData
        };
        
        this.ws.send(JSON.stringify(request));
    }
    
    printKitchenOrder(orderData) {
        const request = {
            tipo: "COMANDA", 
            id: `CMD_${Date.now()}`,
            copias: "1",
            printerName: "COCINA_PRINTER",
            data: orderData
        };
        
        this.ws.send(JSON.stringify(request));
    }
}

// Uso
const printer = new AnfibiusPrinter('tu_token_aqui');
printer.printInvoice({
    numeroFactura: '001-002-123456',
    total: '15.50',
    cliente: 'Juan Pérez',
    // ... más datos
});
```

## Solución de Problemas

### 1. Problemas de Conexión

#### Error: "No se puede conectar"
**Solución:**
1. Verificar que el token sea correcto
2. Comprobar conexión a internet
3. Intentar reconectar desde la configuración
4. Verificar que no haya firewall bloqueando

#### Error: "Certificado SSL inválido"
**Solución:**
- La aplicación ignora automáticamente errores de certificado
- Si persiste, usar conexión HTTP (`ws://`) en lugar de HTTPS

### 2. Problemas de Impresión

#### Error: "Impresora no conectada"
**Solución:**
1. Verificar que la impresora esté encendida
2. Comprobar conexión USB/Bluetooth/Red
3. Reconectar desde "Configuración" → "Impresoras"

#### Error: "Impresora no encontrada"
**Solución:**
1. Verificar el nombre de la impresora en `printerName`
2. Usar nombres exactos como aparecen en la configuración
3. Dejar `printerName` vacío para usar impresora principal

### 3. Problemas de Formato

#### Error: "JSON inválido"
**Solución:**
1. Validar la estructura JSON antes de enviar
2. Asegurar que `tipo` e `id` estén presentes
3. Usar herramientas de validación JSON

#### Error: "Tipo de documento no soportado"
**Solución:**
- Usar tipos válidos: `VENTA`, `COMANDA`, `REPORTE`, `PRUEBA`
- Verificar mayúsculas/minúsculas

## Configuración Avanzada

### 1. Inicio Automático con Windows

#### Activar:
1. **"Configuración"** → **"Sistema"**
2. Activar **"Iniciar con Windows"**
3. La aplicación iniciará automáticamente al arrancar Windows

#### Comportamiento:
- Inicia minimizada en la bandeja del sistema
- Conecta automáticamente al WebSocket si hay token guardado
- Mantiene todas las impresoras configuradas

### 2. Configuración de Red

#### Para impresoras de red:
1. **"Configuración"** → **"Impresoras"**
2. Sección **"Impresora de Red"**
3. Introducir **IP** y **Puerto** (default: 9100)
4. Guardar y conectar

#### Configuración típica:
- **IP**: `192.168.1.100`
- **Puerto**: `9100` (estándar para impresoras ESC/POS)

### 3. Personalización de Papel

#### Configurar ancho personalizado:
```dart
// Configurar ancho de 70mm
await ConfigService.saveCustomPaperWidth(70);

// Activar uso de ancho personalizado  
await ConfigService.saveUsingCustomPaperSize(true);
```

#### Desde la interfaz:
1. **"Configuración"** → **"Impresoras"**
2. **"Configuración de Papel"**
3. Activar **"Usar ancho personalizado"**
4. Introducir ancho en milímetros

## API de Referencia

### WebSocketService

#### Métodos Principales:
```dart
class WebSocketService {
  // Conectar con token
  Future<void> connect(String token);
  
  // Desconectar
  void disconnect();
  
  // Estado de conexión
  bool get isConnected;
  
  // Token actual
  String? get token;
  
  // Historial de mensajes
  List<PrintHistoryItem> get historyItems;
  
  // Limpiar historial
  Future<void> clearHistory();
  
  // Callback para nuevos mensajes
  Function(String)? onNewMessage;
}
```

### PrintJobService

#### Procesamiento de Solicitudes:
```dart
class PrintJobService {
  // Procesar solicitud de impresión
  Future<bool> processPrintRequest(String jsonMessage);
  
  // Obtener tamaño de papel detectado
  PaperSize getDetectedPaperSize();
}
```

### ConfigService

#### Gestión de Configuración:
```dart
class ConfigService {
  // Token WebSocket
  static Future<void> saveWebSocketToken(String token);
  static Future<String?> loadWebSocketToken();
  
  // Impresora seleccionada
  static Future<void> saveSelectedPrinter(BluetoothPrinter printer);
  static Future<BluetoothPrinter?> loadSelectedPrinter();
  
  // Mensajes del historial
  static Future<void> addMessage(String message);
  static Future<List<String>> loadMessages();
  static Future<void> clearMessages();
}
```

## Seguridad y Buenas Prácticas

### 1. Gestión de Tokens
- **Nunca compartir tokens** en código público
- **Rotar tokens** periódicamente
- **Almacenar tokens** de forma segura en variables de entorno

### 2. Validación de Datos
```javascript
// Validar datos antes de enviar
function validatePrintRequest(data) {
    if (!data.tipo || !data.id) {
        throw new Error('Faltan campos requeridos: tipo, id');
    }
    
    const validTypes = ['VENTA', 'COMANDA', 'REPORTE', 'PRUEBA'];
    if (!validTypes.includes(data.tipo.toUpperCase())) {
        throw new Error('Tipo de documento no válido');
    }
    
    return true;
}
```

### 3. Manejo de Errores
```javascript
// Manejo robusto de errores
ws.onerror = function(error) {
    console.error('Error WebSocket:', error);
    // Implementar lógica de reintentos
    setTimeout(reconnect, 5000);
};

ws.onclose = function(event) {
    console.log('Conexión cerrada:', event.code, event.reason);
    // Reconectar automáticamente
    if (event.code !== 1000) {
        setTimeout(reconnect, 5000);
    }
};
```

## Ejemplos de Integración

### 1. Sistema Laravel/PHP
```php
<?php
// composer require ratchet/pawl

use Ratchet\Client\Connector;
use Ratchet\Client\WebSocket;

class AnfibiusPrinterService 
{
    private $token;
    private $connector;
    
    public function __construct($token) 
    {
        $this->token = $token;
        $this->connector = new Connector();
    }
    
    public function printInvoice($invoiceData) 
    {
        $url = "wss://soporte.anfibius.net:3300/{$this->token}";
        
        $this->connector($url)->then(function (WebSocket $conn) use ($invoiceData) {
            $request = [
                'tipo' => 'VENTA',
                'id' => $invoiceData['numero'],
                'copias' => '1',
                'data' => $invoiceData
            ];
            
            $conn->send(json_encode($request));
            $conn->close();
        });
    }
}
?>
```

### 2. Sistema Node.js
```javascript
// npm install ws

const WebSocket = require('ws');

class AnfibiusPrinter {
    constructor(token) {
        this.token = token;
        this.ws = null;
        this.connect();
    }
    
    connect() {
        const url = `wss://soporte.anfibius.net:3300/${this.token}`;
        this.ws = new WebSocket(url);
        
        this.ws.on('open', () => {
            console.log('✅ Conectado a Anfibius Printer');
        });
        
        this.ws.on('error', (error) => {
            console.error('❌ Error:', error);
        });
        
        this.ws.on('close', () => {
            console.log('🔌 Conexión cerrada');
            // Reconectar después de 5 segundos
            setTimeout(() => this.connect(), 5000);
        });
    }
    
    async printDocument(tipo, id, data, printerName = null) {
        if (this.ws.readyState !== WebSocket.OPEN) {
            throw new Error('WebSocket no está conectado');
        }
        
        const request = {
            tipo: tipo.toUpperCase(),
            id: id,
            copias: '1',
            printerName: printerName || '',
            data: data
        };
        
        this.ws.send(JSON.stringify(request));
        console.log(`📄 Enviado: ${tipo} - ${id}`);
    }
}

// Uso
const printer = new AnfibiusPrinter('tu_token_aqui');

// Imprimir factura
printer.printDocument('VENTA', 'FAC_001', {
    numeroFactura: '001-002-123456',
    cliente: 'Juan Pérez',
    total: '25.50'
});

// Imprimir comanda
printer.printDocument('COMANDA', 'CMD_001', {
    mesa: 'Mesa 5',
    productos: ['Hamburguesa', 'Papas']
}, 'COCINA_PRINTER');
```

### 3. Sistema Python
```python
# pip install websockets

import asyncio
import websockets
import json

class AnfibiusPrinter:
    def __init__(self, token):
        self.token = token
        self.websocket = None
        
    async def connect(self):
        url = f"wss://soporte.anfibius.net:3300/{self.token}"
        try:
            self.websocket = await websockets.connect(url)
            print("✅ Conectado a Anfibius Printer")
        except Exception as e:
            print(f"❌ Error de conexión: {e}")
            
    async def print_document(self, tipo, doc_id, data, printer_name=None):
        if not self.websocket:
            await self.connect()
            
        request = {
            "tipo": tipo.upper(),
            "id": doc_id,
            "copias": "1",
            "printerName": printer_name or "",
            "data": data
        }
        
        await self.websocket.send(json.dumps(request))
        print(f"📄 Enviado: {tipo} - {doc_id}")
        
    async def close(self):
        if self.websocket:
            await self.websocket.close()

# Uso
async def main():
    printer = AnfibiusPrinter('tu_token_aqui')
    
    # Imprimir factura
    await printer.print_document('VENTA', 'FAC_001', {
        'numeroFactura': '001-002-123456',
        'cliente': 'Juan Pérez',
        'total': '25.50'
    })
    
    await printer.close()

# Ejecutar
asyncio.run(main())
```

## Conclusión

El sistema de WebSocket de Anfibius Connect Nexus Utility proporciona una solución completa y robusta para la impresión automática de documentos desde sistemas externos. Con soporte para múltiples impresoras, reconexión automática, y una amplia variedad de tipos de documentos, se adapta perfectamente a las necesidades de restaurantes, oficinas, y puntos de venta.

### Características Clave:
- ✅ **Conexión automática** con múltiples endpoints de respaldo
- ✅ **Soporte para múltiples impresoras** simultáneas
- ✅ **Reconexión automática** en caso de pérdida de conexión
- ✅ **Historial persistente** de todas las impresiones
- ✅ **Retrocompatibilidad** completa con sistemas existentes
- ✅ **Inicio automático** con Windows
- ✅ **Configuración flexible** de papel y impresoras

### Soporte
Para soporte técnico o consultas adicionales:
- **Documentación**: Este manual
- **Logs del sistema**: Disponibles en la aplicación
- **Estado en tiempo real**: Visible en la interfaz de dispositivos

¡El sistema está listo para integración inmediata con tus aplicaciones existentes!
