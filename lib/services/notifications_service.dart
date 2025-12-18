import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // 🆕 Callback para manejar clicks en notificaciones
  Function(String? payload)? onNotificationClick;

  // Inicializar el servicio de notificaciones
  Future<void> init() async {
    // Inicializar timezone
    tz_data.initializeTimeZones();

    // Configuración para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Configuración para macOS
    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Configuración para Linux
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
          defaultActionName: 'Open notification',
        );

    // Configuración general para todos los sistemas
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          macOS: initializationSettingsMacOS,
          linux: initializationSettingsLinux,
        );

    // Inicializar el plugin con la configuración
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permisos en iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Solicitar permisos en macOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Método para manejar el tap en la notificación
  void _onNotificationTap(NotificationResponse notificationResponse) {
    // Aquí puedes manejar la acción cuando el usuario toca la notificación
    debugPrint('Notificación tocada: ${notificationResponse.payload}');
    
    // 🆕 Llamar al callback si está definido
    if (onNotificationClick != null) {
      onNotificationClick!(notificationResponse.payload);
    }
  }

  // Método para mostrar una notificación simple en todos los sistemas
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Detalles de la notificación para Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'default_channel',
          'Notificaciones',
          channelDescription: 'Canal de notificaciones predeterminado',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    // Detalles de la notificación para iOS/macOS
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    // Detalles de la notificación para Linux
    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        );

    // Detalles generales para todos los sistemas
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
    );

    // Mostrar la notificación
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Método para programar una notificación
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Detalles de la notificación para Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'scheduled_channel',
          'Notificaciones Programadas',
          channelDescription: 'Canal para notificaciones programadas',
          importance: Importance.max,
          priority: Priority.high,
        );

    // Detalles de la notificación para iOS/macOS
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    // Detalles de la notificación para Linux
    const LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        );

    // Detalles generales para todos los sistemas
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
    );

    // Convertir DateTime a TZDateTime
    final tz.TZDateTime tzDateTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    // Programar la notificación
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Método para cancelar una notificación específica
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Método para cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
