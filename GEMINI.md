Este documento proporciona el contexto completo del proyecto para que Gemini (o cualquier IA) pueda trabajar de manera ordenada y comprenda:

1. ✅ **QUÉ FUNCIONA** - Lo que ya está implementado y **NO debe modificarse** sin petición explícita
2. 🛠️ **ARQUITECTURA** - Cómo está estructurado el proyecto
3. 📋 **REGLAS DE TRABAJO** - Cómo trabajar con este proyecto de forma segura

---

## ⚠️ REGLAS CRÍTICAS - LEER PRIMERO

### 🔒 NO MODIFICAR SIN PETICIÓN EXPLÍCITA:

1. **Sistema de Impresoras** (`lib/services/printer_service.dart`, `lib/services/print_job_service.dart`)

   - Gestión de múltiples impresoras
   - Conexión USB/Bluetooth/Red
   - Procesamiento de trabajos de impresión
   - Historial de impresión
   - **ESTÁ FUNCIONANDO CORRECTAMENTE** ✅
2. **Sistema de WebSocket** (`lib/services/websocket_service.dart`)

   - Conexión automática con múltiples endpoints
   - Reconexión automática cada 5 segundos
   - Recepción de solicitudes de impresión en tiempo real
   - Envío de datos de huellas dactilares
   - **ESTÁ FUNCIONANDO CORRECTAMENTE** ✅
3. **Sistema de Lectores de Huellas** (`lib/services/fingerprint_reader_service.dart`)

   - Detección automática de dispositivos
   - Lectura en tiempo real
   - Integración con WebSocket
   - **ESTÁ FUNCIONANDO CORRECTAMENTE** ✅

### ✅ ANTES DE CUALQUIER MODIFICACIÓN:

1. **PREGUNTAR** si la modificación afecta alguno de los sistemas mencionados arriba
2. **EXPLICAR** qué vas a cambiar y por qué
3. Generar un documento del plan y cambios a aplicar
4. **ESPERAR CONFIRMACIÓN** del usuario antes de proceder
5. **CREAR RESPALDOS** mentales de lo que existía antes

---

## 📂 ESTRUCTURA DEL PROYECTO

### Información General

- **Nombre:** anfibius_uwu (Anfibius Connect Nexus Utility)
- **Framework:** Flutter 3.7.2+
- **Plataformas:** Windows (principal), Android, iOS, Web, Linux, macOS
- **Lenguaje:** Dart
- **Patrón de Estado:** Provider

### Estructura de Carpetas

```
ACNU/
├── lib/
│   ├── main.dart                          # Punto de entrada principal
│   ├── configuraciones.dart               # Configuraciones globales
│   ├── dispositivos.dart                  # Gestión de dispositivos
│   ├── lector_huella.dart                 # Interfaz de lectura de huellas
│   ├── printers.dart                      # Interfaz de impresoras
│   ├── settings_screen.dart               # Pantalla de configuración
│   │
│   ├── models/                            # Modelos de datos
│   │   ├── employee.dart                  # Modelo de empleado
│   │   ├── print_history_item.dart        # Historial de impresión
│   │   └── print_request.dart             # Solicitudes de impresión
│   │
│   ├── screens/                           # Pantallas de la aplicación
│   │   ├── main_screen.dart               # Pantalla principal
│   │   ├── employee_management_screen.dart # Gestión de empleados
│   │   ├── fingerprint_registration_screen.dart # Registro de huellas
│   │   └── nomina.dart                    # Gestión de nómina
│   │
│   └── services/                          # ⭐ SERVICIOS PRINCIPALES
│       ├── auth_service.dart              # 🔒 NO MODIFICAR - Autenticación
│       ├── websocket_service.dart         # 🔒 NO MODIFICAR - WebSocket
│       ├── printer_service.dart           # 🔒 NO MODIFICAR - Impresoras
│       ├── print_job_service.dart         # 🔒 NO MODIFICAR - Trabajos de impresión
│       ├── fingerprint_reader_service.dart # 🔒 NO MODIFICAR - Lector de huellas
│       ├── employee_service.dart          # Gestión de empleados
│       ├── objetivos_service.dart         # Sistema de objetivos
│       ├── notifications_service.dart     # Notificaciones
│       ├── startup_service.dart           # Inicio automático
│       ├── config_service.dart            # Configuración persistente
│       └── hikvision_sdk.dart             # SDK Hikvision
│
├── assets/                                # Recursos (iconos, imágenes)
├── SDKHIKVISION/                          # SDK del dispositivo Hikvision
├── windows/                               # Configuración específica de Windows
├── android/                               # Configuración específica de Android
└── (otras plataformas...)
```

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Patrón Provider (Estado Global)

El proyecto utiliza el patrón **Provider** de Flutter para gestión de estado:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => WebSocketService()),      // 🔒
    ChangeNotifierProvider(create: (_) => PrinterService()),        // 🔒
    ChangeNotifierProvider(create: (_) => AuthService()),           // 🔒
    ProxyProvider<AuthService, FingerprintReaderService>(...),     // 🔒
    ProxyProvider<AuthService, EmployeeService>(...),
    ProxyProvider<PrinterService, PrintJobService>(...),           // 🔒
    ChangeNotifierProvider(create: (_) => ObjetivosService()),
    ChangeNotifierProvider(create: (_) => ThemeService()),
    ChangeNotifierProvider(create: (_) => StartupService()),
  ],
  child: MyApp(),
)
```

### Servicios Principales (🔒 = NO MODIFICAR)

#### 1. 🔒 WebSocketService

**Archivo:** `lib/services/websocket_service.dart`

**Funcionalidades:**

- ✅ Conexión automática a múltiples endpoints:
  - `wss://soporte.anfibius.net:3300/[TOKEN]`
  - `ws://soporte.anfibius.net:3300/[TOKEN]`
  - Fallbacks adicionales
- ✅ Reconexión automática cada 5 segundos
- ✅ Recepción de solicitudes de impresión en tiempo real
- ✅ Envío de datos de huellas dactilares (`sendMessage()`)
- ✅ Historial de mensajes persistente
- ✅ Ignorar errores de certificados SSL

**API Pública:**

```dart
class WebSocketService extends ChangeNotifier {
  Future<void> connect(String token);        // Conectar con token
  void disconnect();                         // Desconectar
  Future<void> sendMessage(String message);  // Enviar mensaje
  bool get isConnected;                      // Estado de conexión
  String? get token;                         // Token actual
  List<PrintHistoryItem> get historyItems;   // Historial
  Future<void> clearHistory();               // Limpiar historial
}
```

**Formatos de Mensaje Soportados:**

- Broadcast: `Broadcast [estacion_1/cocina]: {JSON}`
- JSON directo: `{JSON}`

#### 2. 🔒 PrinterService

**Archivo:** `lib/services/printer_service.dart`

**Funcionalidades:**

- ✅ Gestión de **múltiples impresoras** simultáneamente
- ✅ Tipos de conexión: USB, Bluetooth, Red (TCP/IP)
- ✅ Escaneo automático de dispositivos disponibles
- ✅ Reconexión automática de impresoras desconectadas
- ✅ Estado individual por impresora
- ✅ Configuración persistente (guarda impresoras entre sesiones)

**API Pública:**

```dart
class PrinterService extends ChangeNotifier {
  Future<void> scanPrinters();                              // Escanear dispositivos
  Future<void> addPrinter(BluetoothPrinter printer);        // Agregar impresora
  Future<void> removePrinter(String address);               // Remover impresora
  Future<void> connectPrinter(String address);              // Conectar
  Future<void> disconnectPrinter(String address);           // Desconectar
  BluetoothPrinter? getPrinterByName(String name);          // Buscar por nombre
  List<BluetoothPrinter> get connectedPrinters;             // Impresoras conectadas
  BluetoothPrinter? get selectedPrinter;                    // Impresora principal
}
```

#### 3. 🔒 PrintJobService

**Archivo:** `lib/services/print_job_service.dart`

**Funcionalidades:**

- ✅ Procesamiento de solicitudes de impresión desde WebSocket
- ✅ Soporte para múltiples tipos de documentos:
  - **VENTA** (Facturas)
  - **COMANDA** (Órdenes de cocina)
  - **REPORTE** (Reportes varios)
  - **PRUEBA** (Documentos de prueba)
  - **TICKET** (Tickets de sorteo)
  - **PREFECTURA** (Documentos de prefectura)
- ✅ Selección automática de impresora por nombre
- ✅ Configuración de papel (58mm, 72mm, 80mm, personalizado)
- ✅ Generación de comandos ESC/POS

**API Pública:**

```dart
class PrintJobService {
  Future<bool> processPrintRequest(String jsonMessage);     // Procesar solicitud
  PaperSize getDetectedPaperSize();                         // Tamaño de papel
}
```

**Formato de Solicitud JSON:**

```json
{
  "tipo": "VENTA|COMANDA|REPORTE|PRUEBA|TICKET|PREFECTURA",
  "id": "identificador_unico",
  "copias": "1",
  "printerName": "NOMBRE_IMPRESORA",  // Opcional, usa principal si no se especifica
  "data": {
    // Datos específicos del tipo de documento
  }
}
```

#### 4. 🔒 FingerprintReaderService

**Archivo:** `lib/services/fingerprint_reader_service.dart`

**Funcionalidades:**

- ✅ Detección automática de lectores de huellas
- ✅ Soporte para Hikvision DS-K1F820-F
- ✅ Modo de simulación para pruebas
- ✅ Lectura automática al colocar el dedo
- ✅ Envío automático por WebSocket
- ✅ Integración con sistema de objetivos

**API Pública:**

```dart
class FingerprintReaderService {
  Future<void> scanDevices();                               // Escanear dispositivos
  Future<void> connectToDevice(String deviceId);            // Conectar
  void disconnect();                                        // Desconectar
  List<Map<String, dynamic>> get availableDevices;          // Dispositivos disponibles
  bool get isConnected;                                     // Estado de conexión
  Function(Map<String, dynamic>)? onFingerprintRead;        // Callback de lectura
}
```

**Formato de Datos de Huella:**

```json
{
  "timestamp": "2025-10-22T10:30:00.000Z",
  "device": "Hikvision DS-K1F820-F",
  "type": "Real|Simulado",
  "fingerprint": "base64_encoded_data",
  "simulated": false
}
```

---

## 🔧 FUNCIONALIDADES IMPLEMENTADAS (NO MODIFICAR)

### 1. Sistema de Impresión en Tiempo Real

**Flujo Completo:**

1. Sistema externo envía JSON por WebSocket → `WebSocketService`
2. `WebSocketService` recibe y notifica → `PrintJobService`
3. `PrintJobService` procesa solicitud:
   - Valida formato JSON
   - Identifica tipo de documento
   - Selecciona impresora (por nombre o principal)
   - Genera comandos ESC/POS
4. `PrinterService` ejecuta impresión
5. Resultado se guarda en historial

**Documentos Soportados:**

- ✅ Facturas (VENTA)
- ✅ Comandas de cocina (COMANDA)
- ✅ Reportes (REPORTE)
- ✅ Tickets de sorteo (TICKET)
- ✅ Prefecturas (PREFECTURA)
- ✅ Pruebas (PRUEBA)

### 2. Sistema de Múltiples Impresoras

**Características:**

- ✅ Conectar hasta N impresoras simultáneamente
- ✅ Estado individual de conexión
- ✅ Selección por nombre en solicitudes
- ✅ Fallback a impresora principal
- ✅ Reconexión automática
- ✅ Persistencia de configuración

**Uso desde WebSocket:**

```json
{
  "tipo": "VENTA",
  "printerName": "EPSON_COCINA",  // Específico
  "data": {...}
}
```

### 3. Sistema de Lectores de Huellas

**Características:**

- ✅ Detección automática al colocar dedo
- ✅ Envío en tiempo real por WebSocket
- ✅ Registro de estado en `objetivos.json`
- ✅ Modo simulación para desarrollo
- ✅ Soporte para dispositivos Hikvision

**Dispositivos Soportados:**

- Hikvision DS-K1F820-F (real)
- Lector Simulado (pruebas)

### 4. Inicio Automático con Windows

**Características:**

- ✅ Configuración automática en primer inicio
- ✅ Inicia minimizado en bandeja del sistema
- ✅ Control manual desde configuración
- ✅ Verificación de sincronización con registro de Windows

**Archivos Relacionados:**

- `lib/services/startup_service.dart`

### 5. Sistema de Bandeja del Sistema (System Tray)

**Características:**

- ✅ Ícono en bandeja de Windows
- ✅ Menú contextual:
  - Mostrar/Ocultar ventana
  - Ir a Configuración
  - Ir a Impresoras
  - Salir
- ✅ Minimizar a bandeja al cerrar ventana (X)

**Paquetes Utilizados:**

- `tray_manager`
- `window_manager`

### 6. Configuración Persistente

**Datos Guardados:**

- ✅ Token WebSocket
- ✅ Impresoras conectadas
- ✅ Configuración de papel
- ✅ Historial de impresiones
- ✅ Dispositivo de huella seleccionado
- ✅ Estado de objetivos
- ✅ Preferencias de inicio automático

**Tecnologías:**

- `SharedPreferences` (configuraciones simples)
- Archivos JSON (datos complejos)

---

## 📝 DOCUMENTACIÓN DISPONIBLE

El proyecto incluye documentación detallada en formato Markdown:

1. **README.md** - Descripción general y características del sistema
2. **MANUAL_WEBSOCKET.md** - Manual completo del sistema WebSocket
3. **API_Documentation.md** - Documentación de la API AnfibiusBack
4. **IMPLEMENTACION_HUELLAS.md** - Resumen de implementación de huellas
5. **MULTIPLES_IMPRESORAS.md** - Documentación de múltiples impresoras
6. **STARTUP_SETUP.md** - Configuración de inicio automático
7. **documentacion_sorteo.md** - Documentación de tickets de sorteo
8. **ejemplos_sorteo.md** - Ejemplos de uso de sorteos

**IMPORTANTE:** Antes de preguntar sobre funcionalidades existentes, consultar estos documentos.

---

## 🎨 INTERFAZ DE USUARIO

### Pantallas Principales

#### 1. MainScreen (Pantalla Principal)

**Archivo:** `lib/screens/main_screen.dart`

**Tabs:**

- 🏠 **Inicio** - Dashboard general
- 🖨️ **Dispositivos** - Estado de impresoras y WebSocket
- ⚙️ **Configuración** - Ajustes del sistema

#### 2. SettingsScreen (Configuración)

**Archivo:** `lib/settings_screen.dart`

**Secciones:**

- **Conexión** - Token WebSocket, estado de conexión
- **Impresoras** - Gestión de impresoras, configuración de papel
- **Lector de Huellas** - Selección y configuración de dispositivos
- **Objetivos del Sistema** - Progreso de objetivos implementados
- **Sistema** - Inicio automático, tema, versión

#### 3. Employee Management

**Archivo:** `lib/screens/employee_management_screen.dart`

**Funcionalidades:**

- Lista de empleados desde API
- Búsqueda y filtrado
- Acceso a registro de huellas

#### 4. Fingerprint Registration

**Archivo:** `lib/screens/fingerprint_registration_screen.dart`

**Funcionalidades:**

- Registro de huellas por empleado
- Visualización de estado de registro
- Envío a API AnfibiusBack

---

## 🔌 INTEGRACIONES EXTERNAS

### 1. API AnfibiusBack

**Base URL:** (Configurada en AuthService)

**Endpoints Utilizados:**

- `POST /anfibiusback/api/usuarios/login` - Login
- `GET /anfibiusback/api/empleados` - Listar empleados
- `POST /anfibiusback/api/empleados/registarbiometrico?id={id}` - Registrar huella

**Autenticación:** JWT Token en header `Authorization`

### 2. WebSocket Server

**URLs de Conexión:**

- Primaria: `wss://soporte.anfibius.net:3300/[TOKEN]`
- Fallbacks múltiples (ver WebSocketService)

**Protocolo:**

- Recepción: JSON de solicitudes de impresión
- Envío: JSON de datos de huellas

### 3. SDK Hikvision

**Ubicación:** `SDKHIKVISION/`

**Archivos:**

- Headers: `SDKHIKVISION/include/`
- Libraries: `SDKHIKVISION/libs/`
- Docs: `SDKHIKVISION/docs/`

**Integración:** A través de FFI (Foreign Function Interface)

---

## 📦 DEPENDENCIAS PRINCIPALES

### Dependencias de Flutter (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Estado
  provider: ^6.1.5+1
  
  # Comunicación 🔒
  web_socket_channel: ^3.0.3              # WebSocket
  http: ^1.5.0                            # HTTP requests
  
  # Impresión 🔒
  flutter_esc_pos_utils: ^1.0.1           # Comandos ESC/POS
  flutter_pos_printer_platform_image_3: ^1.2.4  # Impresoras POS
  
  # Persistencia
  shared_preferences: ^2.5.3              # Configuración simple
  path_provider: ^2.1.5                   # Rutas del sistema
  
  # Notificaciones
  flutter_local_notifications: ^19.2.1
  timezone: ^0.10.1
  
  # Escritorio (Windows) 🔒
  launch_at_startup: ^0.5.1               # Inicio automático
  desktop_multi_window: ^0.2.1            # Múltiples ventanas
  tray_manager: ^0.5.0                    # Bandeja del sistema
  window_manager: ^0.5.1                  # Gestión de ventanas
  system_tray: ^2.0.3                     # Icono de bandeja
  
  # Biométrico 🔒
  ffi: ^2.1.0                             # FFI para SDK nativo
  device_manager: ^0.0.7                  # Gestión de dispositivos USB
  
  # Utilidades
  package_info_plus: ^8.3.0               # Info de la app
  carousel_slider: ^5.0.0                 # Carruseles UI
  json_annotation: ^4.9.0                 # Serialización JSON
```

---

## 🚀 CÓMO TRABAJAR CON ESTE PROYECTO

### Reglas de Oro

1. **🔍 INVESTIGAR ANTES DE ACTUAR**

   - Lee los archivos de documentación (`.md`)
   - Explora el código existente
   - Verifica si la funcionalidad ya existe
2. **❓ PREGUNTAR ANTES DE MODIFICAR**

   - Si una funcionalidad parece relacionada con impresoras o WebSocket, **PREGUNTA**
   - Si ves un servicio marcado como 🔒, **PREGUNTA**
   - Si no estás seguro, **PREGUNTA**
3. **📝 DOCUMENTAR CAMBIOS**

   - Explica qué vas a cambiar y por qué
   - Indica qué archivos se verán afectados
   - Espera confirmación antes de proceder
4. **🧪 PROBAR ANTES DE CONFIRMAR**

   - Verifica que el cambio funcione
   - Asegúrate de no romper funcionalidades existentes
   - Usa el modo de simulación cuando sea posible

### Proceso de Trabajo Recomendado

```
1. Usuario solicita cambio/nueva función
   ↓
2. Gemini investiga el código existente
   ↓
3. Gemini explica:
   - ¿Existe ya esta funcionalidad?
   - ¿Qué archivos se modificarán?
   - ¿Afecta a sistemas críticos (🔒)?
   ↓
4. Usuario confirma o ajusta la solicitud
   ↓
5. Gemini realiza cambios
   ↓
6. Gemini explica qué se cambió
   ↓
7. Usuario prueba y confirma
```

### Áreas Seguras para Modificar (Sin Preguntar)

✅ **Interfaces de Usuario:**

- Estilos y diseños
- Widgets visuales
- Pantallas nuevas (que no afecten servicios existentes)

✅ **Modelos de Datos:**

- Nuevos modelos
- Extensiones de modelos existentes (sin romper compatibilidad)

✅ **Nuevas Funcionalidades:**

- Servicios completamente nuevos
- Pantallas independientes
- Utilidades que no afecten servicios existentes

❌ **Áreas Que SIEMPRE Requieren Confirmación:**

- `lib/services/websocket_service.dart` 🔒
- `lib/services/printer_service.dart` 🔒
- `lib/services/print_job_service.dart` 🔒
- `lib/main.dart` (Provider setup)
- Cualquier cambio que afecte la arquitectura global

---

## 🐛 SOLUCIÓN DE PROBLEMAS COMUNES

### "No se puede conectar al WebSocket"

1. Verificar token en configuración
2. Verificar conexión a internet
3. Revisar logs: `WebSocketService` imprime estado de conexión
4. Probar reconexión manual desde UI

### "Impresora no responde"

1. Verificar que la impresora esté encendida
2. Verificar conexión (USB/Bluetooth/Red)
3. Intentar reconectar desde UI
4. Verificar logs de `PrinterService`

### "Lector de huellas no detecta"

1. Verificar que el dispositivo esté conectado
2. Usar modo simulación para probar sin hardware
3. Revisar permisos de USB/HID
4. Verificar logs de `FingerprintReaderService`

### "Error al compilar"

1. Ejecutar `flutter clean`
2. Ejecutar `flutter pub get`
3. Verificar que todas las dependencias estén instaladas
4. En Windows, verificar que los DLLs del SDK Hikvision estén en la carpeta correcta

---

## 📋 CHECKLIST ANTES DE CUALQUIER CAMBIO

- [ ] He leído la documentación relevante (`.md` files)
- [ ] He explorado el código existente
- [ ] He verificado que la funcionalidad no existe ya
- [ ] He identificado los archivos que modificaré
- [ ] He comprobado que no afecto a sistemas 🔒
- [ ] He preguntado si tengo dudas
- [ ] He explicado claramente qué voy a hacer
- [ ] He generado un documento md con los cambios que voy a realizar
- [ ] He recibido confirmación del usuario marcando con un 🟢 lo aprobado, 🟠 Lo que requiere coreccion, y con un 🔴 lo desaprobado en el documento md generado para la tarea asignada o solicitado.

---

## 🎓 CONCEPTOS CLAVE DEL PROYECTO

### 1. ¿Qué es ESC/POS?

Protocolo de comandos para impresoras térmicas de recibos. El proyecto genera estos comandos para imprimir documentos.

### 2. ¿Qué es un WebSocket?

Protocolo de comunicación bidireccional en tiempo real. Usado para recibir solicitudes de impresión y enviar datos de huellas.

### 3. ¿Qué es Provider?

Patrón de gestión de estado en Flutter. Permite compartir datos entre widgets sin pasar parámetros manualmente.

### 4. ¿Qué es FFI?

Foreign Function Interface - Permite llamar código nativo (C/C++) desde Dart. Usado para el SDK de Hikvision.

### 5. ¿Qué es JWT?

JSON Web Token - Token de autenticación usado por la API AnfibiusBack.

---

## 🔄 FLUJOS PRINCIPALES

### Flujo de Impresión

```
Sistema Externo → WebSocket → WebSocketService → PrintJobService → PrinterService → Impresora
                                      ↓
                              Historial (persistente)
```

### Flujo de Lectura de Huellas

```
Dispositivo Físico → FingerprintReaderService → WebSocketService → Servidor Remoto
                              ↓
                      ObjetivosService (registro interno)
```

### Flujo de Autenticación

```
Usuario → AuthService → API AnfibiusBack → JWT Token → Headers de solicitudes futuras
```

## 🎯 MENSAJE FINAL PARA GEMINI

Hola Gemini 👋

Este proyecto tiene sistemas críticos en funcionamiento que sirven a usuarios reales. Tu responsabilidad es:

1. **PROTEGER** lo que funciona
2. **PREGUNTAR** antes de cambiar
3. **EXPLICAR** claramente qué harás
4. **RESPETAR** las marcas 🔒

Trabaja con confianza en áreas seguras, pero siempre con precaución en áreas críticas.

**Gracias por tu colaboración responsable** 🙏
