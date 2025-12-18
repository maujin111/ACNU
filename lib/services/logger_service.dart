import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Servicio para guardar logs en archivo
/// Mantiene los últimos 7 días de logs y rota archivos automáticamente
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _currentLogFile;
  IOSink? _logSink;
  String? _currentDate;
  final _logBuffer = <String>[];
  Timer? _flushTimer;
  bool _isInitialized = false;

  // Configuración
  static const int maxLogFiles = 7; // Mantener logs de los últimos 7 días
  static const int maxBufferSize = 50; // Flush cada 50 líneas
  static const Duration flushInterval = Duration(seconds: 30); // O cada 30 segundos

  /// Inicializar el servicio de logging
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _initLogFile();
      
      // Timer para flush periódico
      _flushTimer = Timer.periodic(flushInterval, (_) => _flushBuffer());
      
      _isInitialized = true;
      log('📝 Logger Service iniciado correctamente');
    } catch (e) {
      print('❌ Error inicializando Logger Service: $e');
    }
  }

  /// Inicializar archivo de log
  Future<void> _initLogFile() async {
    try {
      final directory = await _getLogDirectory();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Si cambió el día, crear nuevo archivo
      if (_currentDate != today) {
        await _closeCurrentFile();
        
        _currentDate = today;
        final fileName = 'anfibius_log_$today.txt';
        _currentLogFile = File('${directory.path}/$fileName');
        
        // Crear archivo si no existe
        if (!await _currentLogFile!.exists()) {
          await _currentLogFile!.create(recursive: true);
          await _currentLogFile!.writeAsString(
            '${'=' * 80}\n'
            'ANFIBIUS CONNECT NEXUS UTILITY - LOG\n'
            'Fecha: $today\n'
            'Inicio de sesión: ${DateFormat('HH:mm:ss').format(DateTime.now())}\n'
            '${'=' * 80}\n\n',
          );
        }
        
        _logSink = _currentLogFile!.openWrite(mode: FileMode.append);
        
        // Limpiar logs antiguos
        await _cleanOldLogs(directory);
      }
    } catch (e) {
      print('❌ Error inicializando archivo de log: $e');
    }
  }

  /// Obtener directorio de logs
  Future<Directory> _getLogDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDocDir.path}/anfibius_logs');
    
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    return logDir;
  }

  /// Limpiar logs antiguos (mantener solo los últimos X días)
  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final files = await logDir.list().toList();
      final now = DateTime.now();
      
      for (var file in files) {
        if (file is File && file.path.contains('anfibius_log_')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > maxLogFiles) {
            await file.delete();
            print('🗑️ Log antiguo eliminado: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('❌ Error limpiando logs antiguos: $e');
    }
  }

  /// Cerrar archivo actual
  Future<void> _closeCurrentFile() async {
    try {
      await _flushBuffer();
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;
      _currentLogFile = null;
    } catch (e) {
      print('❌ Error cerrando archivo de log: $e');
    }
  }

  /// Escribir log en buffer
  void log(String message, {String level = 'INFO'}) {
    if (!_isInitialized) {
      print(message); // Fallback a consola
      return;
    }

    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final logLine = '[$timestamp] [$level] $message';
    
    // Imprimir en consola también
    print(logLine);
    
    // Agregar a buffer
    _logBuffer.add(logLine);
    
    // Flush si el buffer está lleno
    if (_logBuffer.length >= maxBufferSize) {
      _flushBuffer();
    }
  }

  /// Escribir log de error
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log('❌ $message', level: 'ERROR');
    if (error != null) {
      log('   Error: $error', level: 'ERROR');
    }
    if (stackTrace != null) {
      log('   Stack trace: $stackTrace', level: 'ERROR');
    }
  }

  /// Escribir log de warning
  void warning(String message) {
    log('⚠️ $message', level: 'WARN');
  }

  /// Escribir log de info
  void info(String message) {
    log('ℹ️ $message', level: 'INFO');
  }

  /// Escribir log de debug
  void debug(String message) {
    log('🐛 $message', level: 'DEBUG');
  }

  /// Escribir log de éxito
  void success(String message) {
    log('✅ $message', level: 'SUCCESS');
  }

  /// Flush buffer a archivo
  Future<void> _flushBuffer() async {
    if (_logBuffer.isEmpty) return;

    try {
      // Verificar si cambió el día
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_currentDate != today) {
        await _initLogFile();
      }

      if (_logSink != null) {
        for (final line in _logBuffer) {
          _logSink!.writeln(line);
        }
        await _logSink!.flush();
      }
      
      _logBuffer.clear();
    } catch (e) {
      print('❌ Error escribiendo logs a archivo: $e');
    }
  }

  /// Obtener contenido de los logs del día actual
  Future<String> getCurrentLogs() async {
    try {
      await _flushBuffer(); // Asegurar que todo esté escrito
      
      if (_currentLogFile != null && await _currentLogFile!.exists()) {
        return await _currentLogFile!.readAsString();
      }
      
      return 'No hay logs disponibles para hoy.';
    } catch (e) {
      return 'Error leyendo logs: $e';
    }
  }

  /// Obtener lista de archivos de log
  Future<List<File>> getLogFiles() async {
    try {
      final directory = await _getLogDirectory();
      final files = await directory
          .list()
          .where((file) => file is File && file.path.contains('anfibius_log_'))
          .cast<File>()
          .toList();
      
      // Ordenar por fecha (más reciente primero)
      files.sort((a, b) => b.path.compareTo(a.path));
      
      return files;
    } catch (e) {
      print('❌ Error obteniendo archivos de log: $e');
      return [];
    }
  }

  /// Obtener ruta del directorio de logs
  Future<String> getLogDirectoryPath() async {
    final directory = await _getLogDirectory();
    return directory.path;
  }

  /// Exportar logs a un archivo específico
  Future<File?> exportLogs(String destinationPath) async {
    try {
      await _flushBuffer();
      
      if (_currentLogFile != null && await _currentLogFile!.exists()) {
        final destination = File(destinationPath);
        await _currentLogFile!.copy(destination.path);
        return destination;
      }
      
      return null;
    } catch (e) {
      print('❌ Error exportando logs: $e');
      return null;
    }
  }

  /// Limpiar todos los logs
  Future<void> clearAllLogs() async {
    try {
      final directory = await _getLogDirectory();
      final files = await directory.list().toList();
      
      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }
      
      log('🗑️ Todos los logs han sido eliminados');
    } catch (e) {
      print('❌ Error limpiando logs: $e');
    }
  }

  /// Cerrar el servicio de logging
  Future<void> dispose() async {
    try {
      _flushTimer?.cancel();
      _flushTimer = null;
      await _flushBuffer();
      await _closeCurrentFile();
      _logBuffer.clear();
      _isInitialized = false;
    } catch (e) {
      print('❌ Error en dispose de logger: $e');
    }
  }
}

// Instancia global para fácil acceso
final logger = LoggerService();
