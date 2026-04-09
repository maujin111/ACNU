import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/print_history_item.dart';
import '../services/config_service.dart';
import '../services/logger_service.dart';
import '../services/notifications_service.dart';
import '../services/nfc_service.dart';

class WebSocketService extends ChangeNotifier {
  HttpClient client =
      HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

  WebSocketChannel? _channel;
  String? _token;
  bool _isConnected = false;
  final List<String> _messages = [];
  final List<PrintHistoryItem> _historyItems = [];
  StreamSubscription? _subscription;

  Timer? _reconnectTimer;

  Timer? _heartbeatTimer;

  Timer? _connectionCheckTimer;

  Timer? _watchdogTimer;
  DateTime? _lastSuccessfulActivity;
  static const Duration _watchdogTimeout = Duration(minutes: 5);

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  bool _shouldAutoReconnect = true;

  bool _isInBackground = false;

  bool _isDisposed = false;

  final NotificationsService _notificationsService = NotificationsService();

  bool _isConnecting = false;

  int _lastSeenTimestamp = 0;

  bool _isSystemSuspending = false;

  Function()? onNeedRestart;

  WebSocketService() {
    _initFromStorage();

    _startWatchdog();

    _notificationsService.onNotificationClick = _handleNotificationClick;
  }

  void _handleNotificationClick(String? payload) {
    logger.info('Notificación clickeada con payload: $payload');

    if (payload == 'reconnect') {
      logger.info('Usuario solicitó reconexión desde notificación');
      reconnect();
    }
  }

  void _startWatchdog() {
    if (_isDisposed) return;

    _lastSuccessfulActivity = DateTime.now();
    _watchdogTimer?.cancel();

    _watchdogTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      try {
        if (_isDisposed) {
          timer.cancel();
          return;
        }

        final now = DateTime.now();
        final timeSinceLastActivity = now.difference(
          _lastSuccessfulActivity ?? now,
        );

        logger.debug(
          'Watchdog check - Última actividad hace: ${timeSinceLastActivity.inMinutes} minutos',
        );

        if (_token != null &&
            _token!.isNotEmpty &&
            _shouldAutoReconnect &&
            timeSinceLastActivity > _watchdogTimeout) {
          logger.warning(
            'WATCHDOG: Detectado estado zombie (sin actividad por ${timeSinceLastActivity.inMinutes} min)',
          );

          if (!_isConnected && !_isConnecting) {
            logger.info('WATCHDOG: Intentando recuperación automática...');

            _emergencyCleanup();

            _shouldAutoReconnect = true;

            Future.delayed(const Duration(seconds: 3), () {
              if (!_isDisposed && !_isSystemSuspending) {
                _reconnectAttempts = 0;
                _isConnecting = false;
                logger.info('WATCHDOG: Ejecutando reconexión forzada...');
                _connect();
              }
            });

            _lastSuccessfulActivity = DateTime.now();
          } else if (_isConnected) {
            logger.warning(
              'WATCHDOG: Conectado pero sin actividad - Posible estado zombie',
            );

            try {
              _channel?.sink.add(
                json.encode({
                  'type': 'watchdog_ping',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                }),
              );
              logger.debug('WATCHDOG: Ping de verificación enviado');
            } catch (e) {
              logger.error(
                'WATCHDOG: Canal no funcional, limpiando...',
                error: e,
              );
              _emergencyCleanup();

              _shouldAutoReconnect = true;

              Future.delayed(const Duration(seconds: 3), () {
                if (!_isDisposed && !_isSystemSuspending) {
                  _reconnectAttempts = 0;
                  _isConnecting = false;
                  logger.info(
                    'WATCHDOG: Ejecutando reconexión forzada después de canal no funcional...',
                  );
                  _connect();
                }
              });
            }

            _lastSuccessfulActivity = DateTime.now();
          }
        }

        if (timeSinceLastActivity > const Duration(minutes: 10) &&
            _token != null &&
            _shouldAutoReconnect) {
          logger.error(
            'WATCHDOG: Estado zombie crítico - Recomendando reinicio de app',
          );

          if (onNeedRestart != null) {
            try {
              onNeedRestart!();
            } catch (e) {
              logger.error('Error en callback onNeedRestart', error: e);
            }
          }
        }
      } catch (e, stackTrace) {
        logger.error('Error en watchdog', error: e, stackTrace: stackTrace);
      }
    });
  }

  void _emergencyCleanup() {
    logger.info('EMERGENCY CLEANUP - Limpiando recursos zombies...');

    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;

      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;

      _isConnected = false;
      _isConnecting = false;

      logger.success('Emergency cleanup completado');
    } catch (e, stackTrace) {
      logger.error(
        'Error en emergency cleanup',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  String _extractJsonPayload(String rawMessage) {
    final cleanMessage =
        rawMessage
            .replaceAll("\r", "")
            .replaceAll("\n", " ")
            .replaceAll("%0D", "")
            .trim();

    final historyLiveRegex = RegExp(r'^\[(HISTORIAL|LIVE)\|(\d+)\]\s(.*)');
    final historyMatch = historyLiveRegex.firstMatch(cleanMessage);

    if (historyMatch != null) {
      _lastSeenTimestamp = int.parse(historyMatch.group(2)!);
      return historyMatch.group(3)!.trim();
    }

    final broadcastRegex = RegExp(r'Broadcast \[.*?\]:\s*(\{.*\})');
    final broadcastMatch = broadcastRegex.firstMatch(cleanMessage);
    if (broadcastMatch != null && broadcastMatch.groupCount >= 1) {
      return broadcastMatch.group(1)!.trim();
    }

    return cleanMessage;
  }

  Map<String, dynamic>? _parseMessageData(String jsonMessage) {
    final parsedData = json.decode(jsonMessage);

    if (parsedData is List && parsedData.isNotEmpty) {
      final firstItem = parsedData.first;
      if (firstItem is Map<String, dynamic>) {
        return firstItem;
      }
      return null;
    }

    if (parsedData is Map<String, dynamic>) {
      return parsedData;
    }

    return null;
  }

  bool _isAllowedHistoryType(Map<String, dynamic> data) {
    final String? type = data['type']?.toString() ?? data['tipo']?.toString();

    const List<String> allowedTypes = [
      'COMANDA',
      'PREFACTURA',
      'VENTA',
      'TEST',
      'SORTEO',
    ];

    return type != null && allowedTypes.contains(type.toUpperCase());
  }

  Future<void> _initFromStorage() async {
    try {
      final savedMessages = await ConfigService.loadMessages();
      if (savedMessages.isNotEmpty) {
        for (var message in savedMessages) {
          try {
            final jsonMessage = _extractJsonPayload(message);
            final data = _parseMessageData(jsonMessage);

            if (data == null) {
              print('⚠️ Mensaje guardado con formato no válido, omitido');
              continue;
            }

            if (!_isAllowedHistoryType(data)) {
              final String? type =
                  data['type']?.toString() ?? data['tipo']?.toString();
              print(
                '⚠️ Mensaje guardado con tipo "$type" no permitido, omitiendo del historial',
              );
              continue;
            }

            _messages.add(jsonMessage);

            final historyItem = PrintHistoryItem.fromMessage(
              jsonMessage,
              timestamp: DateTime.now(),
            );
            _historyItems.add(historyItem);
          } catch (e) {
            print('Error al procesar mensaje guardado: $e');
          }
        }
      }

      final token = await ConfigService.loadWebSocketToken();
      if (token != null && token.isNotEmpty) {
        _token = token.replaceAll("%0D", "").trim();
        if (_token != token) {
          await ConfigService.saveWebSocketToken(_token!);
        }
        await _connect();
      }
      _safeNotifyListeners();
    } catch (e) {
      print('Error al inicializar WebSocketService: $e');
    }
  }

  bool get isConnected => _isConnected;
  String? get token => _token;
  List<String> get messages => List.unmodifiable(_messages);
  List<PrintHistoryItem> get historyItems => List.unmodifiable(_historyItems);

  bool get shouldAutoReconnect => _shouldAutoReconnect;

  int get reconnectAttempts => _reconnectAttempts;

  Future<void> connect(String token) async {
    if (_isConnected) {
      disconnect();
    }

    _token = token.replaceAll("%0D", "").trim();
    await ConfigService.saveWebSocketToken(_token!);

    _shouldAutoReconnect = true;
    _reconnectAttempts = 0;

    print('Conectando al WebSocket con token: $_token');
    return _connect();
  }

  Future<void> forceReconnect() async {
    if (_isDisposed) {
      print('❌ [${DateTime.now()}] Servicio disposed, no se puede reconectar');
      return;
    }

    if (_token == null || _token!.isEmpty) {
      print('❌ [${DateTime.now()}] No hay token disponible para reconectar');
      return;
    }

    if (_isConnecting) {
      print(
        '⚠️ [${DateTime.now()}] Ya hay una conexión en curso, esperando...',
      );
      int waitCount = 0;
      while (_isConnecting && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }

      if (_isConnecting) {
        print(
          '⚠️ [${DateTime.now()}] Timeout esperando conexión actual, abortando',
        );
        _isConnecting = false;
      }
    }

    print('🔄 [${DateTime.now()}] Forzando reconexión...');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    if (_isConnected) {
      _isConnected = false;

      try {
        await _subscription?.cancel();
        _subscription = null;
      } catch (e) {
        print('⚠️ Error cancelando subscription en forceReconnect: $e');
      }

      try {
        await _channel?.sink.close();
        _channel = null;
      } catch (e) {
        print('⚠️ Error cerrando channel en forceReconnect: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    _reconnectAttempts = 0;
    _shouldAutoReconnect = true;
    _isConnecting = false;

    await _connect();
  }

  Future<IOWebSocketChannel> connectWebSocketInsecure(String url) async {
    final httpClient =
        HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
    final WebSocket ws = await WebSocket.connect(url, customClient: httpClient);

    return IOWebSocketChannel(ws);
  }

  Future<void> _connect() async {
    if (_isDisposed) {
      logger.warning('Servicio disposed, abortando conexión');
      print('⚠️ [${DateTime.now()}] Servicio disposed, abortando conexión');
      return;
    }

    if (_isConnecting) {
      logger.warning('Ya hay una conexión en curso, abortando');
      print('⚠️ [${DateTime.now()}] Ya hay una conexión en curso, abortando');
      return;
    }

    if (_token == null || _token!.isEmpty) {
      logger.error('No hay token disponible para conectar');
      print('⚠️ [${DateTime.now()}] No hay token disponible');
      return;
    }

    _isConnecting = true;
    logger.info('Iniciando proceso de conexión WebSocket...');

    try {
      if (Platform.isAndroid) {
        try {
          await WakelockPlus.enable();
          print('✅ Wake lock activado');
        } catch (e) {
          print('❌ Error activando wake lock: $e');
        }
      }
      String baseUrl = 'wss://soporte.anfibius.net:3300/$_token';
      // String baseUrl = 'ws://192.168.1.5:3300/$_token';
      if (_lastSeenTimestamp > 0) {
        baseUrl += '?since=$_lastSeenTimestamp';
      }

      final urlsToTry = [baseUrl];

      for (String urlString in urlsToTry) {
        if (_isDisposed) {
          logger.warning('Servicio disposed durante conexión, abortando');
          print(
            '⚠️ [${DateTime.now()}] Servicio disposed durante conexión, abortando',
          );
          _isConnecting = false;
          return;
        }

        try {
          await _subscription?.cancel();
          await _channel?.sink.close();

          logger.info('Intentando conectar a: $urlString');
          print('Intentando conectar a: $urlString');

          final connectionTimeout = Duration(seconds: 10);

          if (urlString.startsWith('wss://')) {
            _channel = await connectWebSocketInsecure(urlString).timeout(
              connectionTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Timeout al conectar con $urlString',
                  connectionTimeout,
                );
              },
            );
          } else {
            final url = Uri.parse(urlString);
            _channel = WebSocketChannel.connect(url);

            await _channel!.ready.timeout(
              connectionTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Timeout esperando confirmación de $urlString',
                  connectionTimeout,
                );
              },
            );
          }

          _subscription = _channel!.stream.listen(
            (message) {
              if (_isDisposed) {
                print(
                  '⚠️ [${DateTime.now()}] Mensaje recibido pero servicio disposed',
                );
                return;
              }

              print('Mensaje recibido - Raw: $message');
              _addMessage(message.toString());

              if (_reconnectAttempts > 0) {
                print('✅ Conexión estable, reseteando contador de reconexión');
                _reconnectAttempts = 0;
              }
            },
            onDone: () {
              if (_isDisposed) {
                print('⚠️ [${DateTime.now()}] onDone pero servicio disposed');
                return;
              }
              if (_isConnecting) {
                print(
                  '⚠️ [${DateTime.now()}] onDone durante conexión inicial, no reconectar aún',
                );
                return;
              }

              print('WebSocket desconectado (onDone)');
              logger.info('WebSocket desconectado (onDone)');
              _isConnected = false;

              try {
                _heartbeatTimer?.cancel();
                _heartbeatTimer = null;
              } catch (e) {
                print('⚠️ Error cancelando heartbeat en onDone: $e');
              }

              try {
                _connectionCheckTimer?.cancel();
                _connectionCheckTimer = null;
              } catch (e) {
                print('⚠️ Error cancelando connection check en onDone: $e');
              }

              _safeNotifyListeners();

              if (_shouldAutoReconnect && !_isSystemSuspending) {
                logger.info('onDone: Iniciando reconexión automática...');
                _scheduleReconnect();
              } else {
                logger.warning(
                  'onDone: Reconexión no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending',
                );
              }
            },
            onError: (error) {
              if (_isDisposed) {
                print('⚠️ [${DateTime.now()}] onError pero servicio disposed');
                return;
              }
              if (_isConnecting) {
                print(
                  '⚠️ [${DateTime.now()}] onError durante conexión inicial, no reconectar aún',
                );
                logger.warning(
                  'onError durante conexión inicial, se maneja en catch del loop',
                );
                return;
              }

              print('Error de WebSocket: $error');
              logger.error(
                'Error de WebSocket después de conexión establecida',
                error: error,
              );
              _handleWebSocketError(error, urlString);
            },
            cancelOnError: false,
          );

          _isConnected = true;
          _isConnecting = false;
          _reconnectAttempts = 0;
          _lastSuccessfulActivity = DateTime.now();
          _startHeartbeat();
          _safeNotifyListeners();
          logger.success('✅ CONEXIÓN EXITOSA a: $urlString');
          if (Platform.isAndroid && _token != null) {
            NfcService.startForegroundService(sala: _token!);
          }

          logger.info('Contador de intentos reseteado a 0');
          print('✅ Conectado exitosamente a: $urlString');

          return;
        } catch (e) {
          String errorMessage = _getDetailedErrorMessage(e, urlString);
          logger.warning('Fallo al conectar: $errorMessage');
          print('❌ $errorMessage');
          continue;
        }
      }
      logger.error('No se pudo conectar con ninguna de las URLs disponibles');
      logger.info('Intentos realizados en todas las 4 URLs');
      print('❌ No se pudo conectar con ninguna de las URLs disponibles');
      _isConnected = false;
      _isConnecting = false;
      _safeNotifyListeners();

      if (_shouldAutoReconnect && !_isSystemSuspending) {
        logger.info('Iniciando ciclo de reconexión automática...');
        _scheduleReconnect();
      } else {
        logger.warning(
          'Reconexión automática no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending',
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        'Error crítico en _connect',
        error: e,
        stackTrace: stackTrace,
      );
      print('❌ [${DateTime.now()}] Error crítico en _connect: $e');
      print('📋 Stack trace: $stackTrace');
      _isConnected = false;
      _isConnecting = false;
      _safeNotifyListeners();

      if (!_isDisposed && _shouldAutoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    try {
      if (!_shouldAutoReconnect) {
        logger.warning('Reconexión automática deshabilitada');
        print('⚠️ [${DateTime.now()}] Reconexión automática deshabilitada');
        return;
      }
      if (_isDisposed) {
        logger.warning('Servicio disposed, no se programará reconexión');
        print(
          '⚠️ [${DateTime.now()}] Servicio disposed, no se programará reconexión',
        );
        return;
      }

      try {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      } catch (e) {
        print('⚠️ Error cancelando reconnect timer: $e');
      }

      try {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
      } catch (e) {
        print('⚠️ Error cancelando heartbeat timer: $e');
      }

      _reconnectAttempts++;

      int delaySeconds;
      if (_reconnectAttempts == 1) {
        delaySeconds = 1;
      } else if (_reconnectAttempts == 2) {
        delaySeconds = 2;
      } else if (_reconnectAttempts == 3) {
        delaySeconds = 3;
      } else if (_reconnectAttempts == 4) {
        delaySeconds = 5;
      } else if (_reconnectAttempts == 5) {
        delaySeconds = 10;
      } else {
        delaySeconds = 15;
      }

      logger.info(
        'Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...',
      );
      print(
        '🔄 [${DateTime.now()}] Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...',
      );

      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        try {
          if (_isDisposed) {
            logger.warning('Servicio disposed en callback de reconexión');
            print(
              '⚠️ [${DateTime.now()}] Servicio disposed en callback de reconexión',
            );
            return;
          }

          if (!_isConnected &&
              _token != null &&
              _token!.isNotEmpty &&
              _shouldAutoReconnect) {
            logger.info(
              'Ejecutando intento de reconexión #$_reconnectAttempts',
            );
            print(
              '🔄 [${DateTime.now()}] Intentando reconectar al WebSocket (intento #$_reconnectAttempts)...',
            );
            _connect();
          } else if (_isConnected) {
            logger.success('Ya conectado, cancelando reconexión');
            print('✅ [${DateTime.now()}] Ya conectado, cancelando reconexión');
            _reconnectAttempts = 0; // Resetear contador
          }
        } catch (e, stackTrace) {
          print(
            '❌ [${DateTime.now()}] Error crítico en callback de reconexión: $e',
          );
          print('📋 Stack trace: $stackTrace');
          if (!_isDisposed && _shouldAutoReconnect) {
            Future.delayed(const Duration(seconds: 10), () {
              if (!_isDisposed && !_isConnected) {
                _scheduleReconnect();
              }
            });
          }
        }
      });
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error crítico en _scheduleReconnect: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  void disconnect() {
    print('Desconectando WebSocket manualmente...');

    _shouldAutoReconnect = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    _isConnecting = false;
    _isConnected = false;
    _reconnectAttempts = 0;

    try {
      _subscription?.cancel();
      _subscription = null;
    } catch (e) {
      print('⚠️ Error cancelando subscription: $e');
    }

    try {
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      print('⚠️ Error cerrando channel: $e');
    }

    _safeNotifyListeners();
  }

  void reconnect() {
    logger.info('Reconexión manual solicitada');
    logger.debug(
      'Estado actual: disposed=$_isDisposed, connected=$_isConnected, connecting=$_isConnecting, autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending, hasToken=${_token != null && _token!.isNotEmpty}',
    );

    if (_isDisposed) {
      logger.warning('Servicio disposed, no se puede reconectar');
      return;
    }
    if (_token == null || _token!.isEmpty) {
      logger.warning('No hay token disponible para reconectar');
      return;
    }

    _shouldAutoReconnect = true;
    logger.success('AutoReconnect habilitado');

    if (_isConnected || _isConnecting) {
      logger.info('Limpiando conexión existente antes de reconectar...');
      _emergencyCleanup();

      Future.delayed(const Duration(seconds: 1), () {
        if (!_isDisposed && !_isSystemSuspending) {
          _reconnectAttempts = 0;
          _isConnecting = false;
          logger.info('Iniciando reconexión después de cleanup...');
          _connect();
        } else {
          logger.warning(
            'Reconexión cancelada - disposed: $_isDisposed, suspending: $_isSystemSuspending',
          );
        }
      });
    } else {
      _reconnectAttempts = 0;
      _isConnecting = false;
      logger.info('Iniciando reconexión directa...');
      _connect();
    }
  }

  void _startHeartbeat() {
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Servicio disposed, no se inicia heartbeat');
      return;
    }

    _heartbeatTimer?.cancel();

    final heartbeatInterval =
        Platform.isAndroid
            ? const Duration(seconds: 30)
            : const Duration(seconds: 15);

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      try {
        if (_isDisposed) {
          print(
            '⚠️ [${DateTime.now()}] Servicio disposed, cancelando heartbeat',
          );
          timer.cancel();
          return;
        }

        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add(
              json.encode({
                'type': 'HEARTBEAT',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }),
            );
          } catch (e) {
            print('❌ [${DateTime.now()}] Error al enviar heartbeat: $e');
            _isConnected = false;
            _heartbeatTimer?.cancel();
            _safeNotifyListeners();
            _scheduleReconnect();
          }
        } else {
          print(
            '⚠️ [${DateTime.now()}] Heartbeat detectó desconexión, intentando reconectar...',
          );
          timer.cancel();
          if (_shouldAutoReconnect && !_isDisposed) {
            _scheduleReconnect();
          }
        }
      } catch (e, stackTrace) {
        print('❌ [${DateTime.now()}] Error crítico en heartbeat: $e');
        print('📋 Stack trace: $stackTrace');
        timer.cancel();
        if (_shouldAutoReconnect && !_isDisposed) {
          _scheduleReconnect();
        }
      }
    });

    _startConnectionCheck();
  }

  void _startConnectionCheck() {
    if (_isDisposed) {
      print(
        '⚠️ [${DateTime.now()}] Servicio disposed, no se inicia connection check',
      );
      return;
    }

    _connectionCheckTimer?.cancel();

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 60), (
      timer,
    ) {
      try {
        if (_isDisposed) {
          print(
            '⚠️ [${DateTime.now()}] Servicio disposed, cancelando connection check timer',
          );
          timer.cancel();
          return;
        }

        print('🔍 [${DateTime.now()}] Verificación periódica de conexión...');

        if (!_isConnected &&
            _token != null &&
            _token!.isNotEmpty &&
            _shouldAutoReconnect &&
            !_isConnecting) {
          print(
            '⚠️ [${DateTime.now()}] Conexión perdida detectada, forzando reconexión...',
          );
          _reconnectAttempts = 0;
          _connect();
        } else if (_isConnected) {
          print('✅ [${DateTime.now()}] Conexión verificada como activa');
        } else if (_isConnecting) {
          print('🔄 [${DateTime.now()}] Conexión en curso, esperando...');
        }
      } catch (e, stackTrace) {
        print('❌ [${DateTime.now()}] Error en verificación de conexión: $e');
        print('📋 Stack trace: $stackTrace');
        // No dejar que crashee
      }
    });
  }

  Function(String)? onNewMessage;

  void _addMessage(String message) {
    if (_isDisposed) {
      print(
        '⚠️ [${DateTime.now()}] Intento de agregar mensaje en servicio disposed',
      );
      return;
    }

    _lastSuccessfulActivity = DateTime.now();

    if (message.trim().isEmpty) {
      return;
    }

    try {
      String cleanMessage =
          message
              .replaceAll("\r", "")
              .replaceAll("\n", " ")
              .replaceAll("%0D", "")
              .trim();

      if (cleanMessage.toLowerCase() == 'ping' ||
          cleanMessage.toLowerCase() == 'pong') {
        print('📡 Mensaje de heartbeat recibido: $cleanMessage');
        return;
      }

      final jsonMessage = _extractJsonPayload(cleanMessage);

      print('Mensaje procesado: [$cleanMessage]');
      print('JSON extraído: [$jsonMessage]');

      bool shouldAddToHistory = true;
      try {
        dynamic parsedData = json.decode(jsonMessage);

        Map<String, dynamic> data;
        if (parsedData is List && parsedData.isNotEmpty) {
          data = parsedData[0];
        } else if (parsedData is Map<String, dynamic>) {
          data = parsedData;
        } else {
          throw FormatException('Formato de mensaje no válido');
        }

        final String? type =
            data['type']?.toString() ?? data['tipo']?.toString();

        const List<String> allowedTypes = [
          'COMANDA',
          'PREFACTURA',
          'VENTA',
          'TEST',
          'SORTEO',
        ];

        if (type == null || !allowedTypes.contains(type.toUpperCase())) {
          print(
            '⚠️ Tipo de documento "$type" no permitido para historial. Solo se permiten: ${allowedTypes.join(", ")}',
          );
          shouldAddToHistory = false;
        } else {
          print('✅ Tipo de documento válido para historial: $type');
        }
      } catch (e) {
        print('❌ Error al validar tipo de mensaje para historial: $e');
        shouldAddToHistory = false;
      }

      if (shouldAddToHistory) {
        _messages.add(jsonMessage);

        try {
          final historyItem = PrintHistoryItem.fromMessage(jsonMessage);
          _historyItems.add(historyItem);
          print(
            'Historial añadido: ID=${historyItem.id}, Tipo=${historyItem.tipo}',
          );
        } catch (e) {
          print('Error al crear elemento de historial: $e');
        }

        ConfigService.addMessage(jsonMessage);
      }

      if (onNewMessage != null) {
        print('Enviando mensaje a impresora: [$jsonMessage]');
        try {
          onNewMessage!(jsonMessage);
        } catch (e, stackTrace) {
          print('❌ [${DateTime.now()}] Error en callback onNewMessage: $e');
          print('📋 Stack trace: $stackTrace');
        }
      }

      _safeNotifyListeners();
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error crítico en _addMessage: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  void _handleWebSocketError(dynamic error, String urlString) {
    String errorMessage = _getDetailedErrorMessage(error, urlString);
    logger.error('Error de WebSocket: $errorMessage', error: error);
    print('🔥 Error de WebSocket: $errorMessage');

    _isConnected = false;
    _heartbeatTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _safeNotifyListeners();

    _scheduleReconnect();
  }

  String _getDetailedErrorMessage(dynamic error, String urlString) {
    if (error.toString().contains('socket_patch.dart')) {
      // Error relacionado con sockets de red
      if (error.toString().contains('lookup')) {
        return 'Error de resolución DNS al conectar con $urlString - Verifique la conexión a internet';
      } else if (error.toString().contains('staggeredLookup')) {
        return 'Error de conectividad de red con $urlString - El servidor puede no estar disponible';
      } else {
        return 'Error de socket de red con $urlString - Problema de conectividad de red';
      }
    } else if (error is TimeoutException) {
      return 'Timeout al conectar con $urlString después de ${error.duration?.inSeconds ?? 10} segundos';
    } else if (error.toString().contains('Connection refused')) {
      return 'Conexión rechazada por el servidor $urlString - El servidor puede estar apagado';
    } else if (error.toString().contains(
      'No address associated with hostname',
    )) {
      return 'No se pudo resolver la dirección $urlString - Verifique el nombre del servidor';
    } else if (error.toString().contains('Network is unreachable')) {
      return 'Red no accesible para $urlString - Verifique la conexión a internet';
    } else {
      return 'Error al conectar con $urlString: ${error.toString()}';
    }
  }

  void _safeNotifyListeners() {
    try {
      if (!_isDisposed) {
        notifyListeners();
      } else {
        print(
          '⚠️ [${DateTime.now()}] Intento de notificar listeners en servicio disposed',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error al notificar listeners: $e');
      print('📋 Stack trace: $stackTrace');
      // NO dejar que crashee
    }
  }

  @override
  void dispose() {
    print('🛑 [${DateTime.now()}] Limpiando WebSocketService...');

    _isDisposed = true;

    _shouldAutoReconnect = false;
    _isConnecting = false;

    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cancelando reconnect timer: $e');
    }

    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cancelando heartbeat timer: $e');
    }

    try {
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
    } catch (e) {
      print(
        '⚠️ [${DateTime.now()}] Error cancelando connection check timer: $e',
      );
    }

    try {
      _watchdogTimer?.cancel();
      _watchdogTimer = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cancelando watchdog timer: $e');
    }

    try {
      _subscription?.cancel();
      _subscription = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cancelando subscription: $e');
    }

    try {
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cerrando channel: $e');
    }

    if (Platform.isAndroid) {
      try {
        WakelockPlus.disable();
      } catch (e) {
        print('⚠️ [${DateTime.now()}] Error deshabilitando wake lock: $e');
      }
    }

    _isConnected = false;

    onNewMessage = null;
    onNeedRestart = null;
    _messages.clear();
    _historyItems.clear();
    try {
      super.dispose();
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error en super.dispose(): $e');
    }

    print('✅ [${DateTime.now()}] WebSocketService limpiado completamente');
  }

  void onAppPaused() {
    _isInBackground = true;
    print('⏸️ App en segundo plano - manteniendo conexión WebSocket activa');

    if (Platform.isWindows) {
      print(
        '💤 Windows detectado - CANCELANDO timers para evitar crashes durante suspensión',
      );
      try {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        print('✅ Reconnect timer cancelado');
      } catch (e) {
        print('⚠️ Error cancelando reconnect timer en pause: $e');
      }

      try {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        print('✅ Heartbeat timer cancelado');
      } catch (e) {
        print('⚠️ Error cancelando heartbeat timer en pause: $e');
      }

      try {
        _connectionCheckTimer?.cancel();
        _connectionCheckTimer = null;
        print('✅ Connection check timer cancelado');
      } catch (e) {
        print('⚠️ Error cancelando connection check timer en pause: $e');
      }

      try {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        print('✅ Watchdog timer cancelado');
      } catch (e) {
        print('⚠️ Error cancelando watchdog timer en pause: $e');
      }

      _isSystemSuspending = true;

      print(
        '✅ Todos los timers cancelados - evitando ACCESS_VIOLATION durante suspensión',
      );
    }

    if (Platform.isAndroid) {
      print('🤖 Android - Servicio de primer plano mantiene la conexión');
    }
  }

  void onAppResumed() {
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Servicio disposed, ignorando onAppResumed');
      return;
    }

    _isInBackground = false;
    print('▶️ App en primer plano - verificando conexión WebSocket');

    if (!_isConnected && _token != null && _token!.isNotEmpty) {
      print(
        '⚠️ Conexión perdida mientras estaba en segundo plano, reconectando...',
      );
      _shouldAutoReconnect = true;
      _reconnectAttempts = 0;
      _isConnecting = false;

      print('💻 Reconectando después de 2 segundos...');
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_isConnected && _token != null) {
          _connect();
        }
      });
    } else if (_isConnected) {
      if (Platform.isWindows) {
        print('🔄 Reiniciando timers después de reanudar...');
        _isSystemSuspending = false;
        _lastSuccessfulActivity = DateTime.now();
        _startHeartbeat();
        _startWatchdog();
      }
    } else {
      print('⚠️ No se puede reconectar - token no disponible');
    }
  }

  Future<void> clearHistory() async {
    _messages.clear();
    _historyItems.clear();

    try {
      await ConfigService.clearMessages();

      _safeNotifyListeners();

      print('Historial de impresión limpiado correctamente');
    } catch (e) {
      print('Error al limpiar el historial: $e');
    }
  }

  bool sendMessage(Map<String, dynamic> message) {
    try {
      final String jsonMessage = json.encode(message);
      _channel!.sink.add(jsonMessage);
      print('📤 Mensaje enviado: $jsonMessage');
      return true;
    } catch (e, stackTrace) {
      logger.error(
        'Error al enviar mensaje por WebSocket',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
