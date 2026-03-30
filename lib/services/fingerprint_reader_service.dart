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

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class FingerprintDevice {
  final String id;
  final String name;
  final String type;

  FingerprintDevice({required this.id, required this.name, required this.type});
}

class FingerprintReaderService extends ChangeNotifier {
  AuthService _authService;
  final TTSService _ttsService = TTSService();

  static const String _baseUrl = 'http://10.0.1.33:8080/anfibiusBack/api';

  static const String _secureKeyStr = "AnfibiusAppSecureKey2026_32bytes";
  static const String _initVectorStr = "RandomInitVec123";

  /// ==============================
  /// DEVICE STATE
  /// ==============================

  List<FingerprintDevice> _availableDevices = [];
  FingerprintDevice? _selectedDevice;

  bool _isConnected = false;
  bool _isScanning = false;
  bool _isLooping = false; // Nueva flag para evitar hilos duplicados
  bool _huellasCargadasEnRam = false;

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

  void updateAuthService(AuthService authService) {
    _authService = authService;
  }

  @override
  void dispose() {
    _isScanning = false;
    _isLooping = false;
    disconnect();
    super.dispose();
  }

  Future<void> _init() async {
    await _ttsService.initialize();

    _isAutoListeningEnabled = await ConfigService.loadAutoListeningEnabled();
    _ttsEnabled = await ConfigService.loadTTSEnabled();
    _ttsService.setEnabled(_ttsEnabled);

    await scanDevices();

    final savedDeviceData = await ConfigService.loadFingerprintDevice();

    if (savedDeviceData != null) {
      _selectedDevice = FingerprintDevice(
        id: savedDeviceData['vendorId'] ?? '',
        name: savedDeviceData['name'] ?? 'Lector Biométrico',
        type: savedDeviceData['type'] ?? '',
      );

      if (_selectedDevice!.type.toLowerCase().contains('zk')) {
        _sdkType = 'zkteco';
        _zktecoSDK ??= ZKTecoSDK();
      } else {
        _sdkType = 'hikvision';
        _hikvisionSDK ??= HikvisionSDK();
      }

      final connected = await connect();

      if (connected && _isAutoListeningEnabled) {
        startListening();
      } else if (!connected) {}
    }
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
    await ConfigService.saveFingerprintDevice(
      device.type,
      device.id,
      '',
      device.name,
    );

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

        final index = int.parse(_selectedDevice!.id.split('_').last);

        _zkDeviceHandle = _zktecoSDK!.openDevice(index);
        if (_zkDeviceHandle == null) return false;

        _zkDBHandle = _zktecoSDK!.dbInit();
        if (_zkDBHandle == null) return false;

        _isConnected = true;
        await _loadFingerprintsToMemory();
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

  void startListening() async {
    if (!_isConnected) return;

    // Si ya estamos escaneando, no hacemos nada para evitar duplicar el hilo
    if (_isScanning) return;

    if (_sdkType == 'zkteco' && !_huellasCargadasEnRam) {
      await _loadFingerprintsToMemory();
    }

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

            // AUTO-TIMBRADO
            if (result.template.isNotEmpty) {
              final base64 = base64Encode(result.template);
              onFingerprintRead?.call(base64);

              // AUTO-TIMBRADO: Validación local con la RAM
              if (!_isRegistering) {
                print("🔎 Analizando huella localmente...");

                // El SDK compara contra las huellas cargadas y nos da el ID
                final int matchId = _zktecoSDK!.identifyFingerprint(
                  _zkDBHandle,
                  result.template,
                );

                if (matchId > 0) {
                  print("✅ Huella reconocida! Empleado ID: $matchId");

                  // Enviamos el timbrado seguro
                  markAttendanceSeguro(matchId).then((response) {
                    if (response != null) {
                      print("✅ Timbrado exitoso en BD");
                      onAttendanceMarked?.call(response);
                    }
                  });
                } else {
                  print(
                    "❌ Huella no reconocida (No hace match con ninguna guardada).",
                  );
                  // Opcional: _ttsService.sayWelcome("Empleado", "No reconocido");
                }
              }
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
  /// CARGAR HUELLAS A LA MEMORIA (ZKTeco)
  /// ==============================
  Future<void> _loadFingerprintsToMemory() async {
    if (_sdkType != 'zkteco' || !_isConnected) return;

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      print("⏳ Descargando huellas del servidor...");
      final response = await http.get(
        Uri.parse('$_baseUrl/empleados/huellas'),
        headers: {'Authorization': token},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> huellasArray = jsonResponse['data'];

        // Preparar llaves AES
        final key = encrypt.Key.fromUtf8(_secureKeyStr);
        final iv = encrypt.IV.fromUtf8(_initVectorStr);
        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
        );

        int huellasCargadas = 0;

        for (var item in huellasArray) {
          final int empId = item['empl_id'];
          final String base64Aes = item['huella_aes'];

          try {
            // 1. Desencriptar el Base64 a bytes crudos
            final encryptedObj = encrypt.Encrypted.fromBase64(base64Aes);
            final decryptedBytes = encrypter.decryptBytes(encryptedObj, iv: iv);
            final Uint8List templateData = Uint8List.fromList(decryptedBytes);

            // Insertar en la memoria RAM del SDK
            final bool exito = _zktecoSDK!.addTemplateToMemory(
              _zkDBHandle,
              empId,
              templateData,
            );

            if (exito) {
              huellasCargadas++;
            }
          } catch (e) {
            print("❌ Error al desencriptar/cargar huella del ID $empId: $e");
          }
        }
        print(
          "✅ $huellasCargadas huellas cargadas exitosamente en la RAM del lector.",
        );
        _huellasCargadasEnRam = true;
      }
    } catch (e) {
      print("❌ Error de red al cargar huellas: $e");
    }
  }

  /// ==============================
  /// MARK ATTENDANCE (OPTIMIZADO)
  /// ==============================

  // Future<Map<String, dynamic>?> markAttendance(Uint8List template) async {
  //   final token = await _authService.getToken();
  //   if (token == null) return null;

  //   final uri = Uri.parse('$_baseUrl/empleados/marcarbiometrico');
  //   print(template);
  //   final response = await http.post(
  //     uri,
  //     headers: {
  //       'Authorization': token,
  //       'Content-Type': 'application/octet-stream',
  //     },
  //     body: template,
  //   );
  //   print(jsonDecode(response.body));
  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //     await _ttsService.sayWelcome(
  //       data["data"]["empleado"]["nombres"],
  //       data["data"]["empleado"]["apellidos"],
  //     );
  //     return data;
  //   }

  //   return null;
  // }

  /// ==============================
  /// MARK ATTENDANCE SEGURO (HMAC)
  /// ==============================
  Future<Map<String, dynamic>?> markAttendanceSeguro(int employeeId) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final uri = Uri.parse('$_baseUrl/empleados/marcarbiometrico');

    // 1. Generar Timestamp (ISO 8601 UTC)
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // 2. Crear Payload y Firmar con HMAC-SHA256
    final payload = "$employeeId|$timestamp";
    final hmacSha256 = Hmac(sha256, utf8.encode(_secureKeyStr));
    final digest = hmacSha256.convert(utf8.encode(payload));
    final firmaBase64 = base64Encode(digest.bytes);

    print("🚀 Enviando timbrado seguro para ID $employeeId...");

    try {
      final response = await http.post(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'empleado_id': employeeId,
          'timestamp': timestamp,
          'firma': firmaBase64,
        }),
      );

      print("📦 Respuesta cruda del servidor: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Verificamos que la API Java respondió bien (200)
        if (data['code'] == 200) {
          final bdData = data['data']; // Este es el JSON que mandó Postgres

          if (bdData != null) {
            // Verificamos si Postgres dijo que todo salió bien
            if (bdData['success'] == true) {
              print("✅ Timbrado registrado exitosamente en base de datos.");

              if (bdData['empleado'] != null) {
                final empleado = bdData['empleado'];
                final nombres = empleado['nombres'] ?? 'Empleado';
                final apellidos = empleado['apellidos'] ?? '';
                await _ttsService.sayWelcome(nombres, apellidos);
              } else {
                await _ttsService.sayWelcome("Empleado", "Registrado");
              }
            } else {
              // Si Postgres dice success: false (Ej. No tiene turno)
              final mensajeError = bdData['message'] ?? 'Error desconocido';
              print(
                "⚠️ Timbrado rechazado por regla de negocio: $mensajeError",
              );

              await _ttsService.sayWelcome("Error", "Consulte su turno");
            }
          }
          return data;
        } else {
          print("⚠️ La API Java rechazó la petición: ${data['message']}");
        }
      } else {
        print("❌ Error HTTP ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("❌ Excepción en timbrado automático: $e");
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

    if (_isConnected) {
      if (value) {
        startListening();
      } else if (!value) {
        stopListening();
      }
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
      '$_baseUrl/empleados/registrarbiometrico?id=$employeeId',
    );

    print("Enviando registro de huella a: $uri");

    try {
      print(template);
      final response = await http.post(
        uri,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/octet-stream',
        },
        body: template,
      );
      print(jsonDecode(response.body));
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

    final bool estabaEscuchando = _isScanning;
    if (estabaEscuchando) {
      stopListening();
      // Le damos medio segundo al lector para que apague la luz y libere la memoria
      await Future.delayed(const Duration(milliseconds: 500));
    }
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
          prefHeight: h,
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
        final t1 = calloc<Uint8>(templates[0].length)
          ..asTypedList(templates[0].length).setAll(0, templates[0]);
        final t2 = calloc<Uint8>(templates[1].length)
          ..asTypedList(templates[1].length).setAll(0, templates[1]);
        final t3 = calloc<Uint8>(templates[2].length)
          ..asTypedList(templates[2].length).setAll(0, templates[2]);

        try {
          final mergeResult = _zktecoSDK!.dbMerge(
            _zkDBHandle,
            t1,
            t2,
            t3,
            mergedTemplatePtr,
            mergedLenPtr,
          );

          if (mergeResult == 0) {
            final finalTemplate = Uint8List.fromList(
              mergedTemplatePtr.asTypedList(mergedLenPtr.value),
            );

            // REGISTRO REAL EN EL SERVIDOR
            final success = await registerFingerprint(
              employeeId,
              finalTemplate,
            );

            if (success) {
              onRegistrationSuccess?.call();
            } else {
              throw Exception("El servidor rechazó la huella");
            }
          } else {
            throw Exception(
              "Error al combinar huellas (Merge error: $mergeResult)",
            );
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
      if (estabaEscuchando && _isAutoListeningEnabled) {
        startListening();
      }
    }
  }

  void stopFingerprintRegistration() {
    _isRegistering = false;
  }

  Future<void> forgetDevice() async {
    await disconnect();
    await ConfigService.removeFingerprintDevice();

    _selectedDevice = null;
    _sdkType = null;
    notifyListeners();
  }

  /// ==============================
  /// GETTERS
  /// ==============================

  List<FingerprintDevice> get availableDevices => _availableDevices;

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
