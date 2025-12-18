# NOTIFICACIONES DEL SISTEMA - ALERTAS DE CONEXIÓN

## Fecha: 2025-12-13

---

## 🎯 OBJETIVO

**Notificar al usuario mediante el sistema operativo cuando hay cambios en la conexión WebSocket**

Funcionalidades:
- ✅ Notificación cuando se desconecta
- ✅ Notificación cuando se reconecta
- ✅ Notificaciones clickeables para forzar reconexión
- ✅ Compatible con Windows, Linux, macOS, Android, iOS

---

## 📋 IMPLEMENTACIÓN

### **CAMBIO 1: Agregar callback en NotificationsService**

**Archivo**: `lib/services/notifications_service.dart`

```dart
class NotificationsService {
  // ... código existente ...
  
  // 🆕 Callback para manejar clicks en notificaciones
  Function(String? payload)? onNotificationClick;
  
  // Método para manejar el tap en la notificación
  void _onNotificationTap(NotificationResponse notificationResponse) {
    debugPrint('Notificación tocada: ${notificationResponse.payload}');
    
    // 🆕 Llamar al callback si está definido
    if (onNotificationClick != null) {
      onNotificationClick!(notificationResponse.payload);
    }
  }
}
```

**Resultado**: Ahora se puede configurar un callback desde fuera del servicio.

---

### **CAMBIO 2: Configurar callback en WebSocketService**

**Archivo**: `lib/services/websocket_service.dart`

```dart
// Agregar import
import '../services/notifications_service.dart';

class WebSocketService extends ChangeNotifier {
  // ... variables existentes ...
  
  // 🆕 Servicio de notificaciones
  final NotificationsService _notificationsService = NotificationsService();
  
  WebSocketService() {
    _initFromStorage();
    _startWatchdog();
    
    // 🆕 Configurar callback para notificaciones
    _notificationsService.onNotificationClick = _handleNotificationClick;
  }
  
  // 🆕 Manejar click en notificaciones
  void _handleNotificationClick(String? payload) {
    logger.info('Notificación clickeada con payload: $payload');
    
    if (payload == 'reconnect') {
      // Usuario clickeó la notificación de desconexión
      logger.info('Usuario solicitó reconexión desde notificación');
      reconnect(); // Forzar reconexión inmediata
    }
  }
}
```

**Resultado**: El WebSocketService maneja los clicks en notificaciones.

---

### **CAMBIO 3: Notificación al desconectar**

**Archivo**: `lib/services/websocket_service.dart` - callback `onDone` (línea ~553)

```dart
onDone: () {
  if (_isDisposed) return;
  if (_isConnecting) return;
  
  print('WebSocket desconectado (onDone)');
  logger.info('WebSocket desconectado (onDone)');
  _isConnected = false;
  
  // 🔔 NOTIFICACIÓN: Desconectado
  _notificationsService.showNotification(
    id: 1,
    title: '⚠️ Anfibius - Desconectado',
    body: 'Conexión perdida. Intentando reconectar automáticamente...',
    payload: 'reconnect', // ← Al hacer click, fuerza reconexión
  );
  
  // ... resto del código ...
  
  if (_shouldAutoReconnect && !_isSystemSuspending) {
    _scheduleReconnect();
  }
},
```

**Resultado**: Cuando se pierde la conexión, aparece notificación del sistema.

---

### **CAMBIO 4: Notificación al reconectar**

**Archivo**: `lib/services/websocket_service.dart` - método `_connect()` (línea ~611)

```dart
_isConnected = true;
_reconnectAttempts = 0;
_isConnecting = false;
_lastSuccessfulActivity = DateTime.now();
_startHeartbeat();
_safeNotifyListeners();
logger.success('✅ CONEXIÓN EXITOSA a: $urlString');
logger.info('Contador de intentos reseteado a 0');

// 🔔 NOTIFICACIÓN: Reconectado
_notificationsService.showNotification(
  id: 2,
  title: '✅ Anfibius - Conectado',
  body: 'Conexión restablecida exitosamente',
  payload: 'connected',
);

return;
```

**Resultado**: Cuando se reconecta, aparece notificación de éxito.

---

## 🖼️ EJEMPLOS DE NOTIFICACIONES

### **Windows**:
```
┌─────────────────────────────────────┐
│ ⚠️ Anfibius - Desconectado          │
│ Conexión perdida. Intentando        │
│ reconectar automáticamente...       │
│                                     │
│ [Click para reconectar ahora]       │
└─────────────────────────────────────┘
```

```
┌─────────────────────────────────────┐
│ ✅ Anfibius - Conectado             │
│ Conexión restablecida exitosamente │
└─────────────────────────────────────┘
```

### **Android/Linux/macOS**:
Similar, adaptado al estilo de cada sistema operativo.

---

## 🔄 FLUJO DE USUARIO

### **Escenario 1: Reconexión automática**

1. **Usuario pierde internet** → Notificación aparece:
   ```
   ⚠️ Anfibius - Desconectado
   Conexión perdida. Intentando reconectar automáticamente...
   ```

2. **App intenta reconectar** (cada 1s, 2s, 3s, 5s, 10s, 15s...)

3. **Internet vuelve** → App reconecta → Nueva notificación:
   ```
   ✅ Anfibius - Conectado
   Conexión restablecida exitosamente
   ```

### **Escenario 2: Reconexión manual desde notificación**

1. **Usuario pierde internet** → Notificación aparece

2. **Usuario hace CLICK en la notificación** → App inmediatamente:
   - Llama a `reconnect()`
   - Limpia conexión existente con `_emergencyCleanup()`
   - Fuerza reconexión inmediata sin esperar el timer

3. **Si internet está disponible** → Reconecta instantáneamente

---

## 📊 VENTAJAS

| Característica | Antes | Ahora |
|----------------|-------|-------|
| Usuario sabe que se desconectó | ❌ No | ✅ Notificación visual |
| Usuario sabe que se reconectó | ❌ No | ✅ Notificación visual |
| Usuario puede forzar reconexión | ⚠️ Solo desde botón en app | ✅ Desde notificación también |
| Funciona en background | ❌ No | ✅ Sí (notificaciones del SO) |
| Compatible multiplataforma | - | ✅ Windows, Linux, macOS, Android, iOS |

---

## 🛠️ CÓDIGO TÉCNICO

### **Payload de notificaciones**:

```dart
// Notificación de desconexión
payload: 'reconnect' 
// → Al hacer click: llama reconnect()

// Notificación de conexión exitosa
payload: 'connected'
// → Al hacer click: no hace nada (solo informativa)
```

### **IDs de notificaciones**:

```dart
id: 1  // Desconexión (se reemplaza si hay múltiples desconexiones)
id: 2  // Conexión exitosa (se reemplaza si hay múltiples conexiones)
```

**Ventaja**: Usar el mismo ID evita spam de notificaciones. Solo se muestra la más reciente.

---

## 🔧 PERSONALIZACIÓN

### **Cambiar texto de notificaciones**:

En `websocket_service.dart`, modificar los parámetros de `showNotification()`:

```dart
// Desconexión
title: '⚠️ Tu título aquí',
body: 'Tu mensaje aquí',

// Reconexión
title: '✅ Tu título aquí',
body: 'Tu mensaje aquí',
```

### **Agregar sonido** (solo Android/iOS):

En `notifications_service.dart`, modificar `AndroidNotificationDetails`:

```dart
AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'default_channel',
      'Notificaciones',
      channelDescription: 'Canal de notificaciones predeterminado',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,  // ← Agregar esto
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );
```

---

## 📋 ARCHIVOS MODIFICADOS

| Archivo | Líneas | Cambio |
|---------|--------|--------|
| `websocket_service.dart` | 1-11 | Import de NotificationsService |
| `websocket_service.dart` | 56-57 | Variable _notificationsService |
| `websocket_service.dart` | 67-87 | Configurar callback en constructor |
| `websocket_service.dart` | 553-563 | Notificación al desconectar |
| `websocket_service.dart` | 619-626 | Notificación al reconectar |
| `notifications_service.dart` | 14-15 | Callback onNotificationClick |
| `notifications_service.dart` | 77-86 | Llamar callback en _onNotificationTap |
| `NOTIFICACIONES_SISTEMA.md` | Nuevo | Esta documentación |

---

## 🚀 INSTRUCCIONES DE USO

### **1. Recompilar la app**:
```cmd
flutter clean
flutter pub get
flutter build windows --release
```

### **2. Probar notificaciones**:

1. **Iniciar la app** → Debe conectarse normalmente

2. **Desconectar internet** → Debe aparecer notificación:
   ```
   ⚠️ Anfibius - Desconectado
   Conexión perdida. Intentando reconectar automáticamente...
   ```

3. **Hacer CLICK en la notificación** → App intenta reconectar inmediatamente

4. **Reconectar internet** → Debe aparecer notificación:
   ```
   ✅ Anfibius - Conectado
   Conexión restablecida exitosamente
   ```

### **3. Verificar logs**:

Presionar botón 📄 en la app y buscar:
```
[HH:MM:SS] [INFO] WebSocket desconectado (onDone)
[HH:MM:SS] [INFO] Notificación clickeada con payload: reconnect
[HH:MM:SS] [INFO] Usuario solicitó reconexión desde notificación
[HH:MM:SS] [INFO] Reconexión manual solicitada
[HH:MM:SS] [SUCCESS] ✅ CONEXIÓN EXITOSA a: wss://...
```

---

## 🐛 TROUBLESHOOTING

### **Las notificaciones no aparecen**:

1. **Windows**: Verificar que las notificaciones estén habilitadas:
   - Configuración → Sistema → Notificaciones y acciones
   - Buscar "Anfibius" y habilitar

2. **Android**: Verificar permisos:
   - Configuración → Apps → Anfibius → Notificaciones → Habilitar

3. **Verificar logs**: Buscar errores de `NotificationsService`

### **Click en notificación no funciona**:

1. Verificar que el callback esté configurado en constructor
2. Revisar logs: Debe aparecer "Notificación clickeada con payload: reconnect"
3. Verificar que `reconnect()` sea llamado

### **Notificaciones duplicadas**:

- Normal, se usa el mismo ID para reemplazar notificaciones antiguas
- Si aparecen múltiples, verificar que se use `id: 1` y `id: 2` correctamente

---

## ✅ RESUMEN

### **Características implementadas**:
1. ✅ Notificación del SO cuando se desconecta
2. ✅ Notificación del SO cuando se reconecta
3. ✅ Click en notificación de desconexión → Fuerza reconexión
4. ✅ Callback configurable en NotificationsService
5. ✅ Logging completo de interacciones

### **Beneficios**:
- Usuario **siempre sabe** el estado de la conexión
- Usuario puede **reconectar desde la notificación** sin abrir la app
- Notificaciones funcionan **incluso si la app está en background**
- Compatible con **todos los sistemas operativos**

### **Próximos pasos**:
1. Recompilar app
2. Probar desconexión/reconexión
3. Probar click en notificación
4. Verificar logs

---

**Última actualización**: 2025-12-13  
**Versión de la app**: 1.0.0+1  
**Prioridad**: ALTA ⚠️  
**Estado**: LISTO PARA PROBAR ✅
