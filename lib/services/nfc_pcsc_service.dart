import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Card; 
import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';

class NfcPcscService extends ChangeNotifier {
  bool _isReading = false;
  
  bool get isReading => _isReading;

  Future<void> startNFC(WebSocketService webSocketService) async {

    if (_isReading) {
      print('El lector ya está buscando una tarjeta.');
      return;
    }

    _isReading = true;
    notifyListeners();

    final context = Context(Scope.user);

    try {
      await context.establish();
      List<String> readers = await context.listReaders();

      if (readers.isEmpty) {
        print('❌ No se detectó ningún lector conectado.');
        return;
      }

      print('✅ Lector: ${readers.first}. Esperando tarjeta...');

      List<String> withCard = await context.waitForCard(readers).value;

      if (withCard.isEmpty) {
        print('⚠️ Proceso terminado sin detectar tarjeta.');
        return;
      }

      print('💳 Conectando a la tarjeta...');
      Card card = await context.connect(
        withCard.first,
        ShareMode.shared,
        Protocol.any,
      );

      print('📡 Solicitando UID...');
      
      Uint8List resp = await card.transmit(
        Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]),
      );

      await card.disconnect(Disposition.leaveCard);

      if (resp.length >= 2) {
        int sw1 = resp[resp.length - 2];
        int sw2 = resp[resp.length - 1];

        if (sw1 == 0x90 && sw2 == 0x00) {
          Uint8List uidBytes = resp.sublist(0, resp.length - 2);
          
          String uidHex = uidBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join();

          final jsonData = {
            "type": "RES_NFC",
            "uid": uidHex
          };

          webSocketService.sendMessage(jsonData);
          
        } else {
          print('❌ Lectura fallida.');
        }
      }

    } catch (e) {
      print('❌ Error general NFC: $e');
    } finally {
      await context.release();
      _isReading = false;
      notifyListeners();
    }
  }
}

final nfcPcsc = NfcPcscService();