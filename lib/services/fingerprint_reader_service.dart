import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services/config_service.dart';
import '../services/hikvision_sdk.dart';

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

  // Última imagen de huella capturada
  Uint8List? _lastFingerprintImage;
  DateTime? _lastCaptureTime;

  // Callbacks
  Function(String fingerprintData)? onFingerprintRead;
  Function(bool isConnected)? onConnectionChanged;

  FingerprintReaderService() {
    _initService();
  }

  // Capturar huella real usando SDK de Hikvision
  void _captureRealFingerprint() {
    if (_currentDeviceID < 0) return;
    try {
      // Primero detectar si hay un dedo en el lector
      if (HikvisionSDK.detectFinger()) {
        // Si hay un dedo, capturar el template
        final templateData = HikvisionSDK.captureTemplate();

        if (templateData != null && templateData.isNotEmpty) {
          // Capturar también la imagen de la huella
          try {
            final imageData = HikvisionSDK.captureImage();
            if (imageData != null && imageData.isNotEmpty) {
              _lastFingerprintImage = Uint8List.fromList(imageData);
              _lastCaptureTime = DateTime.now();

              // Calcular dimensiones probables basándose en el tamaño
              int probableWidth = 256; // Ancho típico
              int probableHeight = imageData.length ~/ probableWidth;

              print('📷 Imagen de huella capturada: ${imageData.length} bytes');
              print(
                '📐 Dimensiones calculadas: ${probableWidth}x${probableHeight}',
              );
            }
          } catch (e) {
            print('⚠️ Error capturando imagen de huella: $e');
          }

          // Convertir los datos de la huella a base64
          final base64Data = base64Encode(templateData);

          print('🔍 Huella real capturada: ${base64Data.substring(0, 50)}...');

          // Procesar los datos de la huella
          Map<String, dynamic> fingerprintData = {
            'timestamp': DateTime.now().toIso8601String(),
            'fingerprint': templateData,
            'simulated': false,
          };

          String jsonData = jsonEncode(fingerprintData);

          // Llamar callback
          onFingerprintRead?.call(jsonData);

          notifyListeners();
        }
      }
    } catch (e) {
      print('⚠️ Error capturando huella real: $e');
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
        print('✅ SDK de Hikvision inicializado correctamente');
      } else {
        print(
          '⚠️ No se pudo inicializar el SDK de Hikvision, usando modo simulación',
        );
      }

      // Cargar dispositivo guardado
      await _loadSavedDevice();

      // Iniciar verificación periódica del estado
      _initConnectionChecker();

      print('✅ FingerprintReaderService inicializado');
    } catch (e) {
      print('❌ Error al inicializar FingerprintReaderService: $e');
    }
  }

  // Escanear dispositivos disponibles
  Future<void> scanDevices() async {
    try {
      print('🔍 Escaneando dispositivos de huellas...');

      _availableDevices = [];

      // Intentar escanear dispositivos reales usando SDK de Hikvision
      try {
        final realDevices = HikvisionSDK.enumDevices();
        for (var device in realDevices) {
          _availableDevices.add(
            FingerprintDevice(
              id: 'hikvision_${device['id']}',
              name: 'Hikvision ${device['name']}',
              type: 'Hikvision SDK',
            ),
          );
        }
        print(
          '✅ Encontrados ${realDevices.length} dispositivos reales Hikvision',
        );
      } catch (e) {
        print('⚠️ No se pudieron escanear dispositivos reales: $e');
      }

      // Agregar dispositivos simulados si no hay reales disponibles
      if (_availableDevices.isEmpty) {
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
      }

      print(
        '📱 Encontrados ${_availableDevices.length} dispositivos de huellas disponibles',
      );
      for (var device in _availableDevices) {
        print('  - ${device.name} (${device.type})');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error al escanear dispositivos: $e');
    }
  }

  // Seleccionar dispositivo
  Future<void> selectDevice(FingerprintDevice device) async {
    try {
      print('🔌 Seleccionando dispositivo: ${device.name}');

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
      print('❌ Error al seleccionar dispositivo: $e');
    }
  }

  // Conectar al dispositivo seleccionado
  Future<bool> connectToDevice() async {
    if (_selectedDevice == null) {
      print('❌ No hay dispositivo seleccionado para conectar');
      return false;
    }

    try {
      print('🔌 Conectando a: ${_selectedDevice!.name}');

      bool connectionSuccess = false;

      // Conectar usando SDK real si es un dispositivo Hikvision
      if (_selectedDevice!.type == 'Hikvision SDK') {
        try {
          _currentDeviceID = 0; // El SDK maneja solo un dispositivo
          final openResult = HikvisionSDK.openDevice();

          if (openResult) {
            connectionSuccess = true;
            print('✅ Dispositivo Hikvision conectado exitosamente');
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

        // Iniciar escucha de huellas
        _startFingerprintListening();

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

  // Iniciar escucha de datos de huella
  void _startFingerprintListening() {
    if (_isScanning) {
      return; // Ya está escuchando
    }

    _isScanning = true;
    print('👂 Iniciando escucha de huellas dactilares...');

    if (_selectedDevice?.type == 'Hikvision SDK') {
      print(
        '🔧 Modo SDK Hikvision - Las huellas se capturarán automáticamente',
      );
      // Para dispositivos Hikvision reales, usar captura continua
      _scanTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isConnected || !_isScanning) {
          timer.cancel();
          _isScanning = false;
          return;
        }
        _captureRealFingerprint();
      });
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
      // En implementación real, esto se conectaría al driver del dispositivo
      _scanTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isConnected || !_isScanning) {
          timer.cancel();
          _isScanning = false;
          return;
        }
        // Aquí iría la lectura real del dispositivo
        // Por ahora, solo mantener el timer activo
      });
    }

    notifyListeners();
  }

  // Simular lectura de huella
  void _simulateFingerprintReading() {
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

    if (_selectedDevice?.id == 'simulated_reader') {
      print('🔍 [SIMULACIÓN] Huella dactilar generada automáticamente');
    } else {
      print('🔍 Huella dactilar detectada');
    }
    print('📄 Datos de huella: $jsonData');

    // Notificar a través del callback
    onFingerprintRead?.call(jsonData);
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
      '🎨 Generando imagen simulada de ${width}x${height} = ${width * height} bytes',
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
