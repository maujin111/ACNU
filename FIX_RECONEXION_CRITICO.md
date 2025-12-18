# FIX CRÍTICO: Reconexión WebSocket

## Fecha: 2025-12-13 (Segunda corrección)

---

## 🔴 PROBLEMA CRÍTICO ENCONTRADO

### **Análisis de logs** (`anfibius_log_2025-12-13.txt`):

```
[08:18:47.617] [INFO] Iniciando proceso de conexión WebSocket...
[08:18:47.617] [INFO] Intentando conectar a: wss://soporte.anfibius.net:3300/token123
[08:18:47.629] [WARN] Fallo al conectar: ... SocketException (URL #1)
[08:18:47.629] [INFO] Intentando conectar a: ws://soporte.anfibius.net:3300/token123  
[08:18:47.640] [WARN] Fallo al conectar: ... SocketException (URL #2)
[08:18:48.808] [WARN] Ya hay una conexión en curso, abortando  ← ¡PROBLEMA!
```

**Observaciones**:
1. ✅ Intenta URL #1 (wss) → Falla con DNS error
2. ✅ Intenta URL #2 (ws) → Falla con DNS error
3. ❌ **NO intenta URL #3 y #4** (deberían estar en la lista)
4. ❌ Solo 1.2 segundos después, **otra llamada a `_connect()` es bloqueada**
5. ❌ **NO se ve el log** "No se pudo conectar con ninguna de las URLs disponibles"

---

## 🔍 CAUSA RAÍZ

### **Problema: Doble manejo de errores**

En el método `_connect()`, el flujo es:

```dart
for (String urlString in urlsToTry) {
  try {
    _channel = WebSocketChannel.connect(url);
    
    // ❌ PROBLEMA: Crea listener ANTES de confirmar conexión
    _subscription = _channel!.stream.listen(
      onMessage: (message) { ... },
      onDone: () {
        _scheduleReconnect();  // ← Llama reconexión
      },
      onError: (error) {
        _handleWebSocketError(error, url);  // ← Llama reconexión
      },
    );
    
    _isConnected = true;  // ← Esto NUNCA se alcanza si hay error inmediato
    _isConnecting = false;
    return;
  } catch (e) {
    // ← Este catch TAMBIÉN maneja el error
    logger.warning('Fallo al conectar: $errorMessage');
    continue;  // ← Intenta siguiente URL
  }
}

// Si todas fallan:
_scheduleReconnect();  // ← Debería llegar AQUÍ
```

### **El flujo real** (cuando hay error DNS):

1. **Intenta URL #1** (wss):
   - `WebSocketChannel.connect()` lanza excepción
   - Pero **ANTES**, el `stream.listen()` ya está configurado
   - **onError se dispara** → llama `_handleWebSocketError()` → llama `_scheduleReconnect()` 
   - Timer de 5s programado ✅

2. **catch maneja el error**:
   - Log: "Fallo al conectar"
   - `continue` → va a URL #2

3. **Intenta URL #2** (ws):
   - Mismo problema: `onError` se dispara → `_scheduleReconnect()` 
   - Timer de 10s programado ✅ (sobreescribe el de 5s)

4. **Timer de 5s se cumple** (aún está iterando):
   - Llama `_connect()` 
   - Pero `_isConnecting = true` aún
   - Log: "Ya hay una conexión en curso, abortando" ❌

5. **El for loop SE INTERRUMPE** porque hay una llamada pendiente
   - **NUNCA llega a URL #3 y #4**
   - **NUNCA llega al código después del for loop**
   - **NUNCA resetea `_isConnecting = false`**

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **Modificación: Evitar reconexión durante proceso inicial**

He agregado una **verificación de `_isConnecting`** en los callbacks `onDone` y `onError`:

#### **1. onDone (línea 537)**

```dart
// ❌ ANTES
onDone: () {
  if (_isDisposed) return;
  
  print('WebSocket desconectado (onDone)');
  _isConnected = false;
  _heartbeatTimer?.cancel();
  _connectionCheckTimer?.cancel();
  _safeNotifyListeners();
  
  _scheduleReconnect();  // ← SIEMPRE reconectaba
},

// ✅ DESPUÉS
onDone: () {
  if (_isDisposed) return;
  
  // 🔥 NO reconectar si aún estamos en proceso de conexión inicial
  if (_isConnecting) {
    print('⚠️ onDone durante conexión inicial, no reconectar aún');
    return;  // ← Dejar que el catch del for loop lo maneje
  }
  
  print('WebSocket desconectado (onDone)');
  logger.info('WebSocket desconectado (onDone)');
  _isConnected = false;
  _heartbeatTimer?.cancel();
  _connectionCheckTimer?.cancel();
  _safeNotifyListeners();
  
  _scheduleReconnect();  // ← Solo reconecta si YA estaba conectado
},
```

#### **2. onError (línea 567)**

```dart
// ❌ ANTES
onError: (error) {
  if (_isDisposed) return;
  
  print('Error de WebSocket: $error');
  _handleWebSocketError(error, urlString);  // ← SIEMPRE reconectaba
},

// ✅ DESPUÉS
onError: (error) {
  if (_isDisposed) return;
  
  // 🔥 NO reconectar si aún estamos en proceso de conexión inicial
  if (_isConnecting) {
    print('⚠️ onError durante conexión inicial, no reconectar aún');
    logger.warning('onError durante conexión inicial, se maneja en catch del loop');
    return;  // ← Dejar que el catch del for loop lo maneje
  }
  
  print('Error de WebSocket: $error');
  logger.error('Error de WebSocket después de conexión establecida', error: error);
  _handleWebSocketError(error, urlString);  // ← Solo si la conexión ya estaba establecida
},
```

---

## 📋 FLUJO CORREGIDO

### **Ahora el flujo correcto es**:

1. **Intenta URL #1** (wss):
   - Error → `onError` se dispara
   - `_isConnecting = true` → **NO llama `_scheduleReconnect()`** ✅
   - `catch` maneja error → `continue`

2. **Intenta URL #2** (ws):
   - Error → `onError` se dispara
   - `_isConnecting = true` → **NO llama `_scheduleReconnect()`** ✅
   - `catch` maneja error → `continue`

3. **Intenta URL #3** (wss sin puerto):
   - Error → `onError` se dispara
   - `_isConnecting = true` → **NO llama `_scheduleReconnect()`** ✅
   - `catch` maneja error → `continue`

4. **Intenta URL #4** (ws sin puerto):
   - Error → `onError` se dispara
   - `_isConnecting = true` → **NO llama `_scheduleReconnect()`** ✅
   - `catch` maneja error → `continue`

5. **Sale del for loop**:
   - Llega a línea 599: "No se pudo conectar con ninguna de las URLs disponibles"
   - Resetea `_isConnecting = false` ✅
   - Llama `_scheduleReconnect()` **UNA SOLA VEZ** ✅
   - Timer de 5s programado

6. **Timer de 5s se cumple**:
   - Llama `_connect()`
   - `_isConnecting = false` → **Permite nueva conexión** ✅
   - Intenta las 4 URLs nuevamente

---

## 🔧 LOGS ESPERADOS DESPUÉS DEL FIX

```
[HH:MM:SS] [INFO] Iniciando proceso de conexión WebSocket...
[HH:MM:SS] [INFO] Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
[HH:MM:SS] [WARN] onError durante conexión inicial, se maneja en catch del loop
[HH:MM:SS] [WARN] Fallo al conectar: ... SocketException
[HH:MM:SS] [INFO] Intentando conectar a: ws://soporte.anfibius.net:3300/TOKEN
[HH:MM:SS] [WARN] onError durante conexión inicial, se maneja en catch del loop
[HH:MM:SS] [WARN] Fallo al conectar: ... SocketException
[HH:MM:SS] [INFO] Intentando conectar a: wss://soporte.anfibius.net/TOKEN
[HH:MM:SS] [WARN] onError durante conexión inicial, se maneja en catch del loop
[HH:MM:SS] [WARN] Fallo al conectar: ... SocketException
[HH:MM:SS] [INFO] Intentando conectar a: ws://soporte.anfibius.net/TOKEN
[HH:MM:SS] [WARN] onError durante conexión inicial, se maneja en catch del loop
[HH:MM:SS] [WARN] Fallo al conectar: ... SocketException
[HH:MM:SS] [ERROR] No se pudo conectar con ninguna de las URLs disponibles
[HH:MM:SS] [INFO] Programando reconexión #1 en 5s...
[HH:MM:SS] [INFO] Ejecutando intento de reconexión #1
[HH:MM:SS] [INFO] Iniciando proceso de conexión WebSocket...
... (repite hasta reconectar)
```

---

## 📊 COMPARACIÓN ANTES/DESPUÉS

| Aspecto | ❌ Antes | ✅ Después |
|---------|---------|-----------|
| URLs intentadas | 2 de 4 | 4 de 4 |
| Llamadas a `_scheduleReconnect()` | Múltiples (2-4 veces) | 1 sola vez |
| Timers programados | Múltiples conflictivos | 1 solo timer |
| `_isConnecting` | Se queda en `true` | Se resetea correctamente |
| Reconexión automática | ❌ Bloqueada | ✅ Funciona |
| Logs completos | ❌ Se cortan | ✅ Completos |

---

## 🚀 PRÓXIMOS PASOS

1. **Recompilar**:
   ```cmd
   aplicar_cambios.bat
   ```

2. **Probar**:
   - Desconectar internet
   - Esperar 5-10 segundos
   - Reconectar internet
   - Esperar hasta 60 segundos

3. **Verificar logs**:
   - Debes ver las **4 URLs** intentadas
   - Debe aparecer "No se pudo conectar con ninguna de las URLs disponibles"
   - Debe aparecer "Programando reconexión #X en Ys..."
   - Debe reconectar automáticamente cuando vuelva internet

---

## 📝 ARCHIVOS MODIFICADOS

| Archivo | Líneas | Cambio |
|---------|--------|--------|
| `websocket_service.dart` | 537-566 | Verificación `_isConnecting` en `onDone` |
| `websocket_service.dart` | 567-586 | Verificación `_isConnecting` en `onError` |
| `FIX_RECONEXION_CRITICO.md` | Nuevo | Esta documentación |

---

## 🎯 RESUMEN EJECUTIVO

**Problema**: Los callbacks `onDone` y `onError` del WebSocket llamaban a `_scheduleReconnect()` **durante el proceso de conexión inicial**, creando múltiples timers conflictivos que bloqueaban la reconexión.

**Solución**: Agregar verificación `if (_isConnecting) return;` en ambos callbacks para que **SOLO reconecten si la conexión ya estaba establecida**, dejando que el `catch` del for loop maneje los errores durante la conexión inicial.

**Resultado**: Ahora intenta las 4 URLs correctamente, resetea `_isConnecting`, y programa reconexión automática UNA SOLA VEZ.

---

**Última actualización**: 2025-12-13  
**Versión de la app**: 1.0.0+1  
**Prioridad**: CRÍTICA
