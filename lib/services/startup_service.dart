import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupService extends ChangeNotifier {
  static final StartupService _instance = StartupService._internal();
  factory StartupService() => _instance;
  StartupService._internal();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  // Inicializar y cargar la configuración
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('start_with_windows') ?? false;

    // Obtener el estado actual del inicio automático
    final isAtStartupEnabled = await launchAtStartup.isEnabled();

    // Sincronizar el estado almacenado con el estado real
    if (_isEnabled != isAtStartupEnabled) {
      await _updateStartupSetting(_isEnabled);
    }

    notifyListeners();
  }

  // Cambiar la configuración de inicio automático
  Future<void> toggleStartupSetting() async {
    _isEnabled = !_isEnabled;
    await _updateStartupSetting(_isEnabled);
    notifyListeners();
  }

  // Actualizar la configuración de inicio automático
  Future<void> _updateStartupSetting(bool enabled) async {
    // Guardar la configuración en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('start_with_windows', enabled);

    // Actualizar la configuración del sistema
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
