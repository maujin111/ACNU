import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Modelo para representar un objetivo
class Objetivo {
  final String id;
  final String descripcion;
  final bool completado;
  final DateTime ultimaActualizacion;

  Objetivo({
    required this.id,
    required this.descripcion,
    required this.completado,
    required this.ultimaActualizacion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descripcion': descripcion,
      'completado': completado,
      'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
    };
  }

  factory Objetivo.fromJson(Map<String, dynamic> json) {
    return Objetivo(
      id: json['id'] ?? '',
      descripcion: json['descripcion'] ?? '',
      completado: json['completado'] ?? false,
      ultimaActualizacion:
          DateTime.tryParse(json['ultimaActualizacion'] ?? '') ??
          DateTime.now(),
    );
  }

  Objetivo copyWith({
    String? id,
    String? descripcion,
    bool? completado,
    DateTime? ultimaActualizacion,
  }) {
    return Objetivo(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      completado: completado ?? this.completado,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
    );
  }
}

class ObjetivosService extends ChangeNotifier {
  static const String _fileName = 'objetivos.json';

  // Lista de objetivos predefinidos
  final Map<String, Objetivo> _objetivos = {
    'detectar_huella': Objetivo(
      id: 'detectar_huella',
      descripcion:
          'Detectar automáticamente la huella al colocar el dedo en el lector',
      completado: false,
      ultimaActualizacion: DateTime.now(),
    ),
    'enviar_websocket': Objetivo(
      id: 'enviar_websocket',
      descripcion:
          'Enviar la lectura de la huella como cadena de texto a un WebSocket en tiempo real',
      completado: false,
      ultimaActualizacion: DateTime.now(),
    ),
    'registrar_estado': Objetivo(
      id: 'registrar_estado',
      descripcion:
          'Registrar en un documento interno el estado de cada objetivo (pendiente / completado)',
      completado: false,
      ultimaActualizacion: DateTime.now(),
    ),
  };

  ObjetivosService() {
    _initService();
  }

  // Getters
  Map<String, Objetivo> get objetivos => Map.unmodifiable(_objetivos);

  List<Objetivo> get objetivosList => _objetivos.values.toList();

  int get completados =>
      _objetivos.values.where((obj) => obj.completado).length;

  int get total => _objetivos.length;

  double get progreso => total > 0 ? completados / total : 0.0;

  Future<void> _initService() async {
    try {
      await _loadObjetivos();
      print('✅ ObjetivosService inicializado');
    } catch (e) {
      print('❌ Error al inicializar ObjetivosService: $e');
    }
  }

  // Obtener el archivo de objetivos
  Future<File> _getObjetivosFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      return file;
    } catch (e) {
      // Fallback para plataformas que no soporten path_provider
      final file = File(_fileName);
      return file;
    }
  }

  // Cargar objetivos desde el archivo
  Future<void> _loadObjetivos() async {
    try {
      final file = await _getObjetivosFile();

      if (!await file.exists()) {
        // Si no existe el archivo, crear con objetivos por defecto
        await _saveObjetivos();
        return;
      }

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;

      // Cargar objetivos desde el archivo y actualizar el mapa
      for (final entry in data.entries) {
        if (_objetivos.containsKey(entry.key)) {
          _objetivos[entry.key] = Objetivo.fromJson(entry.value);
        }
      }

      print('📂 Objetivos cargados desde ${file.path}');
    } catch (e) {
      print('⚠️ Error al cargar objetivos: $e');
      // En caso de error, usar objetivos por defecto
    }
  }

  // Guardar objetivos en el archivo
  Future<void> _saveObjetivos() async {
    try {
      final file = await _getObjetivosFile();

      final data = <String, dynamic>{};
      for (final entry in _objetivos.entries) {
        data[entry.key] = entry.value.toJson();
      }

      await file.writeAsString(jsonEncode(data));
      print('💾 Objetivos guardados en ${file.path}');
    } catch (e) {
      print('❌ Error al guardar objetivos: $e');
    }
  }

  // Marcar un objetivo como completado
  Future<void> completarObjetivo(String objetivoId) async {
    if (_objetivos.containsKey(objetivoId)) {
      final objetivo = _objetivos[objetivoId]!;

      if (!objetivo.completado) {
        _objetivos[objetivoId] = objetivo.copyWith(
          completado: true,
          ultimaActualizacion: DateTime.now(),
        );

        print('✅ Objetivo completado: ${objetivo.descripcion}');

        await _saveObjetivos();
        notifyListeners();

        // Verificar si todos los objetivos están completados
        if (completados == total) {
          print('🎉 ¡Todos los objetivos completados!');
        }
      }
    }
  }

  // Marcar un objetivo como pendiente
  Future<void> marcarPendiente(String objetivoId) async {
    if (_objetivos.containsKey(objetivoId)) {
      final objetivo = _objetivos[objetivoId]!;

      if (objetivo.completado) {
        _objetivos[objetivoId] = objetivo.copyWith(
          completado: false,
          ultimaActualizacion: DateTime.now(),
        );

        print('📋 Objetivo marcado como pendiente: ${objetivo.descripcion}');

        await _saveObjetivos();
        notifyListeners();
      }
    }
  }

  // Resetear todos los objetivos
  Future<void> resetearObjetivos() async {
    for (final key in _objetivos.keys) {
      final objetivo = _objetivos[key]!;
      _objetivos[key] = objetivo.copyWith(
        completado: false,
        ultimaActualizacion: DateTime.now(),
      );
    }

    print('🔄 Todos los objetivos reseteados');

    await _saveObjetivos();
    notifyListeners();
  }

  // Obtener resumen del progreso
  String getResumenProgreso() {
    return '$completados de $total objetivos completados (${(progreso * 100).toStringAsFixed(1)}%)';
  }

  // Verificar si un objetivo específico está completado
  bool isObjetivoCompletado(String objetivoId) {
    return _objetivos[objetivoId]?.completado ?? false;
  }

  // Obtener información de un objetivo específico
  Objetivo? getObjetivo(String objetivoId) {
    return _objetivos[objetivoId];
  }

  @override
  void dispose() {
    print('🧹 Limpiando ObjetivosService...');
    super.dispose();
  }
}
