import 'package:anfibius_uwu/printers.dart';
import 'package:anfibius_uwu/settings_screen.dart';
import 'package:flutter/material.dart';

class Configuraciones extends StatefulWidget {
  const Configuraciones({super.key});

  @override
  State<Configuraciones> createState() => _ConfiguracionesState();
}

class _ConfiguracionesState extends State<Configuraciones> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        surfaceTintColor: Colors.lightGreen,
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      // First tab content
                      GeneralSettingsScreen(),
                      PrinterConfig(),
                      // Second tab content
                    ],
                  ),
                ),
                TabBar(
                  tabs: const [
                    Tab(icon: Icon(Icons.settings), text: 'General'),
                    Tab(icon: Icon(Icons.print), text: 'Impresoras'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
