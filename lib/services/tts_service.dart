import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  bool _isInitialized = false;
  bool _isEnabled = true;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // No-op initialize: PowerShell invocation doesn't need init
    _isInitialized = true;
    developer.log('✅ Servicio TTS (PowerShell) listo');
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    developer.log('🔊 TTS ${enabled ? "HABILITADO" : "DESHABILITADO"}');
  }

  Future<void> sayWelcome(
    String nombre,
    String apellido, {
    bool multado = false,
  }) async {
    final saludo = _greetingForHour();
    var mensaje = '$saludo $nombre $apellido';
    if (multado) mensaje += '. Se ha registrado una multa por su tardanza.';
    await _speak(mensaje);
  }

  Future<void> sayEntrance(
    String nombre,
    String apellido, {
    bool multado = false,
  }) async {
    final saludo = _greetingForHour();
    var mensaje = '$saludo $nombre $apellido. Bienvenido.';
    if (multado)
      mensaje += ' Atención: se ha registrado una multa por su tardanza.';
    await _speak(mensaje);
  }

  Future<void> sayExit(String nombre, String apellido) async {
    final mensaje = 'Hasta luego $nombre $apellido. Que tenga un buen día.';
    await _speak(mensaje);
  }

  Future<void> sayError(String mensaje) async {
    await _speak(mensaje);
  }

  Future<void> sayFingerprintNotRecognized() async {
    await sayError('Huella no reconocida. Por favor, intente nuevamente.');
  }

  Future<void> say(String mensaje) async {
    await _speak(mensaje);
  }

  String _greetingForHour() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _speak(String text) async {
    if (!_isEnabled) return;
    if (!_isInitialized) await initialize();

    try {
      developer.log('🔊 TTS: $text');

      if (Platform.isWindows) {
        // Escape double quotes for PowerShell
        final escaped = text.replaceAll('"', '`"');
        final ps =
            '[reflection.assembly]::loadwithpartialname("System.Speech") | Out-Null; '
            '(New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak("$escaped");';

        // Use Start-Process to avoid blocking the Dart process and to run in background
        await Process.start('powershell', ['-NoProfile', '-Command', ps]);
      } else if (Platform.isMacOS) {
        // macOS `say` command
        await Process.start('say', [text]);
      } else if (Platform.isLinux) {
        // Try `spd-say` (common) or fallback to espeak if available
        if (await _which('spd-say')) {
          await Process.start('spd-say', [text]);
        } else if (await _which('espeak')) {
          await Process.start('espeak', [text]);
        } else {
          developer.log('⚠️ Ningún TTS disponible en Linux (spd-say/espeak)');
        }
      } else {
        developer.log('⚠️ Plataforma TTS no soportada');
      }
    } catch (e) {
      developer.log('❌ Error al intentar reproducir TTS: $e');
    }
  }

  Future<bool> _which(String cmd) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', [cmd]);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('which', [cmd]);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    // No-op
  }

  void dispose() {
    // No-op
  }
}
