import 'package:anfibius_uwu/configuraciones.dart';
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Assuming this widget exists
// Assuming this widget exists

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Configurar listener para marcaciones de asistencia
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fingerprintService = Provider.of<FingerprintReaderService>(
        context,
        listen: false,
      );

      fingerprintService.onAttendanceMarked = (response) {
        if (mounted) {
          _showAttendanceNotification(response);
        }
      };
    });
  }

  void _showAttendanceNotification(Map<String, dynamic> response) {
    final empleado = '${response['nombres']} ${response['apellidos']}';
    final fecha = response['fecha_marcacion'];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Marcación exitosa',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$empleado'),
                  Text('$fecha', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACNU')),
      body: const Dispositivos(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Configuraciones()),
              );
            },
            heroTag: 'general_settings',
            tooltip: 'Configuración',
            child: const Icon(Icons.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
