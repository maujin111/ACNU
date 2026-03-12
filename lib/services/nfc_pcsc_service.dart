import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Card; 
import 'package:dart_pcsc/dart_pcsc.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/config_service.dart';

class NfcPcscService extends ChangeNotifier {
  bool _isReading = false;
  bool get isReading => _isReading;

  // El lector que está guardado
  String? _savedReaderName;
  String? get savedReaderName => _savedReaderName;

  // Estado físico de conexión del lector guardado
  bool _isReaderConnected = false;
  bool get isReaderConnected => _isReaderConnected;

  bool _isDisposed = false;
  Timer? _monitoringTimer;

  NfcPcscService() {
    _initFromStorage();
  }

  // Cargar desde Local Storage al iniciar
  Future<void> _initFromStorage() async {
    try {
      _savedReaderName = await ConfigService.loadNfcReader();
      _startMonitoring();
    } catch (e) {
      print('❌ Error cargando NFC de local storage: $e');
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkReaderStatusSilently();
    });
  }

  Future<void> _checkReaderStatusSilently() async {
    if (_isDisposed || _isReading) return;

    final context = Context(Scope.user);
    try {
      await context.establish();
      
      List<String> readers = [];
      try {
        readers = await context.listReaders();
      } catch (e) {
        readers = []; 
      }

      bool stateChanged = false;

      // 1. AUTO-GUARDADO: Si no hay lector guardado, pero hay uno físico, lo guardamos.
      if (_savedReaderName == null && readers.isNotEmpty) {
        _savedReaderName = readers.first;
        await ConfigService.saveNfcReader(_savedReaderName!);
        print('💾 [NFC] Nuevo lector guardado: $_savedReaderName');
        stateChanged = true;
      }

      // 2. VERIFICACIÓN: Vemos si el lector guardado está actualmente conectado
      bool currentlyConnected = false;
      if (_savedReaderName != null) {
        currentlyConnected = readers.any((r) => r.contains(_savedReaderName!) || _savedReaderName!.contains(r));
      }

      // 3. ACTUALIZACIÓN DE ESTADO SI HUBO CAMBIOS
      if (_isReaderConnected != currentlyConnected) {
        _isReaderConnected = currentlyConnected;
        stateChanged = true;
        
        if (_isReaderConnected) {
          print('✅ [NFC] Lector conectado: $_savedReaderName');
        } else if (_savedReaderName != null) {
          print('❌ [NFC] Lector desconectado físicamente: $_savedReaderName');
        }
      }

      if (stateChanged) notifyListeners();

    } catch (e) {
      if (_isReaderConnected) {
        _isReaderConnected = false;
        notifyListeners();
      }
    } finally {
      try {
        await context.release();
      } catch (_) {}
    }
  }


  Future<void> forgetReader() async {
    print('🗑️ [NFC] Olvidando lector guardado');
    _savedReaderName = null;
    _isReaderConnected = false;
    await ConfigService.removeNfcReader();
    notifyListeners();
  }

  Future<void> checkReaderStatus() async {
    await _checkReaderStatusSilently();
  }

  // Lógica de Lectura 
  Future<void> startNFC(WebSocketService webSocketService) async {
    if (_isReading) return;
    if (!_isReaderConnected) {
      print('❌ No se puede iniciar lectura: Lector no conectado.');
      return;
    }

    _isReading = true;
    notifyListeners();
    final context = Context(Scope.user);

    try {
      await context.establish();
      List<String> readers = await context.listReaders();

      if (readers.isEmpty) {
        _isReaderConnected = false;
        return;
      }

      List<String> withCard = await context.waitForCard(readers).value.timeout(
        const Duration(seconds: 30),
        onTimeout: () => [],
      );

      if (withCard.isEmpty) return;

      Card card = await context.connect(withCard.first, ShareMode.shared, Protocol.any);
      Uint8List resp = await card.transmit(Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]));
      await card.disconnect(Disposition.leaveCard);

      if (resp.length >= 2 && resp[resp.length - 2] == 0x90 && resp[resp.length - 1] == 0x00) {
        Uint8List uidBytes = resp.sublist(0, resp.length - 2);
        String uidHex = uidBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
        webSocketService.sendMessage({"type": "RES_NFC", "uid": uidHex});
      }
    } catch (e) {
      print('❌ Error NFC: $e');
      Future.delayed(const Duration(seconds: 1), () => _checkReaderStatusSilently());
    } finally {
      try { await context.release(); } catch (_) {}
      _isReading = false;
      notifyListeners();
    }
  }

}

//final nfcPcsc = NfcPcscService();