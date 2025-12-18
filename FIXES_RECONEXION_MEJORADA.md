# 🔧 MEJORAS DE RECONEXIÓN - Fix para Desconexión de Internet

## 🔍 Problema Reportado

**Escenario**: 
1. App compilada en Windows, ejecutándose
2. Desconectar internet durante 5+ minutos
3. Reconectar internet
4. **App no se reconecta automáticamente**

---

## ✅ Soluciones Implementadas

### **1. Watchdog Timer Mejorado**

**Archivo**: `lib/services/websocket_service.dart:71-164`

**Mejoras**:
- Timeout reducido de **5 minutos a 3 minutos** para detección más rápida
- Asegura que `_shouldAutoReconnect = true` antes de reconectar
- Verifica que no está en `_isSystemSuspending` antes de reconectar
- Logs detallados para debugging

**Código clave**:
```dart
// Timeout reducido a 3 minutos
static const Duration _watchdogTimeout = Duration(minutes: 3);

// Recuperación forzada con flags correctos
_shouldAutoReconnect = true;
if (!_isDisposed && !_isSystemSuspending) {
  _reconnectAttempts = 0;
  _isConnecting = false;
  _connect();
}
```

---

### **2. Método `reconnect()` Público**

**Archivo**: `lib/services/websocket_service.dart:732-778`

**Funcionalidad**:
- Permite reconexión manual desde la UI
- Logs detallados del estado interno
- Limpieza completa antes de reconectar
- Habilita `_shouldAutoReconnect` automáticamente

**Uso desde UI**:
```dart
webSocketService.reconnect();
```

**Logs de debug**:
```
🔄 Reconexión manual solicitada
📊 Estado actual:
   - _isDisposed: false
   - _isConnected: false
   - _isConnecting: false
   - _shouldAutoReconnect: true
   - _isSystemSuspending: false
   - Token disponible: true
✅ AutoReconnect habilitado
🚀 Iniciando reconexión directa...
```

---

### **3. Botón Flotante de Reconexión Manual**

**Archivo**: `lib/main.dart:890-923`

**Características**:
- Solo aparece cuando **NO está conectado**
- Color naranja para visibilidad
- Icono de WiFi desconectado
- Mensaje de confirmación "Reconectando..."

**UI**:
```
┌─────────────────────────┐
│                         │
│                         │
│        CONTENIDO        │
│                         │
│                    ┌──┐ │  ← Botón naranja con WiFi off
│                    │⚠️│ │     (solo visible si desconectado)
│                    └──┘ │
│                    ┌──┐ │
│                    │⚙️│ │  ← Botón de configuración
│                    └──┘ │
└─────────────────────────┘
```

**Código**:
```dart
Consumer<WebSocketService>(
  builder: (context, webSocketService, child) {
    if (!webSocketService.isConnected) {
      return FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reconectando...')),
          );
          webSocketService.reconnect();
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.wifi_off),
      );
    }
    return const SizedBox.shrink();
  },
)
```

---

### **4. Emergency Cleanup Mejorado**

**Archivo**: `lib/services/websocket_service.dart:167-194`

**Mejoras**:
- Cancela TODOS los timers sin excepciones
- Cierra subscripciones y canales correctamente
- Resetea todos los flags necesarios
- Try-catch para prevenir crashes durante cleanup

**Flujo**:
```
_emergencyCleanup()
    ↓
Cancelar timers:
  - _reconnectTimer
  - _heartbeatTimer  
  - _connectionCheckTimer
    ↓
Cerrar conexiones:
  - _subscription
  - _channel
    ↓
Resetear flags:
  - _isConnected = false
  - _isConnecting = false
    ↓
✅ Listo para reconectar
```

---

## 🔄 Flujo Completo de Reconexión

### **Escenario 1: Watchdog Detecta Problema (Automático)**

```
1. Internet desconectado
   ↓
2. Pasan 3 minutos sin actividad
   ↓
3. Watchdog detecta estado zombie
   🐕 "Última actividad hace: 3 minutos"
   ↓
4. _emergencyCleanup()
   🧹 "Limpiando recursos zombies"
   ↓
5. _shouldAutoReconnect = true
   ✅ "AutoReconnect habilitado"
   ↓
6. Espera 3 segundos
   ⏱️
   ↓
7. _connect()
   🔄 "Intentando conectar a: wss://..."
   ↓
8. Internet disponible → Conexión exitosa ✅
   Internet NO disponible → _scheduleReconnect()
```

### **Escenario 2: Usuario Presiona Botón (Manual)**

```
1. Usuario ve botón naranja (WiFi off)
   ↓
2. Presiona botón
   👆 Click
   ↓
3. SnackBar: "Reconectando..."
   📨
   ↓
4. webSocketService.reconnect()
   📊 Logs de estado actual
   ↓
5. _shouldAutoReconnect = true
   ✅ "AutoReconnect habilitado"
   ↓
6. _emergencyCleanup()
   🧹 (si había conexión anterior)
   ↓
7. _connect()
   🚀 "Iniciando reconexión directa"
   ↓
8. Intenta conectar inmediatamente
   ↓
9. Éxito → Botón desaparece ✅
   Fallo → _scheduleReconnect() (backoff exponencial)
```

### **Escenario 3: Backoff Exponencial (_scheduleReconnect)**

```
Intento 1:  5 segundos  → Fallo
Intento 2: 10 segundos  → Fallo
Intento 3: 20 segundos  → Fallo
Intento 4: 40 segundos  → Fallo
Intento 5: 60 segundos  → Fallo
Intento 6: 60 segundos  → Fallo (mantiene 60s)
Intento 7: 60 segundos  → Éxito ✅

* Sigue intentando INDEFINIDAMENTE
* Nunca se rinde
```

---

## 🧪 Cómo Probar

### **Prueba 1: Desconexión Prolongada (Watchdog)**

1. Compilar y ejecutar app en Windows
   ```bash
   flutter build windows --release
   ./build/windows/x64/runner/Release/anfibius_uwu.exe
   ```

2. Verificar que está conectado (luz verde en UI)

3. Desconectar internet completamente
   - WiFi: Apagar
   - Ethernet: Desconectar cable

4. Esperar **3-4 minutos**

5. Observar logs:
   ```
   🐕 Watchdog check - Última actividad hace: 3 minutos
   ⚠️ WATCHDOG: Detectado estado zombie
   🔧 WATCHDOG: Intentando recuperación automática
   🧹 EMERGENCY CLEANUP - Limpiando recursos zombies
   ```

6. Reconectar internet

7. Dentro de 3-5 segundos, debería ver:
   ```
   🔄 Ejecutando reconexión forzada
   Intentando conectar a: wss://soporte.anfibius.net:3300/...
   ✅ Conexión exitosa
   ```

### **Prueba 2: Reconexión Manual (Botón)**

1. App ejecutándose, conectada

2. Desconectar internet

3. Esperar 10-20 segundos

4. **Observar**: Debe aparecer botón flotante **NARANJA** con icono WiFi off

5. Reconectar internet

6. **Presionar** el botón naranja

7. Observar:
   - SnackBar: "Reconectando..."
   - Logs detallados en consola
   - Botón desaparece al conectar

### **Prueba 3: Suspensión + Desconexión**

1. App conectada

2. Desconectar internet

3. Cerrar tapa de laptop (Sleep)

4. Esperar 2-3 minutos

5. Reconectar internet

6. Abrir laptop

7. Observar:
   ```
   ▶️ App en primer plano
   🔄 Windows: Esperando 3 segundos para estabilización
   _isSystemSuspending = false
   🔄 Reconectando después de 2 segundos
   ```

8. Debería reconectar automáticamente

---

## 📊 Logs Importantes

### **Reconexión Exitosa**
```
🔄 [2025-12-13 10:30:00] Reconexión manual solicitada
📊 Estado actual:
   - _isDisposed: false
   - _isConnected: false
   - _isConnecting: false
   - _shouldAutoReconnect: true
   - _isSystemSuspending: false
   - Token disponible: true
✅ [2025-12-13 10:30:00] AutoReconnect habilitado
🚀 [2025-12-13 10:30:00] Iniciando reconexión directa...
Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
✅ Conexión exitosa
```

### **Watchdog Detecta Problema**
```
🐕 [2025-12-13 10:33:00] Watchdog check - Última actividad hace: 3 minutos
⚠️ [2025-12-13 10:33:00] WATCHDOG: Detectado estado zombie (sin actividad por 3 min)
🔧 [2025-12-13 10:33:00] WATCHDOG: Intentando recuperación automática...
🧹 [2025-12-13 10:33:00] EMERGENCY CLEANUP - Limpiando recursos zombies
✅ [2025-12-13 10:33:00] Emergency cleanup completado
🔄 [2025-12-13 10:33:03] WATCHDOG: Ejecutando reconexión forzada...
```

### **Error de Reconexión (Sin Internet)**
```
🔄 [2025-12-13 10:30:05] Programando reconexión #1 en 5s...
🔄 [2025-12-13 10:30:10] Intentando reconectar al WebSocket (intento #1)...
❌ Error conectando a wss://...: SocketException
🔄 [2025-12-13 10:30:10] Programando reconexión #2 en 10s...
```

---

## 🎯 Resultados Esperados

### **ANTES**:
- ❌ Desconectar internet → Esperar 5 min → Reconectar → **NO reconecta**
- ❌ Usuario debe cerrar y reabrir la app
- ❌ Sin feedback visual del estado
- ❌ Sin forma de forzar reconexión

### **DESPUÉS**:
- ✅ Watchdog detecta problema en 3 minutos
- ✅ Reconexión automática cuando vuelve internet
- ✅ Botón manual visible cuando está desconectado
- ✅ Logs detallados para debugging
- ✅ Reconexión funciona después de suspensión
- ✅ Usuario puede forzar reconexión con 1 click

---

## 🔧 Archivos Modificados

1. **`lib/services/websocket_service.dart`**
   - Watchdog timeout: 5min → 3min
   - `reconnect()` público añadido (línea 732)
   - Logs mejorados en watchdog y reconnect
   - `_shouldAutoReconnect` forzado a `true` en recuperación

2. **`lib/main.dart`**
   - Botón flotante de reconexión añadido (línea 892)
   - Consumer de WebSocketService
   - SnackBar de confirmación

3. **`FIXES_RECONEXION_MEJORADA.md`** (NUEVO)
   - Esta documentación completa

---

## 🐛 Debugging

Si la reconexión NO funciona, revisar:

1. **Logs del watchdog**:
   - ¿Aparece "Watchdog check" cada 2 minutos?
   - ¿Detecta estado zombie después de 3 minutos?

2. **Estado del servicio**:
   - ¿`_isDisposed = false`?
   - ¿`_shouldAutoReconnect = true`?
   - ¿`_isSystemSuspending = false`?
   - ¿`Token disponible: true`?

3. **Errores de conexión**:
   - ¿Hay errores de SocketException?
   - ¿Timeout al conectar?
   - ¿Certificado SSL rechazado?

4. **Botón de reconexión**:
   - ¿Aparece el botón naranja cuando está desconectado?
   - ¿Al presionarlo muestra "Reconectando..."?
   - ¿Qué logs aparecen en consola?

---

## 📝 Comandos Útiles

```bash
# Compilar release
flutter build windows --release

# Ejecutar con logs
./build/windows/x64/runner/Release/anfibius_uwu.exe

# Ver logs de Windows Event Viewer
eventvwr.msc

# Limpiar build
flutter clean && flutter pub get
```

---

**Fecha**: 2025-12-13  
**Versión**: 3.0.0 (Reconexión Mejorada)  
**Estado**: ✅ IMPLEMENTADO - LISTO PARA PROBAR
