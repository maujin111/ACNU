import 'package:flutter/material.dart';
import 'package:anfibius_uwu/services/notifications_service.dart';

class NotificationExample extends StatefulWidget {
  const NotificationExample({Key? key}) : super(key: key);

  @override
  State<NotificationExample> createState() => _NotificationExampleState();
}

class _NotificationExampleState extends State<NotificationExample> {
  final NotificationsService _notificationsService = NotificationsService();

  @override
  void initState() {
    super.initState();
    // Inicializar el servicio de notificaciones cuando se crea este widget
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationsService.init();
  }

  // Método para mostrar una notificación simple
  Future<void> _showNotification() async {
    await _notificationsService.showNotification(
      id: 1,
      title: 'Prueba de notificación',
      body: 'Esta es una notificación de prueba en Windows',
    );
  }

  // Método para programar una notificación para 5 segundos después
  Future<void> _scheduleNotification() async {
    final DateTime scheduledTime = DateTime.now().add(
      const Duration(seconds: 5),
    );
    await _notificationsService.scheduleNotification(
      id: 2,
      title: 'Notificación programada',
      body: 'Esta notificación fue programada para aparecer 5 segundos después',
      scheduledDate: scheduledTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ejemplo de Notificaciones')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _showNotification,
              child: const Text('Mostrar notificación inmediata'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _scheduleNotification,
              child: const Text('Programar notificación (5 segundos)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _notificationsService.cancelAllNotifications(),
              child: const Text('Cancelar todas las notificaciones'),
            ),
          ],
        ),
      ),
    );
  }
}
