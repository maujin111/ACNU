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
        ); // Configuración para Windows
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'Anfibius Connect Nexus Utility',
          iconPath:
              'assets/icon/app_icon.ico', // Ruta al icono de la aplicación
          appUserModelId: 'com.example.anfibius_uwu',
          guid: 'fd34f92d-c18e-4ee0-8a44-a6a7c1f0f1a8',
        );

    // Configuración general para todos los sistemas
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          macOS: initializationSettingsMacOS,
          linux: initializationSettingsLinux,
          windows: initializationSettingsWindows,
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
    // por ejemplo, navegar a una pantalla específica
    debugPrint('Notificación tocada: ${notificationResponse.payload}');
  }

  // Método para mostrar una notificación simple en todos los sistemas
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Detalles de la notificación para Android
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
          'default_channel',
          'Notificaciones',
          channelDescription: 'Canal de notificaciones predeterminado',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    // Detalles de la notificación para iOS/macOS
    DarwinNotificationDetails darwinPlatformChannelSpecifics =
        const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ); // Detalles de la notificación para Linux
    LinuxNotificationDetails linuxPlatformChannelSpecifics =
        const LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        );

    // Detalles de la notificación para Windows
    WindowsNotificationDetails windowsPlatformChannelSpecifics =
        const WindowsNotificationDetails();

    // Detalles generales para todos los sistemas
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
      windows: windowsPlatformChannelSpecifics,
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
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
          'scheduled_channel',
          'Notificaciones Programadas',
          channelDescription: 'Canal para notificaciones programadas',
          importance: Importance.max,
          priority: Priority.high,
        );

    // Detalles de la notificación para iOS/macOS
    DarwinNotificationDetails darwinPlatformChannelSpecifics =
        const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ); // Detalles de la notificación para Linux
    LinuxNotificationDetails linuxPlatformChannelSpecifics =
        const LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        );

    // Detalles de la notificación para Windows
    WindowsNotificationDetails windowsPlatformChannelSpecifics =
        const WindowsNotificationDetails();

    // Detalles generales para todos los sistemas
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
      windows: windowsPlatformChannelSpecifics,
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
