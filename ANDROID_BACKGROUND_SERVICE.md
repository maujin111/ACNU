# Servicio en Segundo Plano para Android

## Problema Resuelto

La aplicación dejaba de imprimir después de ~10 minutos en segundo plano en Android porque el sistema mataba la conexión WebSocket para ahorrar batería.

## Solución Implementada

### 1. **Servicio en Primer Plano (Foreground Service)**
   - Mantiene la app activa con una notificación persistente
   - Archivo: `lib/services/foreground_service.dart`
   - Verifica la conexión cada 5 segundos
   - Envía heartbeat al UI cada 60 segundos
   - Verifica el WebSocket cada 5 minutos

### 2. **Wake Lock**
   - Evita que el dispositivo entre en suspensión profunda
   - Se activa automáticamente al conectar el WebSocket
   - Mantiene el procesador activo para las conexiones de red

### 3. **Keep-Alive Mejorado**
   - Ping cada 30 segundos en Android (15s en otras plataformas)
   - Incluye timestamp para mejor tracking
   - Reconexión automática si falla el ping

### 4. **Gestión del Ciclo de Vida**
   - Detecta cuando la app va a segundo plano (`onAppPaused`)
   - Detecta cuando la app vuelve a primer plano (`onAppResumed`)
   - Verifica y reconecta automáticamente si es necesario

### 5. **Permisos de Android**
   - `WAKE_LOCK`: Mantener procesador activo
   - `FOREGROUND_SERVICE`: Ejecutar servicio en primer plano
   - `FOREGROUND_SERVICE_DATA_SYNC`: Tipo de servicio de sincronización
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Excluir optimización de batería
   - `POST_NOTIFICATIONS`: Mostrar notificación del servicio
   - `RECEIVE_BOOT_COMPLETED`: Reiniciar servicio al arrancar

## Archivos Modificados

1. **pubspec.yaml**
   - Agregadas dependencias:
     - `flutter_foreground_task: ^8.0.0`
     - `wakelock_plus: ^1.2.0`
     - `permission_handler: ^11.3.1`

2. **android/app/src/main/AndroidManifest.xml**
   - Agregados permisos necesarios
   - Configurado el servicio en primer plano
   - Configurado receptor para reinicio automático

3. **lib/services/foreground_service.dart** (NUEVO)
   - Clase `PrinterForegroundService`: Gestiona el servicio
   - Clase `PrinterTaskHandler`: Maneja eventos del servicio

4. **lib/services/websocket_service.dart**
   - Agregado soporte para wake lock
   - Keep-alive mejorado con intervalos diferentes para Android
   - Métodos `onAppPaused()` y `onAppResumed()`
   - Ping con timestamp JSON en lugar de string simple

5. **lib/main.dart**
   - Inicialización del servicio de primer plano
   - Callback para recibir datos del servicio
   - Gestión del ciclo de vida de la app
   - Widget `WithForegroundTask` para Android

6. **lib/settings_screen.dart**
   - Botón para desactivar optimización de batería
   - Solo visible en Android

## Cómo Usar

### Primera vez en Android:

1. **Instalar la app**
   ```bash
   flutter build apk --release
   flutter install
   ```

2. **Configurar permisos** (Desde la app):
   - Ir a Configuración → Sistema
   - Presionar "Configurar" en "Desactivar optimización de batería"
   - Permitir cuando Android solicite el permiso

3. **Conectar al WebSocket**:
   - Ir a Configuración → Conexión
   - Ingresar el token
   - Presionar el botón de conectar

4. **Verificar el servicio**:
   - La notificación "Servicio de Impresión Activo" debería aparecer
   - La app ahora mantendrá la conexión incluso en segundo plano

### Monitoreo:

La notificación del servicio muestra:
- "Servicio de Impresión Activo" cuando todo está funcionando
- Última verificación con timestamp
- Se actualiza cada minuto

En los logs verás:
- `💓 Heartbeat` cada 60 segundos del servicio
- `📡 Keep-alive ping enviado` cada 30 segundos del WebSocket
- `✅ Servicio activo` cada 5 minutos

## Solución de Problemas

### La app sigue sin imprimir después de 10 minutos:

1. **Verificar optimización de batería**:
   - Configuración de Android → Batería → Optimización de batería
   - Buscar "Anfibius web utility"
   - Cambiar a "No optimizar"

2. **Verificar el servicio**:
   ```dart
   final isRunning = await PrinterForegroundService.isRunning();
   print('Servicio activo: $isRunning');
   ```

3. **Verificar logs**:
   ```bash
   flutter logs | grep -E "Heartbeat|Keep-alive|WebSocket"
   ```

4. **Reiniciar el servicio**:
   - Cerrar completamente la app
   - Abrir de nuevo
   - El servicio se iniciará automáticamente

### El servicio se detiene al reiniciar el teléfono:

- El servicio debería reiniciarse automáticamente gracias a `RECEIVE_BOOT_COMPLETED`
- Si no funciona, abre la app una vez después de reiniciar

### Batería se agota rápido:

- Es normal un consumo ligeramente mayor debido a:
  - Wake lock activo
  - Servicio en primer plano
  - Conexión WebSocket permanente
  - Pings cada 30 segundos

- Para reducir consumo:
  - Aumentar intervalo de keep-alive (en `websocket_service.dart`)
  - Reducir frecuencia de verificación del servicio (en `foreground_service.dart`)

## Notas Técnicas

### Por qué funciona:

1. **Servicio en Primer Plano**: Android no mata servicios de primer plano con notificación visible
2. **Wake Lock**: Mantiene el procesador activo para procesar mensajes del WebSocket
3. **Keep-Alive**: Evita que el servidor cierre la conexión por inactividad
4. **Reconexión Automática**: Si algo falla, intenta reconectar con backoff exponencial

### Limitaciones:

- **Batería**: Consumo aumentado (necesario para mantener conexión)
- **Notificación**: Debe mostrar notificación persistente (requisito de Android)
- **Optimización**: Si el usuario fuerza optimización, puede fallar

### Alternativas consideradas:

- ❌ **WorkManager**: No garantiza ejecución inmediata
- ❌ **AlarmManager**: Solo para tareas programadas
- ❌ **JobScheduler**: Puede demorar hasta 15 minutos
- ✅ **Foreground Service**: Mejor opción para conexión permanente

## Referencias

- [Flutter Foreground Task](https://pub.dev/packages/flutter_foreground_task)
- [Wakelock Plus](https://pub.dev/packages/wakelock_plus)
- [Permission Handler](https://pub.dev/packages/permission_handler)
- [Android Foreground Services](https://developer.android.com/develop/background-work/services/foreground-services)
