# 📝 Sistema de Logging a Archivo

## 🎯 Objetivo

Guardar automáticamente todos los logs de la aplicación en archivos de texto para:
- **Debugging** en producción sin acceso a la consola
- **Auditoría** de eventos y errores
- **Soporte técnico** - Los usuarios pueden compartir logs
- **Análisis** de problemas de reconexión y suspensión

---

## ✅ Implementación Completa

### **1. Servicio de Logging (`logger_service.dart`)**

**Ubicación**: `lib/services/logger_service.dart`

**Características**:
- ✅ Guarda logs en archivos de texto diarios
- ✅ Rotación automática (mantiene últimos 7 días)
- ✅ Buffer en memoria con flush cada 50 líneas o 30 segundos
- ✅ Niveles de log: ERROR, WARN, INFO, DEBUG, SUCCESS
- ✅ Timestamp en cada línea
- ✅ Exportación y compartir logs
- ✅ Limpieza de logs antiguos automática

**Ubicación de archivos**:
```
Windows: C:\Users\[Usuario]\Documents\anfibius_logs\
Android: /storage/emulated/0/Android/data/com.example.app/files/anfibius_logs/
Linux: ~/Documents/anfibius_logs/
macOS: ~/Documents/anfibius_logs/
```

**Formato de archivo**:
```
anfibius_log_2025-12-13.txt
anfibius_log_2025-12-14.txt
anfibius_log_2025-12-15.txt
...
```

**Formato de log**:
```
================================================================================
ANFIBIUS CONNECT NEXUS UTILITY - LOG
Fecha: 2025-12-13
Inicio de sesión: 10:30:00
================================================================================

[10:30:01.234] [INFO] ℹ️ Logger Service inicializado
[10:30:02.456] [SUCCESS] ✅ Conexión exitosa
[10:30:15.789] [WARN] ⚠️ WATCHDOG: Detectado estado zombie
[10:30:16.012] [ERROR] ❌ Error en conexión: SocketException
   Error: Connection refused
   Stack trace: ...
```

**Uso en código**:
```dart
import 'package:anfibius_uwu/services/logger_service.dart';

// Logs con nivel
logger.info('Mensaje informativo');
logger.success('Operación exitosa');
logger.warning('Advertencia');
logger.error('Error crítico', error: e, stackTrace: st);
logger.debug('Información de debug');

// O usar log genérico
logger.log('Mensaje personalizado', level: 'CUSTOM');
```

---

### **2. Pantalla de Visualización (`logs_screen.dart`)**

**Ubicación**: `lib/logs_screen.dart`

**Características**:
- 📱 Vista de logs con formato terminal (fondo negro, texto verde)
- 📅 Selector de archivo de log (hoy + últimos 7 días)
- 🔄 Botón de recarga
- 📋 Copiar logs al portapapeles
- 📤 Compartir/Exportar logs
- 🗑️ Eliminar todos los logs (con confirmación)
- ⬇️ Auto-scroll al final (activable/desactivable)
- 🔍 Texto seleccionable para copiar secciones

**UI**:
```
┌─────────────────────────────────────────────┐
│ ← Logs del Sistema  [↕️][🔄][📋][📤][🗑️]   │
├─────────────────────────────────────────────┤
│ Archivo: [Hoy (actual) ▼]                  │
├─────────────────────────────────────────────┤
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                                             │
│ [10:30:01.234] [INFO] Logger Service...   │
│ [10:30:02.456] [SUCCESS] Conexión exitosa │
│ [10:30:15.789] [WARN] Watchdog: zombie... │
│ [10:30:16.012] [ERROR] Error: Socket...   │
│                                             │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────────┘
```

**Acceso**:
- Desde AppBar principal: Icono de documento (📄)
- O desde configuración/settings

---

### **3. Integración en WebSocketService**

**Archivo**: `lib/services/websocket_service.dart`

**Logs importantes guardados**:
- ✅ Watchdog checks (cada 2 minutos)
- ✅ Detección de estado zombie
- ✅ Intentos de recuperación automática
- ✅ Reconexiones (manual y automática)
- ✅ Errores de conexión
- ✅ Emergency cleanup
- ✅ Estados críticos

**Ejemplo de logs generados**:
```
[10:30:00.123] [DEBUG] Watchdog check - Última actividad hace: 0 minutos
[10:33:00.456] [DEBUG] Watchdog check - Última actividad hace: 3 minutos
[10:33:00.457] [WARN] WATCHDOG: Detectado estado zombie (sin actividad por 3 min)
[10:33:00.458] [INFO] WATCHDOG: Intentando recuperación automática...
[10:33:00.459] [INFO] EMERGENCY CLEANUP - Limpiando recursos zombies...
[10:33:00.460] [SUCCESS] Emergency cleanup completado
[10:33:03.789] [INFO] WATCHDOG: Ejecutando reconexión forzada...
[10:33:04.012] [SUCCESS] Conexión exitosa
```

---

### **4. Integración en main.dart**

**Archivo**: `lib/main.dart`

**Inicialización**:
```dart
// En _mainInit()
await logger.init();
logger.success('Logger Service inicializado');
```

**Captura de errores Flutter**:
```dart
FlutterError.onError = (FlutterErrorDetails details) {
  print('❌ Flutter Error: ${details.exception}');
  logger.error('Flutter Error: ${details.exception}', 
               stackTrace: details.stack);
};
```

**Botón en AppBar**:
```dart
IconButton(
  icon: const Icon(Icons.article_outlined),
  onPressed: () {
    Navigator.push(context, 
      MaterialPageRoute(builder: (context) => const LogsScreen()));
  },
  tooltip: 'Ver logs del sistema',
)
```

---

## 📊 Gestión de Logs

### **Rotación Automática**
- Se crea un nuevo archivo cada día
- Formato: `anfibius_log_YYYY-MM-DD.txt`
- Los logs antiguos (7+ días) se eliminan automáticamente

### **Buffer en Memoria**
- Logs se guardan en buffer primero
- Flush automático cada:
  - 50 líneas acumuladas
  - 30 segundos transcurridos
- Flush manual al cerrar app o cambiar día

### **Tamaño de Archivos**
Estimación por día:
- Uso normal: ~100-500 KB
- Con muchos errores: ~1-2 MB
- Máximo 7 días = ~7-14 MB total

---

## 🔧 Métodos Disponibles

### **LoggerService**

```dart
// Inicializar (llamar una vez al inicio)
await logger.init();

// Escribir logs
logger.log(String message, {String level = 'INFO'})
logger.info(String message)
logger.success(String message)
logger.warning(String message)
logger.error(String message, {Object? error, StackTrace? stackTrace})
logger.debug(String message)

// Obtener logs
Future<String> getCurrentLogs()
Future<List<File>> getLogFiles()
Future<String> getLogDirectoryPath()

// Exportar/Compartir
Future<File?> exportLogs(String destinationPath)

// Limpiar
Future<void> clearAllLogs()

// Cerrar (llamar al cerrar app)
Future<void> dispose()
```

---

## 🧪 Pruebas

### **Prueba 1: Verificar Creación de Logs**

1. Compilar y ejecutar app
2. Realizar acciones (conectar, desconectar, etc.)
3. Ir a pantalla de Logs (icono 📄 en AppBar)
4. Verificar que aparecen mensajes con timestamps
5. Presionar "Compartir" para ver ubicación del archivo

### **Prueba 2: Verificar Rotación**

1. Cambiar fecha del sistema a mañana
2. Ejecutar app
3. Verificar que se crea nuevo archivo
4. Restaurar fecha
5. Verificar que ambos archivos están disponibles

### **Prueba 3: Watchdog en Logs**

1. Ejecutar app conectada
2. Desconectar internet
3. Esperar 3 minutos
4. Abrir pantalla de Logs
5. Verificar mensajes de watchdog:
   - "Watchdog check"
   - "Detectado estado zombie"
   - "Intentando recuperación automática"

### **Prueba 4: Exportar Logs**

**Windows**:
1. Presionar icono "Compartir"
2. Ver diálogo con ruta del archivo
3. Presionar "Copiar Ruta"
4. Abrir explorador de archivos
5. Pegar ruta y acceder al archivo

**Android**:
1. Presionar icono "Compartir"
2. Seleccionar app para compartir (WhatsApp, Email, etc.)
3. Verificar que se adjunta el archivo

---

## 📁 Estructura de Archivos

```
lib/
├── services/
│   ├── logger_service.dart          ← NUEVO: Servicio de logging
│   ├── websocket_service.dart       ← Modificado: Usa logger
│   └── ...
├── logs_screen.dart                 ← NUEVO: Pantalla de logs
├── main.dart                        ← Modificado: Init logger + botón
└── ...

Documents/anfibius_logs/              ← Archivos de log
├── anfibius_log_2025-12-13.txt
├── anfibius_log_2025-12-14.txt
└── ...
```

---

## 🎯 Casos de Uso

### **Usuario reporta problema**
```
Usuario: "La app no reconecta después de suspensión"

Soporte:
1. Pedir al usuario ir a Logs (icono 📄)
2. Presionar "Compartir"
3. Enviar archivo de log por email/WhatsApp
4. Analizar logs del día del problema
5. Buscar mensajes de "WATCHDOG", "zombie", "suspended"
```

### **Debugging en producción**
```
Desarrollador:
1. Usuario reporta crash
2. Solicitar logs del día del crash
3. Buscar "[ERROR]" en el archivo
4. Ver stack traces completos
5. Identificar causa raíz
```

### **Análisis de rendimiento**
```
Analista:
1. Recopilar logs de varios días
2. Buscar patrones:
   - Frecuencia de watchdog alerts
   - Tiempos de reconexión
   - Errores recurrentes
3. Identificar mejoras necesarias
```

---

## 🔒 Privacidad

**Información guardada**:
- ✅ Timestamps de eventos
- ✅ Tipos de mensajes recibidos (VENTA, COMANDA, etc.)
- ✅ Estados de conexión (conectado, desconectado)
- ✅ Errores técnicos

**NO se guarda**:
- ❌ Contenido de facturas/comandas
- ❌ Datos de clientes
- ❌ Tokens de autenticación (solo primeros caracteres)
- ❌ Contraseñas

---

## 📋 Dependencias Agregadas

**pubspec.yaml**:
```yaml
dependencies:
  path_provider: ^2.1.1    # Para obtener directorio de documentos
  intl: ^0.19.0            # Para formato de fechas
  share_plus: ^10.1.2      # Para compartir archivos (móvil)
```

---

## 🚀 Próximos Pasos

**Mejoras futuras posibles**:
- [ ] Filtro por nivel de log (solo errores, solo warnings, etc.)
- [ ] Búsqueda dentro de logs
- [ ] Exportar como ZIP con múltiples días
- [ ] Upload automático a servidor de soporte
- [ ] Gráficos de estadísticas de logs
- [ ] Notificación cuando hay errores críticos

---

**Fecha**: 2025-12-13  
**Versión**: 1.0.0  
**Estado**: ✅ IMPLEMENTADO Y FUNCIONAL

---

## 📝 Resumen para Usuario Final

### **¿Dónde ver los logs?**
1. Abre la app
2. Presiona el icono de documento (📄) en la barra superior
3. ¡Listo! Verás todos los logs del día

### **¿Cómo compartir logs con soporte?**
1. Abre los logs (icono 📄)
2. Presiona el icono de compartir (📤)
3. En Windows: copia la ruta y envía el archivo
4. En Android: selecciona WhatsApp/Email y envía

### **¿Los logs ocupan mucho espacio?**
No. La app mantiene solo los últimos 7 días y cada día ocupa ~100-500 KB.
Total: menos de 5 MB en tu dispositivo.

### **¿Puedo eliminar los logs?**
Sí. Presiona el icono de basurero (🗑️) en la pantalla de logs.
Se te pedirá confirmación antes de eliminar.
