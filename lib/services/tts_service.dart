import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isEnabled = true;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Obtener TODOS los idiomas instalados en la PC del cliente
      List<dynamic> installedLanguages = await _flutterTts.getLanguages;
      developer.log('🌐 Idiomas detectados en esta PC: $installedLanguages');

      String? bestSpanishVoice;

      // 2. Buscar un paquete de Español
      for (var lang in installedLanguages) {
        String langStr = lang.toString().toLowerCase();

        if (langStr.startsWith("es")) {
          bestSpanishVoice = lang.toString();
          if (langStr.contains("us") || langStr.contains("mx")) {
            break;
          }
        }
      }

      // 3. Aplicar el idioma
      if (bestSpanishVoice != null) {
        await _flutterTts.setLanguage(bestSpanishVoice);
        developer.log(
          '✅ Idioma TTS configurado automáticamente a: $bestSpanishVoice',
        );
      } else {
        developer.log(
          '⚠️ ADVERTENCIA: Esta computadora no tiene voces en Español instaladas.',
        );
        developer.log(
          '⚠️ El sistema usará la voz por defecto (posiblemente en Inglés).',
        );
      }

      // 4. Ajustar la velocidad y tono para que suene natural
      await _flutterTts.setSpeechRate(0.5); // Velocidad normal
      await _flutterTts.setPitch(1.0); // Tono de voz normal

      _isInitialized = true;
    } catch (e) {
      developer.log('❌ Error inicializando TTS: $e');
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    developer.log('🔊 TTS ${enabled ? "HABILITADO" : "DESHABILITADO"}');
  }

  Future<void> sayMarca({
    required String tipo, // EM | SA | EA | SF
    required String nombres,
    required String apellidos,
    bool multado = false,
  }) async {
    switch (tipo) {
      case 'EM':
        await _sayEntrada(nombres, apellidos, multado: multado);
        break;
      case 'SA':
        await _saySalidaAlmuerzo(nombres, apellidos);
        break;
      case 'EA':
        await _sayEntradaAlmuerzo(nombres, apellidos, multado: multado);
        break;
      case 'SF':
        await _saySalidaFinal(nombres, apellidos);
        break;
      default:
        await _speak('Asistencia registrada. $nombres $apellidos.');
    }
  }

  // EM — Entrada al trabajo
  Future<void> _sayEntrada(
    String nombre,
    String apellido, {
    bool multado = false,
  }) async {
    final saludo = _greetingForHour();
    var mensaje = '$saludo, $nombre $apellido. Entrada registrada.';
    if (multado) {
      mensaje += ' Se ha generado una multa por ingreso tardío.';
    }
    await _speak(mensaje);
  }

  // SA — Salida a almuerzo
  Future<void> _saySalidaAlmuerzo(String nombre, String apellido) async {
    await _speak('Salida a almuerzo registrada. $nombre $apellido.');
  }

  // EA — Regreso de almuerzo
  Future<void> _sayEntradaAlmuerzo(
    String nombre,
    String apellido, {
    bool multado = false,
  }) async {
    var mensaje = 'Regreso de almuerzo registrado. $nombre $apellido.';
    if (multado) {
      mensaje += ' Se ha generado una multa por retorno tardío.';
    }
    await _speak(mensaje);
  }

  // SF — Salida final del día
  Future<void> _saySalidaFinal(String nombre, String apellido) async {
    await _speak('Hasta luego, $nombre $apellido.');
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
    if (multado) {
      mensaje += '. Atención: se ha registrado una multa por su tardanza.';
    }
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
    await sayError('Huella no reconocida.');
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
      developer.log('🔊 TTS hablando: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      developer.log('❌ Error al intentar reproducir TTS: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
