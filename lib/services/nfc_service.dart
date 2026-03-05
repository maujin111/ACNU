import 'package:anfibius_uwu/nfc_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'logger_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/notifications_service.dart';

class NfcService extends ChangeNotifier {
  Future<void> startNFC() async {
    WebSocketService wsService = WebSocketService();
    logger.info('Iniciando sesión NFC...');
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      logger.info('Disponibilidad NFC: $availability');
      if (availability != NFCAvailability.available) {
        logger.info(
          'NFC no está disponible o está apagado en este dispositivo.',
        );
        return;
      }
      logger.info('Acerca la etiqueta NFC ahora...');
      NotificationsService().showNotification(
        id: 1,
        title: "SCANER ACTIVO",
        body: "Acerca la etiqueta NFC",
      );

      const flags =
          0x80 |
          0x40 |
          0x20 |
          0x10; // FLAG_READER_NFC_A | FLAG_READER_NFC_B | FLAG_READER_NFC_F | FLAG_READER_NFC_V

      NFCTag tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: 40),
        androidReaderModeFlags: flags,
      );
      logger.info('ID de la tarjeta: ${tag.id}');
      logger.info('Tipo de tecnología: ${tag.type}');

      final datosJson = {"type": "RES_NFC", "uid": tag.id};

      bool wasSent = wsService.sendMessage(datosJson);
      if (wasSent) {
        logger.info('Mensaje NFC enviado exitosamente a través de WebSocket.');
      } else {
        logger.error('Error al enviar mensaje NFC a través de WebSocket.');
      }
      if (tag.ndefAvailable == true) {
        var ndefRecords = await FlutterNfcKit.readNDEFRecords();
        logger.info('Contenido NDEF: $ndefRecords');
      }

      stopNfcSession(); // Cerrar sesión NFC después de la lectura
    } catch (e) {
      logger.error('Error o cancelación durante la lectura NFC: $e');
    }
  }

  Future<void> stopNfcSession() async {
    try {
      await FlutterNfcKit.finish();
      logger.info('Sesión NFC cerrada correctamente.');
    } catch (e) {
      logger.error('Error al cerrar la sesión NFC: $e');
    }
  }
}

final nfc = NfcService();
