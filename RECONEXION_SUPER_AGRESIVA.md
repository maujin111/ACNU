# RECONEXIÓN SUPER AGRESIVA - SIEMPRE CONECTADO

## Fecha: 2025-12-13 (Tercera y FINAL corrección)

---

## 🎯 OBJETIVO

**ASEGURAR QUE LA APP SIEMPRE SE RECONECTE AUTOMÁTICAMENTE**

La app debe:
- ✅ Reconectarse inmediatamente cuando vuelve el internet
- ✅ Intentar reconectar constantemente sin detenerse
- ✅ Usar delays cortos para reconectar rápido
- ✅ Loguear TODO el proceso para debugging

---

## 🔴 PROBLEMAS CORREGIDOS (SESIÓN 3)

### **1. Delays de reconexión muy largos**
- ❌ ANTES: 5s, 10s, 20s, 40s, 60s (muy lento)
- ✅ AHORA: 1s, 2s, 3s, 5s, 10s, 15s (máximo)

### **2. onDone no verificaba flags**
- ❌ ANTES: Llamaba `_scheduleReconnect()` sin verificar `_shouldAutoReconnect`
- ✅ AHORA: Verifica flags y loguea por qué no reconecta

### **3. Falta de logging en puntos críticos**
- ❌ ANTES: No se sabía por qué no reconectaba
- ✅ AHORA: Logs completos en cada paso

### **4. No se resetea contador en conexión exitosa**
- ❌ ANTES: Solo reseteaba `_reconnectAttempts`
- ✅ AHORA: Resetea contador + timestamp + loguea éxito

---

## ✅ CAMBIOS IMPLEMENTADOS

### **CAMBIO 1: Reconexión SUPER agresiva**

**Archivo**: `websocket_service.dart` línea 671-691

```dart
// ❌ ANTES (lento)
int delaySeconds = (5 * (1 << (_reconnectAttempts - 1))).clamp(5, 60);
// Delays: 5s, 10s, 20s, 40s, 60s, 60s, 60s...

// ✅ AHORA (super rápido)
int delaySeconds;
if (_reconnectAttempts == 1) delaySeconds = 1;       // Casi inmediato
else if (_reconnectAttempts == 2) delaySeconds = 2;
else if (_reconnectAttempts == 3) delaySeconds = 3;
else if (_reconnectAttempts == 4) delaySeconds = 5;
else if (_reconnectAttempts == 5) delaySeconds = 10;
else delaySeconds = 15;                               // Máximo 15s
// Delays: 1s, 2s, 3s, 5s, 10s, 15s, 15s, 15s...
```

**Resultado**: Primera reconexión en 1 segundo, luego cada 15 segundos máximo.

---

### **CAMBIO 2: onDone verifica flags antes de reconectar**

**Archivo**: `websocket_service.dart` línea 570-576

```dart
// ❌ ANTES
_safeNotifyListeners();
_scheduleReconnect();  // Siempre llamaba

// ✅ AHORA
_safeNotifyListeners();

if (_shouldAutoReconnect && !_isSystemSuspending) {
  logger.info('onDone: Iniciando reconexión automática...');
  _scheduleReconnect();
} else {
  logger.warning('onDone: Reconexión no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending');
}
```

**Resultado**: Sabemos exactamente por qué no reconecta si falla.

---

### **CAMBIO 3: Logging mejorado después del for loop**

**Archivo**: `websocket_service.dart` línea 605-619

```dart
// ❌ ANTES
logger.error('No se pudo conectar con ninguna de las URLs disponibles');
_scheduleReconnect();

// ✅ AHORA
logger.error('No se pudo conectar con ninguna de las URLs disponibles');
logger.info('Intentos realizados en todas las 4 URLs');

if (_shouldAutoReconnect && !_isSystemSuspending) {
  logger.info('Iniciando ciclo de reconexión automática...');
  _scheduleReconnect();
} else {
  logger.warning('Reconexión automática no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending');
}
```

**Resultado**: Logs completos de por qué reconecta o no.

---

### **CAMBIO 4: Logging mejorado en conexión exitosa**

**Archivo**: `websocket_service.dart` línea 587-596

```dart
// ❌ ANTES
logger.success('Conectado exitosamente a: $urlString');

// ✅ AHORA
logger.success('✅ CONEXIÓN EXITOSA a: $urlString');
logger.info('Contador de intentos reseteado a 0');
```

**Resultado**: Confirmación visual clara de éxito.

---

### **CAMBIO 5: onError durante conexión inicial no reconecta**

**Archivo**: `websocket_service.dart` línea 583-600

```dart
onError: (error) {
  if (_isDisposed) return;
  
  // 🔥 NO reconectar si aún estamos en proceso de conexión inicial
  if (_isConnecting) {
    print('⚠️ onError durante conexión inicial, no reconectar aún');
    logger.warning('onError durante conexión inicial, se maneja en catch del loop');
    return;  // Dejar que el catch del for loop lo maneje
  }
  
  print('Error de WebSocket: $error');
  logger.error('Error de WebSocket después de conexión establecida', error: error);
  _handleWebSocketError(error, urlString);
},
```

**Resultado**: Evita múltiples llamadas a `_scheduleReconnect()` durante el proceso inicial.

---

## 📊 TABLA DE DELAYS DE RECONEXIÓN

| Intento | Delay | Tiempo acumulado |
|---------|-------|------------------|
| 1       | 1s    | 1s               |
| 2       | 2s    | 3s               |
| 3       | 3s    | 6s               |
| 4       | 5s    | 11s              |
| 5       | 10s   | 21s              |
| 6+      | 15s   | 36s, 51s, 66s... |

**Conclusión**: Si el usuario reconecta internet, la app intentará reconectarse en un **máximo de 15 segundos**.

---

## 🔍 FLUJO COMPLETO DE RECONEXIÓN

### **Escenario: Usuario desconecta y reconecta internet**

1. **Usuario desconecta internet** (t=0s):
```
[00:00] [INFO] WebSocket desconectado (onDone)
[00:00] [INFO] onDone: Iniciando reconexión automática...
[00:00] [INFO] Programando reconexión #1 en 1s...
```

2. **Primer intento** (t=1s):
```
[00:01] [INFO] Ejecutando intento de reconexión #1
[00:01] [INFO] Iniciando proceso de conexión WebSocket...
[00:01] [INFO] Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
[00:01] [WARN] onError durante conexión inicial, se maneja en catch del loop
[00:01] [WARN] Fallo al conectar: SocketException...
[00:01] [INFO] Intentando conectar a: ws://soporte.anfibius.net:3300/TOKEN
[00:01] [WARN] onError durante conexión inicial, se maneja en catch del loop
[00:01] [WARN] Fallo al conectar: SocketException...
[00:01] [INFO] Intentando conectar a: wss://soporte.anfibius.net/TOKEN
[00:01] [WARN] onError durante conexión inicial, se maneja en catch del loop
[00:01] [WARN] Fallo al conectar: SocketException...
[00:01] [INFO] Intentando conectar a: ws://soporte.anfibius.net/TOKEN
[00:01] [WARN] onError durante conexión inicial, se maneja en catch del loop
[00:01] [WARN] Fallo al conectar: SocketException...
[00:01] [ERROR] No se pudo conectar con ninguna de las URLs disponibles
[00:01] [INFO] Intentos realizados en todas las 4 URLs
[00:01] [INFO] Iniciando ciclo de reconexión automática...
[00:01] [INFO] Programando reconexión #2 en 2s...
```

3. **Segundo intento** (t=3s):
```
[00:03] [INFO] Ejecutando intento de reconexión #2
[00:03] [INFO] Iniciando proceso de conexión WebSocket...
... (repite el proceso)
[00:03] [INFO] Programando reconexión #3 en 3s...
```

4. **Intentos 3, 4, 5** (t=6s, 11s, 21s):
```
... (continúa intentando)
[00:21] [INFO] Programando reconexión #6 en 15s...
```

5. **Usuario reconecta internet** (t=25s):
   - La app está esperando el timer de 15s
   - Timer se dispara en t=36s

6. **Reconexión exitosa** (t=36s):
```
[00:36] [INFO] Ejecutando intento de reconexión #6
[00:36] [INFO] Iniciando proceso de conexión WebSocket...
[00:36] [INFO] Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
[00:36] [SUCCESS] ✅ CONEXIÓN EXITOSA a: wss://soporte.anfibius.net:3300/TOKEN
[00:36] [INFO] Contador de intentos reseteado a 0
```

**Tiempo total**: Máximo 15 segundos después de reconectar internet.

---

## 🚀 INSTRUCCIONES DE PRUEBA

### **1. Recompilar la app**:
```cmd
cd C:\ruta\a\tu\proyecto
flutter clean
flutter pub get
flutter build windows --release
```

### **2. Ejecutar la app**:
- Abrir la app compilada
- Verificar que se conecta exitosamente
- Ver logs (botón 📄)

### **3. Probar desconexión/reconexión**:
1. **Desconectar internet** (desactivar WiFi o desconectar cable)
2. **Esperar 5 segundos**
3. Ver en logs:
   ```
   [INFO] WebSocket desconectado (onDone)
   [INFO] Programando reconexión #1 en 1s...
   ```
4. **Reconectar internet**
5. **Esperar máximo 15 segundos**
6. Ver en logs:
   ```
   [SUCCESS] ✅ CONEXIÓN EXITOSA a: wss://...
   ```

### **4. Verificar logs completos**:
- Presionar botón 📄 en la app
- Ver archivo del día actual
- Buscar:
  - ✅ "Programando reconexión"
  - ✅ "Ejecutando intento de reconexión"
  - ✅ "Intentando conectar a:"
  - ✅ "CONEXIÓN EXITOSA"

---

## 📋 ARCHIVOS MODIFICADOS

| Archivo | Líneas | Cambio |
|---------|--------|--------|
| `websocket_service.dart` | 671-691 | Delays super agresivos (1s-15s) |
| `websocket_service.dart` | 570-578 | onDone verifica flags |
| `websocket_service.dart` | 605-619 | Logging mejorado después del for loop |
| `websocket_service.dart` | 587-596 | Logging mejorado en conexión exitosa |
| `websocket_service.dart` | 583-600 | onError durante conexión inicial |
| `RECONEXION_SUPER_AGRESIVA.md` | Nuevo | Esta documentación |

---

## 🔧 TROUBLESHOOTING

### **Si la app NO reconecta después de 15 segundos**:

1. **Revisar logs** (botón 📄):
   - ¿Aparece "Programando reconexión"? 
     - ❌ NO → Verificar `_shouldAutoReconnect` y `_isSystemSuspending`
     - ✅ SÍ → Continuar

   - ¿Aparece "Ejecutando intento de reconexión"?
     - ❌ NO → Timer no se está disparando (verificar dispose)
     - ✅ SÍ → Continuar

   - ¿Aparece "Intentando conectar a:" para las 4 URLs?
     - ❌ NO → Loop se interrumpe (verificar `_isConnecting`)
     - ✅ SÍ → Continuar

   - ¿Todas las URLs fallan con mismo error?
     - ✅ SocketException → Internet aún no está disponible
     - ✅ Timeout → Servidor no responde
     - ❌ Otro error → Investigar error específico

2. **Verificar flags**:
   - En logs, buscar: "Estado actual: disposed=X, connected=X, connecting=X, autoReconnect=X"
   - `_shouldAutoReconnect` debe ser `true`
   - `_isSystemSuspending` debe ser `false`

3. **Verificar servidor**:
   - Hacer ping a `soporte.anfibius.net`
   - Verificar puerto 3300 abierto
   - Verificar que el token sea válido

---

## ✅ RESUMEN EJECUTIVO

### **Cambios clave**:
1. ✅ **Reconexión en 1 segundo** (primer intento)
2. ✅ **Máximo 15 segundos** entre intentos
3. ✅ **Logging completo** de todo el flujo
4. ✅ **Verificación de flags** antes de reconectar
5. ✅ **No reconecta durante conexión inicial** (evita duplicados)

### **Resultado**:
- La app **SIEMPRE intenta reconectar** cuando pierde conexión
- Reconexión **MUY RÁPIDA** (1s, 2s, 3s, 5s, 10s, 15s)
- **Logs completos** para debugging
- **Sin timers duplicados** gracias a verificación en onError

### **Garantía**:
Si el servidor está disponible y el internet funciona, la app se reconectará en **máximo 15 segundos**.

---

**Última actualización**: 2025-12-13  
**Versión de la app**: 1.0.0+1  
**Prioridad**: CRÍTICA ⚠️  
**Estado**: LISTO PARA PROBAR ✅
