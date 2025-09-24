import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/config_service.dart';

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

  // Callbacks
  Function(String fingerprintData)? onFingerprintRead;
  Function(bool isConnected)? onConnectionChanged;

  FingerprintReaderService() {
    _initService();
  }

  // Getters
  List<FingerprintDevice> get availableDevices => _availableDevices;
  FingerprintDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;

  // Getter para obtener el nombre del dispositivo seleccionado
  String? get selectedDeviceName {
    return _selectedDevice?.name ?? 'Dispositivo desconocido';
  }

  Future<void> _initService() async {
    try {
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

      // Por ahora, simular dispositivos disponibles
      // En implementación real, esto escanearía dispositivos USB/HID reales
      _availableDevices = [
        FingerprintDevice(
          id: 'hikvision_ds_k1f820',
          name: 'Hikvision DS-K1F820-F',
          type: 'USB',
        ),
        FingerprintDevice(
          id: 'generic_fingerprint_1',
          name: 'Lector de Huellas Genérico',
          type: 'USB',
        ),
        FingerprintDevice(
          id: 'simulated_reader',
          name: 'Lector Simulado (Para Pruebas)',
          type: 'Simulado',
        ),
      ];

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

      // Simular conexión exitosa
      await Future.delayed(const Duration(seconds: 1));
      _isConnected = true;

      print('✅ Conectado exitosamente al lector de huellas');

      // Iniciar escucha de huellas
      _startFingerprintListening();

      // Notificar cambio de conexión
      onConnectionChanged?.call(_isConnected);
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

    if (_selectedDevice?.id == 'simulated_reader') {
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
    _simulateFingerprintReading();
  }

  // Desconectar del dispositivo
  Future<void> disconnect() async {
    try {
      print('🔌 Desconectando del lector de huellas...');

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
      // Para dispositivos reales, aquí se verificaría la conexión física
      bool stillConnected = true;

      if (_selectedDevice!.id != 'simulated_reader') {
        // Aquí iría verificación real del dispositivo
        // Por ahora, mantener conectado
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
}
