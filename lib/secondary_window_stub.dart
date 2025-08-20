// Stub para secondary_window en plataformas no compatibles
import 'package:flutter/material.dart';

class SecondaryWindowApp extends StatelessWidget {
  final int windowId;
  final String argument;
  final dynamic windowController;

  const SecondaryWindowApp({
    super.key,
    required this.windowId,
    required this.argument,
    required this.windowController,
  });

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Ventanas secundarias no disponibles en esta plataforma'),
        ),
      ),
    );
  }
}
