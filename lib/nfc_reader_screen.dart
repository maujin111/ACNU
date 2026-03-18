import 'package:flutter/material.dart';
import 'package:anfibius_uwu/services/nfc_service.dart';
import 'package:flutter/services.dart';

class NfcScreen extends StatelessWidget {
  const NfcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner NFC')),

      body: ListenableBuilder(
        listenable: nfc,
        builder: (context, child) {

          if (nfc.leido) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 120, color: Colors.green),
                  SizedBox(height: 24),
                  Text(
                    '¡Tarjeta Leída!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  SizedBox(height: 12),
                  Text('Datos enviados correctamente', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }


          if (nfc.leyendo) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nfc, size: 100, color: Colors.lightGreen),
                  SizedBox(height: 32),
                  Text(
                    'Acerca la tarjeta al lector...',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 32),
                  CircularProgressIndicator(color: Colors.lightGreen),
                ],
              ),
            );
          }

          return const Center(
            child: Text(
              'Escáner inactivo',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}