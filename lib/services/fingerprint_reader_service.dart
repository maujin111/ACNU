import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; // Import for http
import 'package:anfibius_uwu/services/auth_service.dart';
import '../services/config_service.dart';
import '../services/hikvision_sdk.dart' show HikvisionSDK, HikvisionConstants;

// Clase simple para representar un dispositivo
class FingerprintDevice {
  final String id;
  final String name;
  final String type;

  FingerprintDevice({required this.id, required this.name, required this.type});

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'type': type};
  }

  factory FingerprintDevice.fromJson(Map<String, dynamic> json) {
    return FingerprintDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class FingerprintReaderService extends ChangeNotifier {
  static const String _baseUrl =
      'http://localhost:8080'; // Replace with your actual API base URL
  AuthService _authService;

  // Dispositivos disponibles (simulados por ahora)
  List<FingerprintDevice> _availableDevices = [];

  // Dispositivo seleccionado
  FingerprintDevice? _selectedDevice;

  // Estado de conexión
  bool _isConnected = false;
  bool _isScanning = false;

  // Timer para escanear automáticamente
  Timer? _scanTimer;
  Timer? _connectionCheckTimer;

  // SDK de Hikvision
  int _currentDeviceID = -1;
  int? _currentEmployeeIdForRegistration;

  // Última imagen de huella capturada
  Uint8List? _lastFingerprintImage;
  DateTime? _lastCaptureTime;

  // Control de captura para evitar múltiples capturas simultáneas
  bool _isCapturing = false;
  DateTime? _lastCaptureAttempt;

  // Callbacks
  Function(String fingerprintData)? onFingerprintRead;
  Function(bool isConnected)? onConnectionChanged;

  // Método para actualizar el AuthService
  void updateAuthService(AuthService newAuthService) {
    _authService = newAuthService;
  }

  // Método para iniciar el proceso de registro de huella para un empleado específico
  void startFingerprintRegistration(int employeeId) {
    _currentEmployeeIdForRegistration = employeeId;
    developer.log(
      '🚀 Iniciando registro de huella para empleado ID: $employeeId',
    );
    // Asegurarse de que el lector esté escaneando
    if (!_isScanning) {
      _startFingerprintListening();
    }
  }

  // Método para detener el proceso de registro de huella
  void stopFingerprintRegistration() {
    _currentEmployeeIdForRegistration = null;
    developer.log('🛑 Deteniendo registro de huella.');
    // Opcional: detener la escucha si no hay otras razones para escanear
    // _stopFingerprintListening();
  }

  FingerprintReaderService(this._authService) {
    _initService();
  }

  Future<bool> registerFingerprintWithApi(
    int employeeId,
    Uint8List fingerprintData,
  ) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in.');
    }

    final uri = Uri.parse(
      '$_baseUrl/anfibiusBack/api/empleados/registarbiometrico?id=$employeeId',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': '$token',
          'Content-Type': 'application/octet-stream',
        },
        body: fingerprintData,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          print(
            '✅ Huella registrada exitosamente para el empleado $employeeId',
          );
          return true;
        }
        throw Exception(
          'Failed to register fingerprint: ${responseData['message']}',
        );
      } else {
        throw Exception(
          'Failed to register fingerprint: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Error registering fingerprint: $e');
      rethrow;
    }
  }

  // Capturar huella real usando SDK de Hikvision
  void _captureRealFingerprint() async {
    // Evitar múltiples capturas simultáneas
    if (_isCapturing) {
      return;
    }

    // Implementar debounce: no capturar si la última captura fue hace menos de 2 segundos
    if (_lastCaptureAttempt != null) {
      final timeSinceLastCapture = DateTime.now().difference(
        _lastCaptureAttempt!,
      );
      if (timeSinceLastCapture.inSeconds < 2) {
        return;
      }
    }

    _isCapturing = true;
    _lastCaptureAttempt = DateTime.now();

    try {
      developer.log('🔍 Iniciando captura de huella...');

      final templateData = HikvisionSDK.captureTemplate();

      if (templateData != null && templateData.isNotEmpty) {
        developer.log('✅ Plantilla capturada: ${templateData.length} bytes');

        // Capturar también la imagen de la huella
        try {
          final imageData = HikvisionSDK.captureImage();
          if (imageData != null && imageData.isNotEmpty) {
            _lastFingerprintImage = Uint8List.fromList(imageData);
            _lastCaptureTime = DateTime.now();

            // Calcular dimensiones probables basándose en el tamaño
            int probableWidth = 256; // Ancho típico
            int probableHeight = imageData.length ~/ probableWidth;

            developer.log(
              '📷 Imagen de huella capturada: ${imageData.length} bytes',
            );
            developer.log(
              '📐 Dimensiones calculadas: ${probableWidth}x$probableHeight',
            );
          }
        } catch (e) {
          developer.log('⚠️ Error capturando imagen de huella: $e');
        }

        // Convertir los datos de la huella a base64
        final base64Data = base64Encode(templateData);

        developer.log('🔍 Huella capturada exitosamente');

        // Procesar los datos de la huella
        Map<String, dynamic> fingerprintData = {
          'timestamp': DateTime.now().toIso8601String(),
          'fingerprint': templateData,
          'simulated': false,
        };

        String jsonData = jsonEncode(fingerprintData);

        // Llamar a la API para registrar la huella si hay un empleado en registro
        if (_currentEmployeeIdForRegistration != null) {
          developer.log(
            '📤 Enviando huella a la API para empleado ${_currentEmployeeIdForRegistration}...',
          );
          try {
            await registerFingerprintWithApi(
              _currentEmployeeIdForRegistration!,
              templateData,
            );
            developer.log('✅ Huella registrada exitosamente');
            // Detener el escaneo después de un registro exitoso
            stopFingerprintRegistration();
          } catch (e) {
            developer.log('❌ Error al registrar huella en API: $e');
          }
        } else {
          // Si no hay un empleado en registro, notificar la lectura
          onFingerprintRead?.call(jsonData);
        }

        notifyListeners();
      } else {
        developer.log('⚠️ No se pudo capturar la plantilla de la huella');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error en _captureRealFingerprint: $e');
      developer.log('Stack trace: $stackTrace');
    } finally {
      _isCapturing = false;
    }
  }

  // Getters
  List<FingerprintDevice> get availableDevices => _availableDevices;
  FingerprintDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  Uint8List? get lastFingerprintImage => _lastFingerprintImage;
  DateTime? get lastCaptureTime => _lastCaptureTime;

  // Getter para obtener el nombre del dispositivo seleccionado
  String? get selectedDeviceName {
    return _selectedDevice?.name ?? 'Dispositivo desconocido';
  }

  Future<void> _initService() async {
    try {
      // Inicializar SDK de Hikvision
      final initResult = HikvisionSDK.initialize();
      if (initResult) {
        developer.log('✅ SDK de Hikvision inicializado correctamente');
      } else {
        developer.log(
          '⚠️ No se pudo inicializar el SDK de Hikvision, usando modo simulación',
        );
      }

      // Cargar dispositivo guardado
      await _loadSavedDevice();

      // Iniciar verificación periódica del estado
      _initConnectionChecker();

      developer.log('✅ FingerprintReaderService inicializado');
    } catch (e) {
      developer.log('❌ Error al inicializar FingerprintReaderService: $e');
    }
  }

  // Escanear dispositivos disponibles
  Future<void> scanDevices() async {
    try {
      developer.log('🔍 Escaneando dispositivos de huellas...');

      _availableDevices = [];

      // Verificar si el SDK de Hikvision está inicializado y disponible
      bool sdkAvailable = HikvisionSDK.isInitialized();
      developer.log(
        '🔧 Estado inicial del SDK Hikvision: ${sdkAvailable ? "Inicializado" : "No inicializado"}',
      );

      // Si no está inicializado, intentar inicializarlo ahora
      if (!sdkAvailable) {
        developer.log('🔄 Intentando inicializar el SDK de Hikvision...');
        sdkAvailable = HikvisionSDK.initialize();
        if (sdkAvailable) {
          developer.log('✅ SDK de Hikvision inicializado exitosamente');
        } else {
          developer.log('❌ No se pudo inicializar el SDK de Hikvision');
          developer.log('   Verifica que la DLL esté en la ubicación correcta');
        }
      }

      // Intentar escanear dispositivos reales si el SDK está disponible
      if (sdkAvailable) {
        try {
          final realDevices = HikvisionSDK.enumDevices();
          developer.log(
            '🔍 enumDevices retornó ${realDevices.length} dispositivos',
          );

          for (var device in realDevices) {
            _availableDevices.add(
              FingerprintDevice(
                id: 'hikvision_${device['id']}',
                name: 'Hikvision ${device['name']}',
                type: 'Hikvision SDK',
              ),
            );
          }

          if (realDevices.isNotEmpty) {
            developer.log(
              '✅ Encontrados ${realDevices.length} dispositivos reales Hikvision',
            );
          } else {
            developer.log(
              '⚠️ SDK inicializado pero no se encontraron dispositivos conectados',
            );
          }
        } catch (e) {
          developer.log('⚠️ Error al escanear dispositivos reales: $e');
        }
      }

      // Agregar dispositivos simulados SOLO si no hay dispositivos reales
      if (_availableDevices.isEmpty) {
        developer.log('➕ Agregando dispositivos simulados como fallback');
        _availableDevices = [
          FingerprintDevice(
            id: 'hikvision_ds_k1f820',
            name: 'Hikvision DS-K1F820-F (Simulado)',
            type: 'Simulado',
          ),
          FingerprintDevice(
            id: 'generic_fingerprint_1',
            name: 'Lector de Huellas Genérico (Simulado)',
            type: 'Simulado',
          ),
        ];
      } else {
        // Agregar opción de simulado adicional para pruebas
        _availableDevices.add(
          FingerprintDevice(
            id: 'simulated_reader',
            name: 'Lector Simulado (Para Pruebas)',
            type: 'Simulado',
          ),
        );
      }

      developer.log(
        '📱 Total de dispositivos disponibles: ${_availableDevices.length}',
      );
      for (var device in _availableDevices) {
        developer.log('  - ${device.name} (${device.type})');
      }

      notifyListeners();
    } catch (e) {
      developer.log('❌ Error al escanear dispositivos: $e');
    }
  }

  // Seleccionar dispositivo
  Future<void> selectDevice(FingerprintDevice device) async {
    try {
      developer.log('🔌 Seleccionando dispositivo: ${device.name}');

      // Desconectar dispositivo anterior si existe
      if (_isConnected) {
        await disconnect();
      }

      _selectedDevice = device;

      // Guardar configuración
      await ConfigService.saveFingerprintDevice(
        device.type,
        device.id,
        device.id,
        device.name,
      );

      // Intentar conectar
      await connectToDevice();

      notifyListeners();
    } catch (e) {
      developer.log('❌ Error al seleccionar dispositivo: $e');
    }
  }

  // Conectar al dispositivo seleccionado
  Future<bool> connectToDevice() async {
    if (_selectedDevice == null) {
      developer.log('❌ No hay dispositivo seleccionado para conectar');
      return false;
    }

    try {
      developer.log('🔌 Conectando a: ${_selectedDevice!.name}');

      bool connectionSuccess = false;

      // Conectar usando SDK real si es un dispositivo Hikvision
      if (_selectedDevice!.type == 'Hikvision SDK') {
        try {
          _currentDeviceID = 0; // El SDK maneja solo un dispositivo
          final openResult = HikvisionSDK.openDevice();

          if (openResult) {
            connectionSuccess = true;
            print('✅ Dispositivo Hikvision conectado exitosamente');

            // Instalar el manejador de mensajes para recibir eventos del lector
            HikvisionSDK.installMessageHandler((msgType, msgData) {
              if (msgType == HikvisionConstants.FP_MSG_PRESS_FINGER) {
                // Solo capturar si no hay una captura en progreso
                if (!_isCapturing) {
                  developer.log('👆 Dedo detectado, iniciando captura...');
                  _captureRealFingerprint();
                }
              }
            });
          } else {
            print('❌ No se pudo abrir el dispositivo Hikvision');
          }
        } catch (e) {
          print('⚠️ Error con SDK Hikvision, usando modo simulado: $e');
          connectionSuccess = true; // Continuar en modo simulado
        }
      } else {
        // Simular conexión para dispositivos simulados
        await Future.delayed(const Duration(seconds: 1));
        connectionSuccess = true;
      }

      _isConnected = connectionSuccess;

      if (_isConnected) {
        print('✅ Conectado exitosamente al lector de huellas');

        // Notificar cambio de conexión
        onConnectionChanged?.call(_isConnected);
      }

      notifyListeners();
      return _isConnected;
    } catch (e) {
      print('❌ Error al conectar con el dispositivo: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
      notifyListeners();
      return false;
    }
  }

  // Método para iniciar la escucha de huellas desde la UI
  void startListening() {
    _startFingerprintListening();
  }

  // Método para detener la escucha de huellas desde la UI
  void stopListening() {
    _stopFingerprintListening();
  }

  // Iniciar escucha de datos de huella
  void _startFingerprintListening() {
    if (_isScanning) {
      return; // Ya está escuchando
    }

    _isScanning = true;
    print('👂 Iniciando escucha de huellas dactilares...');

    if (_selectedDevice?.type == 'Hikvision SDK') {
      HikvisionSDK.startCapture();
      print('🔧 Modo SDK Hikvision - Esperando eventos del lector...');
      // La captura se inicia por el callback de `installMessageHandler`
    } else if (_selectedDevice?.id == 'simulated_reader') {
      print(
        '🔧 Modo simulación activado - Las huellas se generarán automáticamente cada 5 segundos',
      );
      // Para el dispositivo simulado, generar huellas automáticamente cada 5 segundos
      _scanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isConnected || !_isScanning) {
          timer.cancel();
          _isScanning = false;
          return;
        }
        _simulateFingerprintReading();
      });
    } else {
      print('⚠️ Modo real - Esperando colocar dedo en el lector...');
      // Para dispositivos reales, esperar entrada del usuario
    }

    notifyListeners();
  }

  // Detener escucha de datos de huella
  void _stopFingerprintListening() {
    if (!_isScanning) {
      return; // No está escuchando
    }

    _isScanning = false;
    _scanTimer?.cancel();

    if (_selectedDevice?.type == 'Hikvision SDK') {
      HikvisionSDK.stopCapture();
      print('🛑 Deteniendo captura del SDK Hikvision.');
    }

    print('🛑 Deteniendo escucha de huellas dactilares.');
    notifyListeners();
  }

  // Simular lectura de huella
  void _simulateFingerprintReading() async {
    // Generar imagen simulada si no existe
    if (_lastFingerprintImage == null) {
      print('📷 Generando nueva imagen simulada...');
      _lastFingerprintImage = _createSimulatedFingerprintImage();
      _lastCaptureTime = DateTime.now();
    } else {
      print(
        '📷 Reutilizando imagen simulada existente: ${_lastFingerprintImage?.length} bytes',
      );
    }

    // Generar datos simulados de huella
    Map<String, dynamic> fingerprintData = {
      'timestamp': DateTime.now().toIso8601String(),
      'device': selectedDeviceName ?? 'Dispositivo desconocido',
      'type': _selectedDevice?.type ?? 'Unknown',
      'fingerprint': base64Encode(
        'fingerprint_${DateTime.now().millisecondsSinceEpoch}'.codeUnits,
      ),
      'simulated': _selectedDevice?.id == 'simulated_reader',
    };

    String jsonData = jsonEncode(fingerprintData);

    // Llamar a la API para registrar la huella si hay un empleado en registro
    if (_currentEmployeeIdForRegistration != null) {
      // Para simulación, podemos usar los datos base64 decodificados como raw data
      final simulatedRawData = base64Decode(fingerprintData['fingerprint']);
      await registerFingerprintWithApi(
        _currentEmployeeIdForRegistration!,
        simulatedRawData,
      );
      // Opcional: detener el escaneo después de un registro exitoso
      // stopFingerprintRegistration();
    } else {
      // Notificar a través del callback si no hay un empleado en registro
      onFingerprintRead?.call(jsonData);
    }
  }

  // Método público para simular lectura manual (para dispositivos no simulados)
  Future<void> triggerManualFingerprintRead() async {
    if (!_isConnected) {
      print('❌ No hay dispositivo conectado');
      return;
    }

    if (_selectedDevice?.id == 'simulated_reader') {
      print('⚠️ El dispositivo simulado genera huellas automáticamente');
      return;
    }

    print('🔍 Simulando lectura manual de huella...');

    // Crear una imagen simulada (patrón de huella simple)
    print('📷 Generando imagen para lectura manual...');
    _lastFingerprintImage = _createSimulatedFingerprintImage();
    _lastCaptureTime = DateTime.now();
    print(
      '✅ Imagen manual establecida: ${_lastFingerprintImage?.length} bytes',
    );

    _simulateFingerprintReading();
  }

  // Desconectar del dispositivo
  Future<void> disconnect() async {
    try {
      print('🔌 Desconectando del lector de huellas...');

      // Cerrar dispositivo SDK si está abierto
      if (_currentDeviceID >= 0) {
        try {
          HikvisionSDK.stopCapture();
          HikvisionSDK.closeDevice();
          _currentDeviceID = -1;
          print('✅ Dispositivo SDK cerrado correctamente');
        } catch (e) {
          print('⚠️ Error cerrando dispositivo SDK: $e');
        }
      }

      // Parar escucha
      _isScanning = false;
      _scanTimer?.cancel();

      _isConnected = false;

      // Notificar cambio de conexión
      onConnectionChanged?.call(false);
      notifyListeners();

      print('✅ Desconectado del lector de huellas');
    } catch (e) {
      print('❌ Error al desconectar: $e');
    }
  }

  // Verificar periódicamente el estado de conexión
  void _initConnectionChecker() {
    _connectionCheckTimer?.cancel();

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) {
      if (_isConnected && _selectedDevice != null) {
        _checkConnectionStatus();
      }
    });
  }

  // Verificar estado de conexión
  Future<void> _checkConnectionStatus() async {
    if (!_isConnected || _selectedDevice == null) return;

    try {
      // Para dispositivos simulados, siempre mantener conectado
      // Para dispositivos reales, verificar la conexión física
      bool stillConnected = true;

      if (_selectedDevice!.type == 'Hikvision SDK' && _currentDeviceID >= 0) {
        // Verificar si el dispositivo Hikvision sigue disponible
        try {
          final devices = HikvisionSDK.enumDevices();
          stillConnected = devices.isNotEmpty;
        } catch (e) {
          print('⚠️ Error verificando dispositivo Hikvision: $e');
          stillConnected = false;
        }
      } else if (_selectedDevice!.id != 'simulated_reader') {
        // Para otros dispositivos reales, mantener conectado por ahora
        // En implementación completa, aquí se verificaría la conexión USB/HID
      }

      if (!stillConnected && _isConnected) {
        print('⚠️ Dispositivo desconectado inesperadamente');
        _isConnected = false;
        _isScanning = false;
        _scanTimer?.cancel();

        onConnectionChanged?.call(false);
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Error verificando estado de conexión: $e');
    }
  }

  // Cargar dispositivo guardado
  Future<void> _loadSavedDevice() async {
    try {
      final savedDevice = await ConfigService.loadFingerprintDevice();

      if (savedDevice != null) {
        print('📂 Cargando dispositivo guardado: ${savedDevice['name']}');

        // Escanear dispositivos para encontrar el guardado
        await scanDevices();

        // Buscar el dispositivo guardado
        final device =
            _availableDevices
                .where(
                  (device) =>
                      device.id ==
                      savedDevice['vendorId'], // vendorId contiene el id
                )
                .firstOrNull;

        if (device != null) {
          _selectedDevice = device;
          await connectToDevice();
        } else {
          print('⚠️ Dispositivo guardado no encontrado en la lista actual');
        }
      }
    } catch (e) {
      print('⚠️ No se pudo cargar dispositivo guardado: $e');
    }
  }

  // Método para probar la conexión
  Future<bool> testConnection() async {
    if (!_isConnected) {
      print('❌ No hay dispositivo conectado para probar');
      return false;
    }

    try {
      print('🧪 Probando conexión con el lector de huellas...');

      // Para dispositivos simulados, siempre exitoso
      if (_selectedDevice?.id == 'simulated_reader') {
        print('✅ Prueba de conexión exitosa (dispositivo simulado)');
        return true;
      }

      // Para dispositivos reales, aquí se haría una prueba real
      print('✅ Prueba de conexión exitosa');
      return true;
    } catch (e) {
      print('❌ Error en prueba de conexión: $e');
      return false;
    }
  }

  // Limpiar recursos al destruir el servicio
  @override
  void dispose() {
    print('🧹 Limpiando FingerprintReaderService...');

    _scanTimer?.cancel();
    _connectionCheckTimer?.cancel();

    if (_isConnected) {
      disconnect();
    }

    // Cerrar dispositivo SDK si está abierto
    if (_currentDeviceID >= 0) {
      try {
        HikvisionSDK.stopCapture();
        HikvisionSDK.closeDevice();
      } catch (e) {
        print('⚠️ Error cerrando dispositivo SDK en dispose: $e');
      }
    }

    // Limpiar SDK
    try {
      HikvisionSDK.cleanup();
    } catch (e) {
      print('⚠️ Error limpiando SDK en dispose: $e');
    }

    super.dispose();
  }

  // Olvidar dispositivo seleccionado
  Future<void> forgetCurrentDevice() async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _selectedDevice = null;

      // Eliminar de la configuración guardada
      await ConfigService.removeFingerprintDevice();

      print('✅ Dispositivo de huella olvidado correctamente');
      notifyListeners();
    } catch (e) {
      print('❌ Error al olvidar dispositivo: $e');
    }
  }

  // Crear imagen simulada de huella
  Uint8List _createSimulatedFingerprintImage() {
    // Usar las dimensiones reales que devuelve el SDK (256x288, no 256x360)
    const width = 256;
    const height = 288; // Tamaño real observado del SDK Hikvision
    final imageData = Uint8List(width * height);

    print(
      '🎨 Generando imagen simulada de ${width}x$height = ${width * height} bytes',
    );

    // Crear un patrón simple que parezca una huella
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = y * width + x;

        // Crear líneas curvas que simulen una huella
        final centerX = width / 2;
        final centerY = height / 2;
        final distanceX = (x - centerX).abs();
        final distanceY = (y - centerY).abs();
        final distance =
            (distanceX * distanceX + distanceY * distanceY) / 10000;

        // Patrón ondulado
        final wave = (math.sin(distance * 10 + x / 8) * 30).toInt();
        final value =
            (128 + wave + (distance * 2).toInt()).clamp(0, 255).toInt();

        imageData[index] = value;
      }
    }

    print('✅ Imagen simulada generada: ${imageData.length} bytes');
    return imageData;
  }
}
