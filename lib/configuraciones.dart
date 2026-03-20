import 'package:anfibius_uwu/screens/SessionSettingsForm.dart';
import 'package:anfibius_uwu/screens/nomina.dart';

import 'lector_huella.dart';
import 'package:anfibius_uwu/printers.dart';
import 'package:anfibius_uwu/settings_screen.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class Configuraciones extends StatefulWidget {
  const Configuraciones({super.key});

  @override
  State<Configuraciones> createState() => _ConfiguracionesState();
}

class _ConfiguracionesState extends State<Configuraciones> {
  final bool isWindows = Platform.isWindows;
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
        child: SizedBox(
          width: double.infinity,
          child: DefaultTabController(
            length: isWindows ? 5 : 2,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      // First tab content
                      GeneralSettingsScreen(),
                      PrinterConfig(),
                      if(isWindows) const LectorHuella(),
                      if(isWindows) const Nomina(),
                      if(isWindows) const SessionSettingsForm(),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    const Tab(icon: Icon(Icons.settings), text: 'General'),
                    const Tab(icon: Icon(Icons.print), text: 'Impresoras'),
                    if(isWindows) const Tab(icon: Icon(Icons.fingerprint), text: 'Lectores'),
                    if(isWindows) const Tab(icon: Icon(Icons.paid), text: 'Nomina'),
                    if(isWindows) const Tab(icon: Icon(Icons.person), text: 'Sesión'),
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
