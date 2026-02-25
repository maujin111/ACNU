# Logging Mejorado - WebSocket Service

## Fecha: 2025-12-13

---

## 🎯 PROBLEMA IDENTIFICADO

**Situación**: Usuario reporta que la app NO se reconecta después de perder internet.

**Análisis de logs** (`anfibius_log_2025-12-13.txt`):
```
[08:07:00.065] [INFO] ℹ️ Reconexión manual solicitada
[08:07:00.065] [DEBUG] 🐛 Estado actual: disposed=false, connected=false, connecting=true, autoReconnect=true, suspending=false, hasToken=true
[08:07:00.065] [SUCCESS] ✅ AutoReconnect habilitado
[08:07:00.065] [INFO] ℹ️ Limpiando conexión existente antes de reconectar...
[08:07:00.065] [INFO] ℹ️ EMERGENCY CLEANUP - Limpiando recursos zombies...
[08:07:00.065] [SUCCESS] ✅ Emergency cleanup completado
[08:07:01.068] [INFO] ℹ️ Iniciando reconexión después de cleanup...
[LOG SE CORTA AQUÍ - NO HAY MÁS INFORMACIÓN]
```

**Causa raíz**: 
- El método `_connect()` usa SOLO `print()` en lugar de `logger`
- El método `_scheduleReconnect()` usa SOLO `print()` en lugar de `logger`
- El método `_handleWebSocketError()` usa SOLO `print()` en lugar de `logger`
- Los logs NO se guardaban en archivo, por lo que NO sabemos qué pasó después

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **1. Logging agregado a `_connect()` (línea 429)**

**Cambios**:
```dart
// ❌ ANTES
print('⚠️ [${DateTime.now()}] Servicio disposed, abortando conexión');
print('⚠️ [${DateTime.now()}] Ya hay una conexión en curso, abortando');
print('Intentando conectar a: $urlString');
print('✅ Conectado exitosamente a: $urlString');

// ✅ DESPUÉS
logger.warning('Servicio disposed, abortando conexión');
logger.warning('Ya hay una conexión en curso, abortando');
logger.info('Iniciando proceso de conexión WebSocket...');
logger.info('Intentando conectar a: $urlString');
logger.success('Conectado exitosamente a: $urlString');
logger.warning('Fallo al conectar: $errorMessage');
logger.error('No se pudo conectar con ninguna de las URLs disponibles');
logger.error('Error crítico en _connect', error: e, stackTrace: stackTrace);
```

**Puntos críticos agregados**:
- ✅ Inicio del proceso de conexión
- ✅ Intento de cada URL
- ✅ Éxito/Fallo de conexión
- ✅ Errores con stack trace completo

---

### **2. Logging agregado a `_scheduleReconnect()` (línea 612)**

**Cambios**:
```dart
// ❌ ANTES
print('⚠️ [${DateTime.now()}] Reconexión automática deshabilitada');
print('🔄 [${DateTime.now()}] Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...');
print('🔄 [${DateTime.now()}] Intentando reconectar al WebSocket (intento #$_reconnectAttempts)...');

// ✅ DESPUÉS
logger.warning('Reconexión automática deshabilitada');
logger.warning('Servicio disposed, no se programará reconexión');
logger.info('Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...');
logger.info('Ejecutando intento de reconexión #$_reconnectAttempts');
logger.success('Ya conectado, cancelando reconexión');
```

**Puntos críticos agregados**:
- ✅ Verificación de condiciones previas
- ✅ Programación de reconexión con delay
- ✅ Ejecución del intento
- ✅ Estado de conexión actual

---

### **3. Logging agregado a `_handleWebSocketError()` (línea 1024)**

**Cambios**:
```dart
// ❌ ANTES
print('🔥 Error de WebSocket: $errorMessage');

// ✅ DESPUÉS
logger.error('Error de WebSocket: $errorMessage', error: error);
print('🔥 Error de WebSocket: $errorMessage');
```

**Puntos críticos agregados**:
- ✅ Errores con objeto de error completo
- ✅ Mensaje detallado del error

---

## 📋 FLUJO DE RECONEXIÓN COMPLETO (CON LOGS)

### **Escenario: Usuario desconecta internet**

1. **Detección de desconexión**:
```
[HH:MM:SS] [INFO] ℹ️ WebSocket desconectado (onDone)
[HH:MM:SS] [INFO] ℹ️ Programando reconexión #1 en 5s...
```

2. **Primer intento de reconexión**:
```
[HH:MM:SS] [INFO] ℹ️ Ejecutando intento de reconexión #1
[HH:MM:SS] [INFO] ℹ️ Iniciando proceso de conexión WebSocket...
[HH:MM:SS] [INFO] ℹ️ Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
[HH:MM:SS] [WARN] ⚠️ Fallo al conectar: Error de socket de red...
[HH:MM:SS] [INFO] ℹ️ Intentando conectar a: ws://soporte.anfibius.net:3300/TOKEN
[HH:MM:SS] [WARN] ⚠️ Fallo al conectar: Error de socket de red...
[HH:MM:SS] [ERROR] ❌ No se pudo conectar con ninguna de las URLs disponibles
[HH:MM:SS] [INFO] ℹ️ Programando reconexión #2 en 10s...
```

3. **Segundo intento** (después de 10s):
```
[HH:MM:SS] [INFO] ℹ️ Ejecutando intento de reconexión #2
[HH:MM:SS] [INFO] ℹ️ Iniciando proceso de conexión WebSocket...
... (repite el proceso)
[HH:MM:SS] [INFO] ℹ️ Programando reconexión #3 en 20s...
```

4. **Usuario reconecta internet**:
```
[HH:MM:SS] [INFO] ℹ️ Ejecutando intento de reconexión #5
[HH:MM:SS] [INFO] ℹ️ Iniciando proceso de conexión WebSocket...
[HH:MM:SS] [INFO] ℹ️ Intentando conectar a: wss://soporte.anfibius.net:3300/TOKEN
[HH:MM:SS] [SUCCESS] ✅ Conectado exitosamente a: wss://soporte.anfibius.net:3300/TOKEN
```

---

## 🔧 DIAGNÓSTICO CON NUEVOS LOGS

Ahora puedes diagnosticar exactamente qué está pasando:

### **Revisar logs**:
```
Documents/anfibius_logs/anfibius_log_2025-12-13.txt
```

### **Buscar patrones**:
1. ✅ ¿Se programa la reconexión?
   - Buscar: `"Programando reconexión"`
   
2. ✅ ¿Se ejecuta el intento?
   - Buscar: `"Ejecutando intento de reconexión"`
   
3. ✅ ¿Qué URLs se intentan?
   - Buscar: `"Intentando conectar a:"`
   
4. ✅ ¿Qué errores ocurren?
   - Buscar: `"Fallo al conectar:"` o `"Error de WebSocket:"`
   
5. ✅ ¿Se completa la conexión?
   - Buscar: `"Conectado exitosamente"`

---

## 🚀 PRÓXIMOS PASOS

1. **Recompilar la app**:
   ```cmd
   aplicar_cambios.bat
   ```

2. **Probar escenario de desconexión**:
   - Iniciar app
   - Desconectar internet
   - Esperar 5-10 segundos
   - Reconectar internet
   - Esperar hasta 60 segundos

3. **Revisar logs**:
   - Presionar botón 📄 en la app
   - Ver log del día actual
   - Copiar y enviar logs si hay problemas

---

## 📊 LOGS ESPERADOS

### **Conexión exitosa después de pérdida de internet**:
```
[08:00:00] [INFO] ℹ️ Programando reconexión #1 en 5s...
[08:00:05] [INFO] ℹ️ Ejecutando intento de reconexión #1
[08:00:05] [INFO] ℹ️ Iniciando proceso de conexión WebSocket...
[08:00:05] [ERROR] ❌ No se pudo conectar con ninguna de las URLs disponibles
[08:00:05] [INFO] ℹ️ Programando reconexión #2 en 10s...
[08:00:15] [INFO] ℹ️ Ejecutando intento de reconexión #2
[08:00:15] [SUCCESS] ✅ Conectado exitosamente a: wss://soporte.anfibius.net:3300/TOKEN
```

### **Error persistente** (seguir intentando):
```
[08:00:00] [INFO] ℹ️ Programando reconexión #1 en 5s...
[08:00:05] [ERROR] ❌ No se pudo conectar...
[08:00:05] [INFO] ℹ️ Programando reconexión #2 en 10s...
[08:00:15] [ERROR] ❌ No se pudo conectar...
[08:00:15] [INFO] ℹ️ Programando reconexión #3 en 20s...
[08:00:35] [ERROR] ❌ No se pudo conectar...
[08:00:35] [INFO] ℹ️ Programando reconexión #4 en 40s...
[08:01:15] [ERROR] ❌ No se pudo conectar...
[08:01:15] [INFO] ℹ️ Programando reconexión #5 en 60s...
[08:02:15] [ERROR] ❌ No se pudo conectar...
[08:02:15] [INFO] ℹ️ Programando reconexión #6 en 60s...
... (continúa indefinidamente cada 60s)
```

---

## ⚙️ CONFIGURACIÓN DE BACKOFF

Reconexión usa backoff exponencial:

| Intento | Delay  | Total acumulado |
|---------|--------|-----------------|
| 1       | 5s     | 5s              |
| 2       | 10s    | 15s             |
| 3       | 20s    | 35s             |
| 4       | 40s    | 75s             |
| 5+      | 60s    | Indefinido      |

**Máximo delay**: 60 segundos  
**Intentos**: Indefinidos (hasta reconectar o cerrar app)

---

## 📝 ARCHIVOS MODIFICADOS

| Archivo | Líneas modificadas | Cambio |
|---------|-------------------|--------|
| `websocket_service.dart` | 429-609 | Logging en `_connect()` |
| `websocket_service.dart` | 612-672 | Logging en `_scheduleReconnect()` |
| `websocket_service.dart` | 1024-1035 | Logging en `_handleWebSocketError()` |

---

## 🔍 TROUBLESHOOTING

### **Si la app NO reconecta**:

1. **Revisar logs**:
   - ¿Aparece "Programando reconexión"?
   - ¿Aparece "Ejecutando intento de reconexión"?

2. **Si NO aparece "Programando reconexión"**:
   - Verificar `_shouldAutoReconnect = true`
   - Verificar que NO esté disposed

3. **Si aparece pero NO se ejecuta**:
   - Verificar timers
   - Verificar estado `_isConnecting`

4. **Si se ejecuta pero falla siempre**:
   - Revisar mensajes de error específicos
   - Verificar conectividad a `soporte.anfibius.net:3300`

---

**Última actualización**: 2025-12-13  
**Versión de la app**: 1.0.0+1
