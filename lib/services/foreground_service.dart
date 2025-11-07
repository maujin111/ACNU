import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class PrinterForegroundService {
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'printer_service_channel',
        channelName: 'Servicio de Impresión',
        channelDescription:
            'Mantiene la conexión con impresoras y WebSocket activa',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          5000,
        ), // Check cada 5 segundos
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<ServiceRequestResult> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 500,
        notificationTitle: 'Servicio de Impresión Activo',
        notificationText: 'Escuchando órdenes de impresión...',
        callback: startCallback,
      );
    }
  }

  static Future<ServiceRequestResult> stopService() async {
    return FlutterForegroundTask.stopService();
  }

  static Future<void> updateNotification({String? title, String? text}) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title ?? 'Servicio de Impresión Activo',
      notificationText: text ?? 'Escuchando órdenes de impresión...',
    );
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PrinterTaskHandler());
}

class PrinterTaskHandler extends TaskHandler {
  int _eventCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 Foreground service iniciado - ${timestamp.toIso8601String()}');
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    _eventCount++;

    // Enviar heartbeat cada minuto para notificar que el servicio sigue activo
    if (_eventCount % 12 == 0) {
      // Cada 60 segundos (5s * 12)
      final now = DateTime.now();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Servicio de Impresión Activo',
        notificationText:
            'Última verificación: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      );

      // Enviar señal al UI principal
      FlutterForegroundTask.sendDataToMain({
        'type': 'heartbeat',
        'timestamp': now.toIso8601String(),
        'eventCount': _eventCount,
      });

      print(
        '💓 Heartbeat #$_eventCount - ${now.hour}:${now.minute}:${now.second}',
      );
    }

    // Verificar cada 5 minutos que todo está funcionando
    if (_eventCount % 60 == 0) {
      // Cada 5 minutos (5s * 60)
      print('✅ Servicio activo - $_eventCount checks completados');
      FlutterForegroundTask.sendDataToMain({
        'type': 'check_websocket',
        'timestamp': timestamp.toIso8601String(),
      });
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🛑 Foreground service detenido - ${timestamp.toIso8601String()}');
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔘 Botón de notificación presionado: $id');
    if (id == 'btn_open') {
      FlutterForegroundTask.launchApp('/');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    print('📱 Notificación presionada - Abriendo app');
  }

  @override
  void onNotificationDismissed() {
    print('🔕 Notificación descartada (pero el servicio sigue activo)');
  }
}
