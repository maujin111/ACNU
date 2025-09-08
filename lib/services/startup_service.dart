import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupService extends ChangeNotifier {
  static final StartupService _instance = StartupService._internal();
  factory StartupService() => _instance;
  StartupService._internal();

  bool _isEnabled = false;
  bool _isInitialized = false;
  String? _lastError;

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  // Inicializar y cargar la configuración
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('start_with_windows') ?? false;

      // Obtener el estado actual del inicio automático
      final isAtStartupEnabled = await launchAtStartup.isEnabled();

      // Sincronizar el estado almacenado con el estado real
      if (_isEnabled != isAtStartupEnabled) {
        debugPrint(
          'Sincronizando estado de inicio automático: $_isEnabled -> $isAtStartupEnabled',
        );
        await _updateStartupSetting(_isEnabled);
      }

      _isInitialized = true;
      _lastError = null;
      debugPrint(
        'StartupService inicializado correctamente. Estado: $_isEnabled',
      );
    } catch (e) {
      _lastError = 'Error al inicializar StartupService: $e';
      debugPrint(_lastError);
      _isInitialized = true; // Marcar como inicializado aunque haya error
    }

    notifyListeners();
  }

  // Cambiar la configuración de inicio automático
  Future<void> toggleStartupSetting() async {
    if (!_isInitialized) {
      _lastError = 'El servicio no ha sido inicializado';
      debugPrint(_lastError);
      return;
    }

    try {
      _isEnabled = !_isEnabled;
      await _updateStartupSetting(_isEnabled);
      _lastError = null;
      debugPrint('Estado de inicio automático cambiado a: $_isEnabled');
    } catch (e) {
      // Revertir el cambio si hay error
      _isEnabled = !_isEnabled;
      _lastError = 'Error al cambiar configuración de inicio: $e';
      debugPrint(_lastError);
    }

    notifyListeners();
  }

  // Actualizar la configuración de inicio automático
  Future<void> _updateStartupSetting(bool enabled) async {
    try {
      // Guardar la configuración en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('start_with_windows', enabled);

      // Actualizar la configuración del sistema
      if (enabled) {
        await launchAtStartup.enable();
        debugPrint('Inicio automático habilitado en el sistema');
      } else {
        await launchAtStartup.disable();
        debugPrint('Inicio automático deshabilitado en el sistema');
      }

      // Verificar que el cambio se aplicó correctamente
      final actualState = await launchAtStartup.isEnabled();
      if (actualState != enabled) {
        throw Exception(
          'El estado del sistema ($actualState) no coincide con el esperado ($enabled)',
        );
      }
    } catch (e) {
      debugPrint('Error en _updateStartupSetting: $e');
      rethrow;
    }
  }

  // Método para verificar el estado actual
  Future<bool> checkCurrentState() async {
    try {
      final systemState = await launchAtStartup.isEnabled();
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getBool('start_with_windows') ?? false;

      debugPrint(
        'Estado del sistema: $systemState, Estado guardado: $savedState',
      );

      if (systemState != savedState) {
        debugPrint('Inconsistencia detectada, sincronizando...');
        _isEnabled = systemState;
        await prefs.setBool('start_with_windows', systemState);
        notifyListeners();
      }

      return systemState;
    } catch (e) {
      debugPrint('Error al verificar estado actual: $e');
      return false;
    }
  }
}
