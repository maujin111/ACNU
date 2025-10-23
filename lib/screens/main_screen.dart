import 'package:anfibius_uwu/configuraciones.dart';
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:flutter/material.dart';
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
