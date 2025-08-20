import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../models/print_history_item.dart';
import '../services/config_service.dart';

class WebSocketService extends ChangeNotifier {
  HttpClient client =
      HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

  WebSocketChannel? _channel;
  String? _token;
  bool _isConnected = false;
  final List<String> _messages =
      []; // Mantiene los mensajes sin procesar para retrocompatibilidad
  final List<PrintHistoryItem> _historyItems =
      []; // Nueva lista para historial procesado
  StreamSubscription? _subscription;
  WebSocketService() {
    // Comenzar inicialización en la construcción del servicio
    _initFromStorage();
  }
  Future<void> _initFromStorage() async {
    try {
      // Cargar mensajes anteriores
      final savedMessages = await ConfigService.loadMessages();
      if (savedMessages.isNotEmpty) {
        _messages.addAll(savedMessages);

        // Convertir mensajes a elementos de historial
        for (var message in savedMessages) {
          try {
            // Para mensajes guardados, ponemos la fecha actual como fallback
            // En una implementación más avanzada, podríamos guardar las fechas reales
            final historyItem = PrintHistoryItem.fromMessage(
              message,
              timestamp: DateTime.now(),
            );
            _historyItems.add(historyItem);
          } catch (e) {
            print('Error al procesar mensaje guardado: $e');
          }
        }
      }

      // Cargar token y reconectar si está disponible
      final token = await ConfigService.loadWebSocketToken();
      if (token != null && token.isNotEmpty) {
        // Limpiar el token eliminando caracteres no deseados1
        _token = token.replaceAll("%0D", "").trim();
        if (_token != token) {
          // Si se limpiaron caracteres, guardar el token limpio
          await ConfigService.saveWebSocketToken(_token!);
        }
        await _connect();
      }
      notifyListeners();
    } catch (e) {
      print('Error al inicializar WebSocketService: $e');
    }
  }

  bool get isConnected => _isConnected;
  String? get token => _token;
  List<String> get messages => List.unmodifiable(_messages);
  List<PrintHistoryItem> get historyItems => List.unmodifiable(_historyItems);

  Future<void> connect(String token) async {
    if (_isConnected) {
      disconnect();
    }

    // Limpiar el token eliminando caracteres no deseados
    _token = token.replaceAll("%0D", "").trim();
    await ConfigService.saveWebSocketToken(_token!);

    print('Conectando al WebSocket con token: $_token');
    return _connect();
  }

  Future<IOWebSocketChannel> connectWebSocketInsecure(String url) async {
    // Crear un HttpClient personalizado que ignore certificados SSL
    final httpClient =
        HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;

    // Usar el cliente personalizado para la conexión WebSocket
    final WebSocket ws = await WebSocket.connect(url, customClient: httpClient);

    return IOWebSocketChannel(ws);
  }

  Future<void> _connect() async {
    if (_token == null || _token!.isEmpty) return;

    // Lista de URLs para probar en orden de preferencia
    final urlsToTry = [
      'wss://soporte.anfibius.net:3300/$_token', // HTTPS con puerto 3300
      'ws://soporte.anfibius.net:3300/$_token', // HTTP con puerto 3300
      'wss://soporte.anfibius.net/$_token', // HTTPS puerto por defecto
      'ws://soporte.anfibius.net/$_token', // HTTP puerto por defecto
    ];

    for (String urlString in urlsToTry) {
      try {
        // Cerrar cualquier conexión existente
        await _subscription?.cancel();
        await _channel?.sink.close();

        print('Intentando conectar a: $urlString');

        if (urlString.startsWith('wss://')) {
          // Para conexiones seguras, usar el método que ignora certificados
          _channel = await connectWebSocketInsecure(urlString);
        } else {
          // Para conexiones no seguras, usar conexión directa
          final url = Uri.parse(urlString);
          _channel = WebSocketChannel.connect(url);
        }

        _subscription = _channel!.stream.listen(
          (message) {
            print('Mensaje recibido - Raw: $message');
            _addMessage(message.toString());
          },
          onDone: () {
            print('WebSocket desconectado');
            _isConnected = false;
            notifyListeners();
            // Intentar reconectar después de un tiempo
            _scheduleReconnect();
          },
          onError: (error) {
            print('Error de WebSocket: $error');
            _isConnected = false;
            notifyListeners();
            // Intentar reconectar después de un tiempo
            _scheduleReconnect();
          },
        );

        _isConnected = true;
        notifyListeners();
        print('✅ Conectado exitosamente a: $urlString');
        return; // Salir del bucle si la conexión fue exitosa
      } catch (e) {
        print('❌ Error al conectar con $urlString: $e');
        // Continuar con la siguiente URL
        continue;
      }
    }

    // Si llegamos aquí, ninguna URL funcionó
    print('❌ No se pudo conectar con ninguna de las URLs disponibles');
    _isConnected = false;
    notifyListeners();
    // Intentar reconectar después de un tiempo
    _scheduleReconnect();
  }

  // Temporizador para intentar reconexión
  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    // Cancelar cualquier temporizador anterior
    _reconnectTimer?.cancel();

    // Programar un intento de reconexión después de 5 segundos
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _token != null && _token!.isNotEmpty) {
        print('Intentando reconectar al WebSocket...');
        _connect();
      }
    });
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  // Callback para imprimir mensaje automáticamente
  Function(String)? onNewMessage;

  void _addMessage(String message) {
    if (message.trim().isNotEmpty) {
      // Limpiar el mensaje (eliminar caracteres no deseados)
      String cleanMessage =
          message
              .replaceAll("\r", "")
              .replaceAll("\n", " ")
              .replaceAll("%0D", "")
              .trim();

      // Extraer el JSON si el mensaje tiene el formato "Broadcast [estacion_X/Y]: {...json...}"
      String jsonMessage = cleanMessage;
      final broadcastRegex = RegExp(r'Broadcast \[.*?\]:\s*(\{.*\})');
      final match = broadcastRegex.firstMatch(cleanMessage);
      if (match != null && match.groupCount >= 1) {
        jsonMessage = match.group(1)!;
      }

      // Imprimir en consola para debug
      print('Mensaje procesado: [$cleanMessage]');
      print('JSON extraído: [$jsonMessage]');

      // Agregar el mensaje a la lista de mensajes crudos
      _messages.add(cleanMessage);

      // Crear y agregar un elemento de historial estructurado
      try {
        final historyItem = PrintHistoryItem.fromMessage(jsonMessage);
        _historyItems.add(historyItem);
        print(
          'Historial añadido: ID=${historyItem.id}, Tipo=${historyItem.tipo}',
        );
      } catch (e) {
        print('Error al crear elemento de historial: $e');
      }

      // Guardar mensaje en almacenamiento persistente
      ConfigService.addMessage(cleanMessage);

      // Notificar a los callbacks registrados
      if (onNewMessage != null) {
        print('Enviando mensaje a impresora: [$jsonMessage]');
        onNewMessage!(jsonMessage);
      }

      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }

  /// Limpia el historial de mensajes tanto en memoria como en almacenamiento persistente
  Future<void> clearHistory() async {
    // Limpiar listas en memoria
    _messages.clear();
    _historyItems.clear();

    try {
      // Limpiar mensajes en almacenamiento persistente
      await ConfigService.clearMessages();

      // Notificar a los oyentes sobre el cambio
      notifyListeners();

      print('Historial de impresión limpiado correctamente');
    } catch (e) {
      print('Error al limpiar el historial: $e');
    }
  }
}
