import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:anfibius_uwu/services/logger_service.dart';
import 'package:share_plus/share_plus.dart' if (dart.library.html) '';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logs = 'Cargando logs...';
  List<File> _logFiles = [];
  File? _selectedLogFile;
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadLogFiles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      String logs;
      if (_selectedLogFile != null) {
        logs = await _selectedLogFile!.readAsString();
      } else {
        logs = await logger.getCurrentLogs();
      }
      
      setState(() {
        _logs = logs;
      });

      // Auto scroll al final si está habilitado
      if (_autoScroll && _scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _logs = 'Error cargando logs: $e';
      });
    }
  }

  Future<void> _loadLogFiles() async {
    try {
      final files = await logger.getLogFiles();
      setState(() {
        _logFiles = files;
      });
    } catch (e) {
      print('Error cargando archivos de log: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: _logs));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs copiados al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copiando logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareLogs() async {
    try {
      final logPath = _selectedLogFile?.path ?? 
                     await logger.getLogDirectoryPath() + '/anfibius_log_${DateTime.now().toString().split(' ')[0]}.txt';
      
      if (Platform.isAndroid || Platform.isIOS) {
        // En móviles usar share_plus
        final file = File(logPath);
        if (await file.exists()) {
          await Share.shareXFiles([XFile(logPath)], text: 'Logs de Anfibius');
        }
      } else {
        // En escritorio solo mostrar la ruta
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Ubicación de Logs'),
              content: SelectableText(
                'Los logs están guardados en:\n\n$logPath',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: logPath));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ruta copiada al portapapeles')),
                      );
                    }
                  },
                  child: const Text('Copiar Ruta'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compartiendo logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Logs'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar TODOS los logs?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await logger.clearAllLogs();
        setState(() {
          _logs = 'Logs eliminados correctamente';
          _logFiles = [];
          _selectedLogFile = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs eliminados correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error eliminando logs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs del Sistema'),
        actions: [
          // Toggle auto-scroll
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll activado' : 'Auto-scroll desactivado',
          ),
          // Recargar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Recargar logs',
          ),
          // Copiar
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copiar al portapapeles',
          ),
          // Compartir/Exportar
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: 'Compartir logs',
          ),
          // Eliminar
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearLogs,
            tooltip: 'Eliminar todos los logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de archivo de log
          if (_logFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Row(
                children: [
                  const Text('Archivo: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<File?>(
                      isExpanded: true,
                      value: _selectedLogFile,
                      hint: const Text('Hoy (actual)'),
                      items: [
                        const DropdownMenuItem<File?>(
                          value: null,
                          child: Text('Hoy (actual)'),
                        ),
                        ..._logFiles.map((file) {
                          final fileName = file.path.split('/').last;
                          return DropdownMenuItem<File>(
                            value: file,
                            child: Text(fileName),
                          );
                        }).toList(),
                      ],
                      onChanged: (File? newFile) {
                        setState(() {
                          _selectedLogFile = newFile;
                        });
                        _loadLogs();
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenido de los logs
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                _logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
                scrollPhysics: const AlwaysScrollableScrollPhysics(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
