# Casos donde NO se puede reconectar el WebSocket

## 1. Servicio Disposed ❌
**Ubicación:** Múltiples lugares en `websocket_service.dart`

### Descripción:
Cuando el servicio `WebSocketService` ha sido disposed (destruido), **NO** se puede reconectar.

### Dónde se verifica:
- `forceReconnect()` - línea 201-204
- `_connect()` - línea 282-285
- `_scheduleReconnect()` - línea 456-459
- Callbacks de timers en heartbeat y connection check

### Código:
```dart
if (_isDisposed) {
  print('❌ Servicio disposed, no se puede reconectar');
  return;
}
```

### Cuándo ocurre:
- Cuando se cierra la aplicación
- Cuando se navega fuera de la pantalla principal (si no se usa provider correctamente)
- Cuando se destruye el widget que contiene el servicio

### Solución:
**NO HAY SOLUCIÓN** - El servicio debe ser reinicializado creando una nueva instancia.

---

## 2. Token Vacío o Nulo ❌
**Ubicación:** `forceReconnect()` y `_connect()`

### Descripción:
Si no hay un token de autenticación, el WebSocket NO puede conectarse.

### Dónde se verifica:
- `forceReconnect()` - línea 206-209
- `_connect()` - línea 292-295

### Código:
```dart
if (_token == null || _token!.isEmpty) {
  print('❌ No hay token disponible para reconectar');
  return;
}
```

### Cuándo ocurre:
- Primera vez que se inicia la aplicación (sin token guardado)
- Si se borra manualmente el token de la configuración
- Si hay un error al cargar el token desde el almacenamiento

### Solución:
El usuario debe ingresar un token válido manualmente a través de la UI.

---

## 3. Reconexión Automática Deshabilitada ⚠️
**Ubicación:** `_scheduleReconnect()`

### Descripción:
Si `_shouldAutoReconnect` es `false`, el sistema NO intentará reconectar automáticamente.

### Dónde se verifica:
- `_scheduleReconnect()` - línea 450-453

### Código:
```dart
if (!_shouldAutoReconnect) {
  print('⚠️ Reconexión automática deshabilitada');
  return;
}
```

### Cuándo ocurre:
- Cuando el usuario hace clic en "Desconectar" manualmente
- Método `disconnect()` establece `_shouldAutoReconnect = false`

### Efecto:
- **Reconexión automática:** ❌ NO funciona
- **Reconexión manual:** ✅ SÍ funciona (botón "Reconectar")

### Código donde se deshabilita:
```dart
void disconnect() {
  _shouldAutoReconnect = false;  // línea 519
  // ...
}
```

### Solución:
El usuario puede:
1. Hacer clic en el botón "Reconectar" manualmente
2. Llamar a `forceReconnect()` que re-habilita `_shouldAutoReconnect`

---

## 4. ~~Windows en Segundo Plano/Suspensión~~ ✅ YA NO APLICA
**Ubicación:** N/A - **ESTE CASO FUE ELIMINADO**

### Descripción:
**🔥 CAMBIO IMPORTANTE:** En la versión anterior, la aplicación NO reconectaba durante suspensión en Windows para evitar crashes. **ESTO CAUSABA PÉRDIDA DE PEDIDOS.**

### ✅ NUEVA SOLUCIÓN:
La aplicación ahora **MANTIENE LA CONEXIÓN ACTIVA** durante suspensión en Windows con protecciones robustas contra crashes.

### Comportamiento Actual:
- **Durante suspensión:** ✅ Conexión ACTIVA, recibe mensajes, imprime automáticamente
- **Al despertar:** ✅ Verifica conexión, reconecta si es necesario
- **Timers:** ✅ Permanecen activos con protección try-catch

### Por qué se cambió:
El enfoque anterior de cancelar timers durante suspensión causaba que **NO se recibieran órdenes de impresión** enviadas mientras la laptop estaba en reposo. Esto es **CRÍTICO** en negocios donde los pedidos pueden llegar en cualquier momento.

### Protecciones implementadas:
- ✅ Try-catch en todos los callbacks de timers
- ✅ Verificación `_isDisposed` en cada operación
- ✅ Manejo robusto de errores en heartbeat
- ✅ Reconexión automática si se pierde conexión

### Resultado:
**✅ La aplicación funciona como un servicio 24/7** que nunca deja de escuchar órdenes de impresión.

---

## 5. Conexión Ya en Curso 🔄
**Ubicación:** `_connect()`

### Descripción:
Si ya hay una conexión en proceso, NO se iniciará otra conexión simultánea para evitar condiciones de carrera.

### Dónde se verifica:
- `_connect()` - línea 287-290

### Código:
```dart
if (_isConnecting) {
  print('⚠️ Ya hay una conexión en curso, abortando');
  return;
}
```

### Cuándo ocurre:
- Si el usuario hace clic en "Conectar" múltiples veces rápidamente
- Si se llama a `_connect()` desde múltiples lugares simultáneamente
- Durante el proceso de intentar conectar a las 4 URLs diferentes

### Efecto:
- **Nueva conexión:** ❌ NO se inicia
- **Conexión actual:** ✅ Continúa normalmente

### Solución:
Esperar a que la conexión actual termine (éxito o fallo).

**Excepción en `forceReconnect()`:**
Este método espera hasta 5 segundos si hay una conexión en curso:
```dart
if (_isConnecting) {
  // Esperar hasta 5 segundos
  int waitCount = 0;
  while (_isConnecting && waitCount < 10) {
    await Future.delayed(const Duration(milliseconds: 500));
    waitCount++;
  }
  
  if (_isConnecting) {
    _isConnecting = false; // Forzar reset después de timeout
  }
}
```

---

## 6. Todas las URLs Fallaron 🌐❌
**Ubicación:** `_connect()` - final del método

### Descripción:
Si ninguna de las 4 URLs de conexión funciona, NO se puede conectar.

### URLs que se intentan (en orden):
1. `wss://soporte.anfibius.net:3300/{token}` (HTTPS con puerto 3300)
2. `ws://soporte.anfibius.net:3300/{token}` (HTTP con puerto 3300)
3. `wss://soporte.anfibius.net/{token}` (HTTPS puerto por defecto)
4. `ws://soporte.anfibius.net/{token}` (HTTP puerto por defecto)

### Código (línea 425-431):
```dart
// Si llegamos aquí, ninguna URL funcionó
print('❌ No se pudo conectar con ninguna de las URLs disponibles');
_isConnected = false;
_isConnecting = false;
_safeNotifyListeners();
// Intentar reconectar después de un tiempo
_scheduleReconnect();
```

### Cuándo ocurre:
- **Sin internet:** No hay conexión a internet
- **DNS no resuelve:** No se puede resolver `soporte.anfibius.net`
- **Servidor caído:** El servidor WebSocket está apagado o inalcanzible
- **Firewall/Antivirus:** Bloqueando las conexiones WebSocket
- **Token inválido:** El servidor rechaza el token (connection refused)
- **Timeout:** Todas las conexiones exceden 10 segundos

### Errores posibles:
```dart
// Timeout
TimeoutException: 'Timeout al conectar con {url}'

// DNS
'Error de resolución DNS - Verifique la conexión a internet'

// Red inalcanzable  
'Red no accesible - Verifique la conexión a internet'

// Conexión rechazada
'Conexión rechazada - El servidor puede estar apagado'
```

### Efecto:
- **Conexión:** ❌ Falla
- **Reconexión automática:** ✅ Se programa para intentar de nuevo

### Solución:
El sistema intentará reconectar automáticamente usando backoff exponencial:
- Intento 1: 5 segundos
- Intento 2: 10 segundos
- Intento 3: 20 segundos
- Intento 4: 40 segundos
- Intento 5+: 60 segundos (indefinidamente)

---

## 7. Error Durante Conexión (Disposed) 🔥
**Ubicación:** Dentro del bucle de URLs en `_connect()`

### Descripción:
Si el servicio es disposed MIENTRAS se está intentando conectar, se aborta la conexión.

### Código (línea 321-325):
```dart
for (String urlString in urlsToTry) {
  if (_isDisposed) {
    print('⚠️ Servicio disposed durante conexión, abortando');
    _isConnecting = false;
    return;
  }
  // ...
}
```

### Cuándo ocurre:
- Si el usuario cierra la aplicación mientras está conectando
- Si se navega fuera de la pantalla durante la conexión
- Si se llama a `dispose()` mientras está en el bucle de URLs

### Solución:
**NO HAY SOLUCIÓN** - La conexión se aborta correctamente para evitar memory leaks.

---

## Resumen de Casos

| # | Caso | Reconexión Auto | Reconexión Manual | Solución |
|---|------|----------------|-------------------|----------|
| 1 | Servicio Disposed | ❌ | ❌ | Reiniciar app |
| 2 | Token vacío/nulo | ❌ | ❌ | Ingresar token |
| 3 | Auto-reconexión OFF | ❌ | ✅ | Botón "Reconectar" |
| 4 | ~~Windows suspendido~~ | ✅ **AHORA SÍ FUNCIONA** | ✅ | **Automático** |
| 5 | Conexión en curso | ⏸️ (espera) | ⏸️ (espera 5s) | Esperar |
| 6 | Todas URLs fallan | ✅ (reintenta) | ✅ | Verificar red/servidor |
| 7 | Disposed durante conexión | ❌ | ❌ | Reiniciar app |

---

## Diagnóstico Rápido

### ¿Por qué no se reconecta mi WebSocket?

**Paso 1:** Verificar logs
```
❌ Servicio disposed → Reiniciar aplicación
❌ No hay token → Ingresar token en configuración  
⚠️ Reconexión automática deshabilitada → Clic en "Reconectar"
⚠️ Ya hay conexión en curso → Esperar
❌ No se pudo conectar con ninguna URL → Verificar internet/servidor

✅ Windows en segundo plano → Ya NO es problema - funciona automáticamente
```

**Paso 2:** Verificar el estado en UI
- ¿Hay token configurado? → Si NO, ingresar token
- ¿Dice "Conectando..."? → Esperar o reintentar después de 10s

**Paso 3:** Intentar reconexión manual
- Hacer clic en botón "Reconectar"
- Si falla, verificar logs para ver el error específico

**Paso 4:** Verificar conectividad
```bash
# En Windows CMD/PowerShell
ping soporte.anfibius.net
nslookup soporte.anfibius.net
```

---

## Mejoras Sugeridas (Opcional)

Para mejorar la experiencia del usuario, podrías considerar:

1. **Mostrar estado en UI:**
   ```dart
   // Agregar getter para obtener razón de no conexión
   String? getConnectionBlockedReason() {
     if (_isDisposed) return 'Servicio no disponible';
     if (_token == null || _token!.isEmpty) return 'Token no configurado';
     if (!_shouldAutoReconnect) return 'Reconexión deshabilitada';
     if (_isConnecting) return 'Conexión en curso...';
     if (Platform.isWindows && _isInBackground) return 'En segundo plano';
     return null;
   }
   ```

2. **Notificación al usuario:**
   ```dart
   // En _scheduleReconnect(), notificar cuando se pospone
   if (Platform.isWindows && _isInBackground) {
     NotificationsService().showNotification(
       title: 'Reconexión pospuesta',
       body: 'Se reconectará al despertar la laptop',
     );
   }
   ```

3. **Auto-recuperación mejorada:**
   ```dart
   // En onAppResumed(), forzar reconexión si lleva mucho tiempo desconectado
   final disconnectedTime = DateTime.now().difference(_lastDisconnectedAt);
   if (disconnectedTime.inMinutes > 5) {
     forceReconnect();
   }
   ```
