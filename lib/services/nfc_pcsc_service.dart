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
    // Reiniciamos el timer solo si no hemos hecho dispose
    if (!_isDisposed) {
      _monitoringTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _checkReaderStatusSilently();
      });
    }
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

      // 1. AUTO-GUARDADO
      if (_savedReaderName == null && readers.isNotEmpty) {
        _savedReaderName = readers.first;
        await ConfigService.saveNfcReader(_savedReaderName!);
        print('💾 [NFC] Nuevo lector guardado: $_savedReaderName');
        stateChanged = true;
      }

      // 2. VERIFICACIÓN
      bool currentlyConnected = false;
      if (_savedReaderName != null) {
        currentlyConnected = readers.any(
          (r) => r.contains(_savedReaderName!) || _savedReaderName!.contains(r),
        );
      }

      // 3. ACTUALIZACIÓN DE ESTADO
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

  @override
  void dispose() {
    _isDisposed = true;
    _monitoringTimer?.cancel();
    super.dispose();
  }

  Future<void> startNFC(WebSocketService webSocketService, {dynamic id}) async {
    if (_isReading) return;
    if (!_isReaderConnected || _savedReaderName == null) {
      print('❌ No se puede iniciar lectura: Lector no conectado.');
      return;
    }

    _isReading = true;
    _monitoringTimer?.cancel();
    notifyListeners();

    final context = Context(Scope.user);

    try {
      await context.establish();

      final endTime = DateTime.now().add(const Duration(seconds: 30));
      bool cardReadSuccessfully = false;

      // CICLO WHILE: Permite reintentar si el usuario quita la tarjeta rápido
      while (DateTime.now().isBefore(endTime) && !cardReadSuccessfully) {
        final remaining = endTime.difference(DateTime.now());
        if (remaining.inMilliseconds <= 0) break;

        final waitOp = context.waitForCard([_savedReaderName!]);

        try {
          // 👉 EL DOBLE CANDADO: Forzamos a Dart a no quedarse atascado
          List<String> withCard = await waitOp.value.timeout(
            remaining,
            onTimeout: () {
              // Si Dart agota el tiempo, matamos la operación de hardware a la fuerza
              try {
                waitOp.cancel();
              } catch (_) {}
              // Lanzamos error para salir del 'await' congelado
              throw TimeoutException('NFC Timeout de Dart alcanzado');
            },
          );

          if (withCard.isEmpty) {
            continue;
          }

          // Conectamos a la tarjeta lo más rápido posible
          Card card = await context.connect(
            withCard.first,
            ShareMode.shared,
            Protocol.any,
          );

          // Transmitimos APDU para sacar el UID
          Uint8List resp = await card.transmit(
            Uint8List.fromList([0xFF, 0xCA, 0x00, 0x00, 0x00]),
          );

          await card.disconnect(Disposition.leaveCard);

          if (resp.length >= 2 &&
              resp[resp.length - 2] == 0x90 &&
              resp[resp.length - 1] == 0x00) {
            Uint8List uidBytes = resp.sublist(0, resp.length - 2);
            String uidHex =
                uidBytes
                    .map(
                      (b) => b.toRadixString(16).padLeft(2, '0').toUpperCase(),
                    )
                    .join();

            print('✅ NFC Leído exitosamente: $uidHex');

            // Armamos el payload con el ID dinámico
            final Map<String, dynamic> responsePayload = {
              "type": "RES_NFC",
              "uid": uidHex,
            };
            if (id != null) responsePayload["id"] = id;

            webSocketService.sendMessage(responsePayload);
            cardReadSuccessfully = true; // Rompe el ciclo
          }
        } catch (innerError) {
          // Por si el error no vino del timeout, liberamos hardware
          try {
            waitOp.cancel();
          } catch (_) {}

          final errorStr = innerError.toString().toLowerCase();

          // Si el error fue provocado porque se agotó el tiempo límite
          if (errorStr.contains('timeout') || errorStr.contains('cancel')) {
            break;
          }
          // Si la tarjeta fue removida muy rápido (Tap & Go fallido)
          else if (errorStr.contains('removed') ||
              errorStr.contains('no smartcard') ||
              errorStr.contains('unresponsive')) {
            print('⚠️ Tarjeta retirada muy rápido. Acérquela de nuevo...');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            print('❌ Error interno en lectura NFC: $innerError');
            break;
          }
        }
      }

      if (!cardReadSuccessfully) {
        print(
          '⏱️ Lectura NFC finalizada (No se detectó tarjeta válida en 30s).',
        );
      }
    } catch (e) {
      print('❌ Error crítico inicializando NFC: $e');
    } finally {
      try {
        // 👉 PROTECCIÓN EXTRA: Evitar que liberar el contexto congele la app
        await context.release().timeout(const Duration(seconds: 2));
      } catch (_) {}

      _isReading = false;
      notifyListeners();

      _startMonitoring();
    }
  }
}
