import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/hikvision_sdk.dart';
import '../services/zkteco_sdk.dart';
import '../services/tts_service.dart';

class FingerprintDevice {
  final String id;
  final String name;
  final String type;

  FingerprintDevice({
    required this.id,
    required this.name,
    required this.type,
  });
}

class FingerprintReaderService extends ChangeNotifier {
  final AuthService _authService;
  final TTSService _ttsService = TTSService();

  static const String _baseUrl =
      'https://web.anfibius.net:8181/anfibiusBack/api';

  /// ==============================
  /// DEVICE STATE
  /// ==============================

  List<FingerprintDevice> _availableDevices = [];
  FingerprintDevice? _selectedDevice;

  bool _isConnected = false;
  bool _isScanning = false;
  bool _isLooping = false; // Nueva flag para evitar hilos duplicados

  /// ==============================
  /// SDKs
  /// ==============================

  HikvisionSDK? _hikvisionSDK;
  ZKTecoSDK? _zktecoSDK;

  String? _sdkType; // hikvision | zkteco

  /// ZKTeco Handles (persistentes)
  dynamic _zkDeviceHandle;
  dynamic _zkDBHandle;

  /// ==============================
  /// CALLBACKS
  /// ==============================

  Function(String fingerprintData)? onFingerprintRead;
  Function(Map<String, dynamic>)? onAttendanceMarked;
  Function(bool)? onConnectionChanged;

  /// ==============================
  /// CONSTRUCTOR
  /// ==============================

  FingerprintReaderService(this._authService) {
    _init();
  }

  Future<void> _init() async {
  await _ttsService.initialize();

  _isAutoListeningEnabled =
      await ConfigService.loadAutoListeningEnabled();

  _ttsEnabled =
      await ConfigService.loadTTSEnabled();

  _ttsService.setEnabled(_ttsEnabled);

  await scanDevices();
}

  /// ==============================
  /// SCAN DEVICES (UNIFICADO)
  /// ==============================

  Future<void> scanDevices() async {
    print("Scanning for fingerprint devices...");
    _availableDevices.clear();
    

    // ---- ZKTeco ----
    try {
      _zktecoSDK ??= ZKTecoSDK();

      final init = _zktecoSDK!.init();
      print("ZK Init result: $init");

      // En algunos casos 1 o 0 pueden ser aceptables (ya inicializado o éxito)
      // Si init >= 0, intentamos obtener el conteo de dispositivos
      if (init >= 0) {
        final count = _zktecoSDK!.getDeviceCount();
        print("ZK Device count: $count");

        for (int i = 0; i < count; i++) {
          _availableDevices.add(
            FingerprintDevice(
              id: 'zkteco_$i',
              name: 'ZKTeco #$i',
              type: 'zkteco',
            ),
          );
        }
        
        // No terminamos aquí si queremos mantener el conteo o si vamos a abrirlo después
        // Pero para el escaneo puro solemos terminar
        _zktecoSDK!.terminate();
      }
    } catch (e) {
      developer.log('ZKTeco scan error: $e');
    }

    // ---- Hikvision ----
    try {
      if (HikvisionSDK.initialize()) {
        final devices = HikvisionSDK.enumDevices();

        for (var d in devices) {
          _availableDevices.add(
            FingerprintDevice(
              id: 'hikvision_${d["id"]}',
              name: d["name"],
              type: 'hikvision',
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Hikvision scan error: $e');
    }

    notifyListeners();
  }

  /// ==============================
  /// SELECT DEVICE
  /// ==============================

  Future<void> selectDevice(FingerprintDevice device) async {
    await disconnect();

    _selectedDevice = device;

    if (device.type == 'zkteco') {
      _sdkType = 'zkteco';
      _zktecoSDK ??= ZKTecoSDK();
    } else if (device.type == 'hikvision') {
      _sdkType = 'hikvision';
      _hikvisionSDK ??= HikvisionSDK();
    }

    await connect();
    notifyListeners();
  }

  /// ==============================
  /// CONNECT
  /// ==============================

  Future<bool> connect() async {
    if (_selectedDevice == null) return false;

    try {
      if (_sdkType == 'zkteco') {
        final init = _zktecoSDK!.init();
        // Aceptamos 0 o 1 (inicializado)
        if (init < 0) return false;

        final index =
            int.parse(_selectedDevice!.id.split('_').last);

        _zkDeviceHandle = _zktecoSDK!.openDevice(index);
        if (_zkDeviceHandle == null) return false;

        _zkDBHandle = _zktecoSDK!.dbInit();
        if (_zkDBHandle == null) return false;

        _isConnected = true;
      }

      if (_sdkType == 'hikvision') {
        _isConnected = HikvisionSDK.openDevice();
      }

      onConnectionChanged?.call(_isConnected);
      notifyListeners();
      return _isConnected;
    } catch (e) {
      developer.log("Connect error: $e");
      return false;
    }
  }

  /// ==============================
  /// DISCONNECT
  /// ==============================

  Future<void> disconnect() async {
    // Primero detenemos cualquier escaneo activo
    _isScanning = false;
    
    // Esperamos un momento para que el hilo de escucha se detenga
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      if (_sdkType == 'zkteco' && _isConnected) {
        _zktecoSDK!.dbFree(_zkDBHandle);
        _zktecoSDK!.closeDevice(_zkDeviceHandle);
        _zktecoSDK!.terminate();
      }

      if (_sdkType == 'hikvision') {
        HikvisionSDK.stopCapture();
        HikvisionSDK.closeDevice();
      }
    } catch (e) {
       print("Error durante la desconexión: $e");
    }

    _isConnected = false;
    _lastFingerprintImage = null; // Limpiar imagen al desconectar
    onConnectionChanged?.call(false);
    notifyListeners();
  }

  /// ==============================
  /// START LISTENING
  /// ==============================

  void startListening() {
    if (!_isConnected) return;
    
    // Si ya estamos escaneando, no hacemos nada para evitar duplicar el hilo
    if (_isScanning) return;

    _isScanning = true;

    if (_sdkType == 'hikvision') {
      HikvisionSDK.startCapture();
    }

    if (_sdkType == 'zkteco') {
      // Solo lanzamos el hilo si no hay uno ya corriendo
      if (!_isLooping) {
        _startZKListening();
      }
    }
    
    notifyListeners();
  }

  void stopListening() {
    _isScanning = false;

    if (_sdkType == 'hikvision') {
      HikvisionSDK.stopCapture();
    }
    
    notifyListeners();
  }

  /// ==============================
  /// ZK LISTEN LOOP
  /// ==============================

  Future<void> _startZKListening() async {
    if (_isLooping) return;
    _isLooping = true;
    
    print("Iniciando hilo de escucha ZK...");
    
    try {
      // Obtenemos dimensiones una sola vez para evitar error -2 (Busy/Invalid Handle)
      final w = _zktecoSDK!.getImageWidth(_zkDeviceHandle);
      final h = _zktecoSDK!.getImageHeight(_zkDeviceHandle);
      
      print("Iniciando escucha ZK con dimensiones: ${w}x${h}");

      int noFingerCount = 0;
      
      while (_isScanning && _isConnected) {
        final result = _zktecoSDK!.captureFingerprint(
          _zkDeviceHandle,
          prefWidth: w,
          prefHeight: h,
        );

        if (result != null) {
          noFingerCount = 0; // Reset contador
          _lastCaptureTime = DateTime.now();
          _lastFingerprintImage = result.image; 
          _lastImageWidth = result.width;
          _lastImageHeight = result.height;
          notifyListeners();

          if (result.template.isNotEmpty) {
            final base64 = base64Encode(result.template);
            onFingerprintRead?.call(base64);

            // AUTO-TIMBRADO: Si no estamos registrando, marcamos asistencia
            if (!_isRegistering) {
              print("Intentando timbrado automático...");
              markAttendance(result.template).then((response) {
                if (response != null) {
                  print("Timbrado exitoso: ${response['message']}");
                  onAttendanceMarked?.call(response);
                }
              }).catchError((e) {
                print("Error en timbrado automático: $e");
              });
            }
          }
        } else {
          noFingerCount++;
          // Si no hay dedo por más de 2 ciclos (~1 segundo), volvemos a la imagen por defecto
          if (noFingerCount >= 2 && _lastFingerprintImage != null) {
            _lastFingerprintImage = null;
            notifyListeners();
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print("Error en el hilo de escucha ZK: $e");
    } finally {
      _isLooping = false;
      _isScanning = false;
      print("Hilo de escucha ZK finalizado.");
      notifyListeners();
    }
  }

  /// ==============================
  /// MARK ATTENDANCE (OPTIMIZADO)
  /// ==============================

  Future<Map<String, dynamic>?> markAttendance(
      Uint8List template) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final uri = Uri.parse(
        '$_baseUrl/empleados/marcarbiometrico');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/octet-stream',
      },
      body: template,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _ttsService.sayWelcome(
        data["data"]["empleado"]["nombres"],
        data["data"]["empleado"]["apellidos"],
      );
      return data;
    }

    return null;
  }

  Future<bool> connectToDevice() async {
  if (_selectedDevice == null) return false;
  await connect();
  return _isConnected;
}

Future<void> setAutoListeningEnabled(bool value) async {
  _isAutoListeningEnabled = value;

  await ConfigService.saveAutoListeningEnabled(value);

  if (_isConnected && value) {
    startListening();
  }

  notifyListeners();
}

Future<void> setTTSEnabled(bool value) async {
  _ttsEnabled = value;

  await ConfigService.saveTTSEnabled(value);

  _ttsService.setEnabled(value);

  notifyListeners();
}

  Future<bool> registerFingerprint(int employeeId, Uint8List template) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final uri = Uri.parse(
        '$_baseUrl/empleados/registarbiometrico?id=$employeeId');

    print("Enviando registro de huella a: $uri");

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/octet-stream',
        },
        body: template,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      print("Error registrando huella: $e");
      return false;
    }
  }

  Future<void> startFingerprintRegistration(int employeeId) async {
    if (!_isConnected || _sdkType != 'zkteco') {
      onRegistrationStatusChange?.call(false, "Dispositivo no conectado");
      return;
    }

    if (_isRegistering) return;
    _isRegistering = true;

    try {
      // Lista para guardar los 3 templates
      List<Uint8List> templates = [];
      
      // Obtenemos dimensiones una vez
      final w = _zktecoSDK!.getImageWidth(_zkDeviceHandle);
      final h = _zktecoSDK!.getImageHeight(_zkDeviceHandle);

      while (templates.length < 3 && _isRegistering) {
        // Notificar que esperamos dedo
        onRegistrationStatusChange?.call(false, null); 

        // Intentar capturar
        final result = _zktecoSDK!.captureFingerprint(
          _zkDeviceHandle, 
          prefWidth: w, 
          prefHeight: h
        );

        if (result != null && result.template.isNotEmpty) {
          // Dedo detectado y template extraído
          onFingerDetected?.call();
          
          // Guardar imagen para feedback visual
          _lastFingerprintImage = result.image;
          _lastImageWidth = result.width;
          _lastImageHeight = result.height;
          _lastCaptureTime = DateTime.now();
          notifyListeners();

          templates.add(result.template);
          
          // Notificar a la UI que esta captura fue exitosa
          onRegistrationStatusChange?.call(true, null);
          
          // Esperar un poco para que el usuario levante el dedo
          if (templates.length < 3) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
        
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (templates.length == 3) {
        // Tenemos los 3 templates, procedemos al MERGE real
        final mergedTemplatePtr = calloc<Uint8>(2048);
        final mergedLenPtr = calloc<Uint32>()..value = 2048;

        // Necesitamos punteros para los 3 templates originales
        final t1 = calloc<Uint8>(templates[0].length)..asTypedList(templates[0].length).setAll(0, templates[0]);
        final t2 = calloc<Uint8>(templates[1].length)..asTypedList(templates[1].length).setAll(0, templates[1]);
        final t3 = calloc<Uint8>(templates[2].length)..asTypedList(templates[2].length).setAll(0, templates[2]);

        try {
          final mergeResult = _zktecoSDK!.dbMerge(
            _zkDBHandle,
            t1,
            t2,
            t3,
            mergedTemplatePtr,
            mergedLenPtr
          );

          if (mergeResult == 0) {
            final finalTemplate = Uint8List.fromList(mergedTemplatePtr.asTypedList(mergedLenPtr.value));
            
            // REGISTRO REAL EN EL SERVIDOR
            final success = await registerFingerprint(employeeId, finalTemplate);
            
            if (success) {
              onRegistrationSuccess?.call();
            } else {
              throw Exception("El servidor rechazó la huella");
            }
          } else {
            throw Exception("Error al combinar huellas (Merge error: $mergeResult)");
          }
        } finally {
          calloc.free(t1);
          calloc.free(t2);
          calloc.free(t3);
          calloc.free(mergedTemplatePtr);
          calloc.free(mergedLenPtr);
        }
      }
    } catch (e) {
      onRegistrationStatusChange?.call(false, e.toString());
    } finally {
      _isRegistering = false;
    }
  }

void stopFingerprintRegistration() {
  _isRegistering = false;
}

  /// ==============================
  /// GETTERS
  /// ==============================

  List<FingerprintDevice> get availableDevices =>
      _availableDevices;

  bool get isConnected => _isConnected;

  bool get isScanning => _isScanning;

  FingerprintDevice? get selectedDevice => _selectedDevice;

DateTime? _lastCaptureTime;
DateTime? get lastCaptureTime => _lastCaptureTime;

Uint8List? _lastFingerprintImage;
Uint8List? get lastFingerprintImage => _lastFingerprintImage;

int _lastImageWidth = 256;
int get lastImageWidth => _lastImageWidth;

int _lastImageHeight = 288;
int get lastImageHeight => _lastImageHeight;

bool _isAutoListeningEnabled = false;
bool _ttsEnabled = true;

bool _isRegistering = false;

bool get isAutoListeningEnabled => _isAutoListeningEnabled;
bool get isTTSEnabled => _ttsEnabled;

// ------------------
// REGISTRATION CALLBACKS
// ------------------

VoidCallback? onFingerDetected;

Function(bool isReading, String? error)? onRegistrationStatusChange;

VoidCallback? onRegistrationSuccess;

}