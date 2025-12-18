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

  // Temporizador para intentar reconexión
  Timer? _reconnectTimer;

  // Temporizador para heartbeat
  Timer? _heartbeatTimer;

  // Temporizador para verificación periódica de conexión
  Timer? _connectionCheckTimer;

  // 🆕 Watchdog timer para detectar estado zombie
  Timer? _watchdogTimer;
  DateTime? _lastSuccessfulActivity;
  static const Duration _watchdogTimeout = Duration(minutes: 3); // Reducido de 5 a 3 minutos

  // Contador de intentos de reconexión
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // Flag para controlar si debe reconectar automáticamente
  bool _shouldAutoReconnect = true;

  // Flag para saber si la app está en segundo plano
  bool _isInBackground = false;

  // Flag para saber si el servicio fue disposed
  bool _isDisposed = false;
  
  // 🆕 Servicio de notificaciones
  final NotificationsService _notificationsService = NotificationsService();

  // Flag para evitar reconexiones múltiples simultáneas
  bool _isConnecting = false;

  // 🆕 Flag para detectar si estamos en suspensión del sistema
  bool _isSystemSuspending = false;

  // 🆕 Callback para notificar que se necesita reiniciar la app
  Function()? onNeedRestart;

  WebSocketService() {
    // Comenzar inicialización en la construcción del servicio
    _initFromStorage();
    
    // 🆕 Iniciar watchdog timer para detectar estado zombie
    _startWatchdog();
    
    // 🆕 Configurar callback para notificaciones
    _notificationsService.onNotificationClick = _handleNotificationClick;
  }
  
  // 🆕 Manejar click en notificaciones
  void _handleNotificationClick(String? payload) {
    logger.info('Notificación clickeada con payload: $payload');
    
    if (payload == 'reconnect') {
      // Usuario clickeó la notificación de desconexión
      logger.info('Usuario solicitó reconexión desde notificación');
      reconnect(); // Forzar reconexión inmediata
    }
  }
  
  // 🆕 WATCHDOG TIMER - Detecta estado zombie y reinicia la app si es necesario
  void _startWatchdog() {
    if (_isDisposed) return;
    
    _lastSuccessfulActivity = DateTime.now();
    _watchdogTimer?.cancel();
    
    // Verificar cada 2 minutos si hay actividad
    _watchdogTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      try {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        
        final now = DateTime.now();
        final timeSinceLastActivity = now.difference(_lastSuccessfulActivity ?? now);
        
        logger.debug('Watchdog check - Última actividad hace: ${timeSinceLastActivity.inMinutes} minutos');
        
        // Si tiene token y debe estar conectado pero no ha tenido actividad en 3+ minutos
        if (_token != null && 
            _token!.isNotEmpty && 
            _shouldAutoReconnect && 
            timeSinceLastActivity > _watchdogTimeout) {
          
          logger.warning('WATCHDOG: Detectado estado zombie (sin actividad por ${timeSinceLastActivity.inMinutes} min)');
          
          // Intentar recuperación agresiva
          if (!_isConnected && !_isConnecting) {
            logger.info('WATCHDOG: Intentando recuperación automática...');
            
            // Limpiar todo y forzar reconexión
            _emergencyCleanup();
            
            // CRÍTICO: Asegurar que autoreconnect esté habilitado
            _shouldAutoReconnect = true;
            
            // Esperar un poco y reconectar
            Future.delayed(const Duration(seconds: 3), () {
              if (!_isDisposed && !_isSystemSuspending) {
                _reconnectAttempts = 0;
                _isConnecting = false;
                logger.info('WATCHDOG: Ejecutando reconexión forzada...');
                _connect();
              }
            });
            
            // Actualizar timestamp para evitar spam de recuperaciones
            _lastSuccessfulActivity = DateTime.now();
          } else if (_isConnected) {
            // Si dice estar conectado pero no hay actividad, algo está mal
            logger.warning('WATCHDOG: Conectado pero sin actividad - Posible estado zombie');
            
            // Verificar si el canal realmente funciona
            try {
              _channel?.sink.add(json.encode({
                'type': 'watchdog_ping',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }));
              logger.debug('WATCHDOG: Ping de verificación enviado');
            } catch (e) {
              logger.error('WATCHDOG: Canal no funcional, limpiando...', error: e);
              _emergencyCleanup();
              
              // CRÍTICO: Asegurar que autoreconnect esté habilitado
              _shouldAutoReconnect = true;
              
              Future.delayed(const Duration(seconds: 3), () {
                if (!_isDisposed && !_isSystemSuspending) {
                  _reconnectAttempts = 0;
                  _isConnecting = false;
                  logger.info('WATCHDOG: Ejecutando reconexión forzada después de canal no funcional...');
                  _connect();
                }
              });
            }
            
            _lastSuccessfulActivity = DateTime.now();
          }
        }
        
        // Si ha estado en estado zombie por mucho tiempo (10+ minutos), notificar para reinicio
        if (timeSinceLastActivity > const Duration(minutes: 10) &&
            _token != null && 
            _shouldAutoReconnect) {
          logger.error('WATCHDOG: Estado zombie crítico - Recomendando reinicio de app');
          
          // Notificar al UI que necesita reiniciar
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
  
  // 🆕 Limpieza de emergencia cuando se detecta estado zombie
  void _emergencyCleanup() {
    logger.info('EMERGENCY CLEANUP - Limpiando recursos zombies...');
    
    try {
      // Cancelar TODOS los timers
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
      
      // Cerrar conexiones
      _subscription?.cancel();
      _subscription = null;
      _channel?.sink.close();
      _channel = null;
      
      // Resetear flags
      _isConnected = false;
      _isConnecting = false;
      
      logger.success('Emergency cleanup completado');
    } catch (e, stackTrace) {
      logger.error('Error en emergency cleanup', error: e, stackTrace: stackTrace);
    }
  }
  
  Future<void> _initFromStorage() async {
    try {
      // Cargar mensajes anteriores (solo tipos permitidos)
      final savedMessages = await ConfigService.loadMessages();
      if (savedMessages.isNotEmpty) {
        // Filtrar solo mensajes con tipos permitidos
        for (var message in savedMessages) {
          try {
            // Intentar parsear el JSON, manejando posibles arrays
            dynamic parsedData = json.decode(message);

            // Si viene como array, tomar el primer elemento
            Map<String, dynamic> data;
            if (parsedData is List && parsedData.isNotEmpty) {
              data = parsedData[0];
            } else if (parsedData is Map<String, dynamic>) {
              data = parsedData;
            } else {
              continue; // Saltar mensajes con formato no válido
            }

            // Buscar el tipo en ambos campos posibles: 'type' y 'tipo'
            final String? type =
                data['type']?.toString() ?? data['tipo']?.toString();

            const List<String> allowedTypes = [
              'COMANDA',
              'PREFACTURA',
              'VENTA',
              'TEST',
              'SORTEO',
            ];

            if (type != null && allowedTypes.contains(type.toUpperCase())) {
              _messages.add(message);
            }
          } catch (e) {
            print('❌ Error al validar mensaje guardado: $e');
          }
        }

        // Convertir mensajes a elementos de historial (solo tipos permitidos)
        for (var message in savedMessages) {
          try {
            // Validar tipo antes de agregar al historial
            bool shouldAddToHistory = true;
            try {
              // Intentar parsear el JSON, manejando posibles arrays
              dynamic parsedData = json.decode(message);

              // Si viene como array, tomar el primer elemento
              Map<String, dynamic> data;
              if (parsedData is List && parsedData.isNotEmpty) {
                data = parsedData[0];
              } else if (parsedData is Map<String, dynamic>) {
                data = parsedData;
              } else {
                throw FormatException('Formato de mensaje no válido');
              }

              // Buscar el tipo en ambos campos posibles: 'type' y 'tipo'
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
                  '⚠️ Mensaje guardado con tipo "$type" no permitido, omitiendo del historial',
                );
                shouldAddToHistory = false;
              }
            } catch (e) {
              print('❌ Error al validar tipo de mensaje guardado: $e');
              shouldAddToHistory = false;
            }

            if (shouldAddToHistory) {
              // Para mensajes guardados, ponemos la fecha actual como fallback
              // En una implementación más avanzada, podríamos guardar las fechas reales
              final historyItem = PrintHistoryItem.fromMessage(
                message,
                timestamp: DateTime.now(),
              );
              _historyItems.add(historyItem);
            }
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
      _safeNotifyListeners();
    } catch (e) {
      print('Error al inicializar WebSocketService: $e');
    }
  }

  bool get isConnected => _isConnected;
  String? get token => _token;
  List<String> get messages => List.unmodifiable(_messages);
  List<PrintHistoryItem> get historyItems => List.unmodifiable(_historyItems);

  // Getter para saber si la reconexión automática está habilitada
  bool get shouldAutoReconnect => _shouldAutoReconnect;

  // Getter para obtener el número de intentos de reconexión
  int get reconnectAttempts => _reconnectAttempts;

  Future<void> connect(String token) async {
    if (_isConnected) {
      disconnect();
    }

    // Limpiar el token eliminando caracteres no deseados
    _token = token.replaceAll("%0D", "").trim();
    await ConfigService.saveWebSocketToken(_token!);

    // Habilitar reconexión automática al conectar manualmente
    _shouldAutoReconnect = true;
    _reconnectAttempts = 0;

    print('Conectando al WebSocket con token: $_token');
    return _connect();
  }

  // Método para forzar reconexión (usado en botón "Reconectar")
  Future<void> forceReconnect() async {
    // 🛡️ Verificar que no estamos disposed
    if (_isDisposed) {
      print('❌ [${DateTime.now()}] Servicio disposed, no se puede reconectar');
      return;
    }

    if (_token == null || _token!.isEmpty) {
      print('❌ [${DateTime.now()}] No hay token disponible para reconectar');
      return;
    }

    // Si ya hay una conexión en curso, esperar a que termine
    if (_isConnecting) {
      print('⚠️ [${DateTime.now()}] Ya hay una conexión en curso, esperando...');
      // Esperar hasta 5 segundos a que termine la conexión actual
      int waitCount = 0;
      while (_isConnecting && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
      
      if (_isConnecting) {
        print('⚠️ [${DateTime.now()}] Timeout esperando conexión actual, abortando');
        _isConnecting = false; // Forzar reset
      }
    }

    print('🔄 [${DateTime.now()}] Forzando reconexión...');

    // Cancelar todos los timers antes de reconectar
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    // Desconectar si está conectado
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

    // Resetear contador y habilitar reconexión automática
    _reconnectAttempts = 0;
    _shouldAutoReconnect = true;
    _isConnecting = false;

    // Intentar conectar
    await _connect();
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
    // 🛡️ Verificar que no estamos disposed y no hay otra conexión en curso
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

    // Marcar que estamos conectando
    _isConnecting = true;
    logger.info('Iniciando proceso de conexión WebSocket...');

    try {
      // Activar wake lock en Android para mantener la conexión activa
      if (Platform.isAndroid) {
        try {
          await WakelockPlus.enable();
          print('✅ Wake lock activado');
        } catch (e) {
          print('❌ Error activando wake lock: $e');
        }
      }

      // Lista de URLs para probar en orden de preferencia
      final urlsToTry = [
        'wss://soporte.anfibius.net:3300/$_token', // HTTPS con puerto 3300
              ];

      for (String urlString in urlsToTry) {
        // 🛡️ Verificar disposed en cada iteración
        if (_isDisposed) {
          logger.warning('Servicio disposed durante conexión, abortando');
          print('⚠️ [${DateTime.now()}] Servicio disposed durante conexión, abortando');
          _isConnecting = false;
          return;
        }

        try {
          // Cerrar cualquier conexión existente
          await _subscription?.cancel();
          await _channel?.sink.close();

          logger.info('Intentando conectar a: $urlString');
          print('Intentando conectar a: $urlString');

          // Configurar timeout para la conexión
          final connectionTimeout = Duration(seconds: 10);

          if (urlString.startsWith('wss://')) {
            // Para conexiones seguras, usar el método que ignora certificados
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
            // Para conexiones no seguras, usar conexión directa
            final url = Uri.parse(urlString);
            _channel = WebSocketChannel.connect(url);

            // Esperar un mensaje de confirmación para verificar la conexión
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
              // 🛡️ Verificar que no estamos disposed antes de procesar
              if (_isDisposed) {
                print('⚠️ [${DateTime.now()}] Mensaje recibido pero servicio disposed');
                return;
              }
              
              print('Mensaje recibido - Raw: $message');
              _addMessage(message.toString());

              // Resetear contador de reconexión en mensajes exitosos
              if (_reconnectAttempts > 0) {
                print('✅ Conexión estable, reseteando contador de reconexión');
                _reconnectAttempts = 0;
              }
            },
            onDone: () {
              // 🛡️ Verificar disposed antes de manejar desconexión
              if (_isDisposed) {
                print('⚠️ [${DateTime.now()}] onDone pero servicio disposed');
                return;
              }
              
              // 🔥 NO reconectar si aún estamos en proceso de conexión inicial
              // (dejemos que el catch del for loop lo maneje)
              if (_isConnecting) {
                print('⚠️ [${DateTime.now()}] onDone durante conexión inicial, no reconectar aún');
                return;
              }
              
              print('WebSocket desconectado (onDone)');
              logger.info('WebSocket desconectado (onDone)');
              _isConnected = false;
              
              // 🔔 NOTIFICACIÓN: Desconectado
              _notificationsService.showNotification(
                id: 1,
                title: '⚠️ Anfibius - Desconectado',
                body: 'Conexión perdida. Intentando reconectar automáticamente...',
                payload: 'reconnect',
              );
              
              // Cancelar timers de forma segura
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
              
              // Siempre intentar reconectar si está habilitado y no estamos suspendiendo
              if (_shouldAutoReconnect && !_isSystemSuspending) {
                logger.info('onDone: Iniciando reconexión automática...');
                _scheduleReconnect();
              } else {
                logger.warning('onDone: Reconexión no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending');
              }
            },
            onError: (error) {
              // 🛡️ Verificar disposed antes de manejar error
              if (_isDisposed) {
                print('⚠️ [${DateTime.now()}] onError pero servicio disposed');
                return;
              }
              
              // 🔥 NO reconectar si aún estamos en proceso de conexión inicial
              // (dejemos que el catch del for loop lo maneje)
              if (_isConnecting) {
                print('⚠️ [${DateTime.now()}] onError durante conexión inicial, no reconectar aún');
                logger.warning('onError durante conexión inicial, se maneja en catch del loop');
                return;
              }
              
              print('Error de WebSocket: $error');
              logger.error('Error de WebSocket después de conexión establecida', error: error);
              _handleWebSocketError(error, urlString);
            },
            cancelOnError: false, // 🆕 NO cancelar el stream en errores
          );

          _isConnected = true;
          _reconnectAttempts = 0; // Resetear intentos en conexión exitosa
          _isConnecting = false; // 🆕 Marcar que terminamos de conectar
          _lastSuccessfulActivity = DateTime.now(); // 🆕 Registrar actividad exitosa
          _startHeartbeat(); // Iniciar heartbeat para detectar conexiones muertas
          _safeNotifyListeners();
          logger.success('✅ CONEXIÓN EXITOSA a: $urlString');
          logger.info('Contador de intentos reseteado a 0');
          print('✅ Conectado exitosamente a: $urlString');
          
          // 🔔 NOTIFICACIÓN: Reconectado
          _notificationsService.showNotification(
            id: 2,
            title: '✅ Anfibius - Conectado',
            body: 'Conexión restablecida exitosamente',
            payload: 'connected',
          );
          
          return; // Salir del bucle si la conexión fue exitosa
        } catch (e) {
          String errorMessage = _getDetailedErrorMessage(e, urlString);
          logger.warning('Fallo al conectar: $errorMessage');
          print('❌ $errorMessage');
          // Continuar con la siguiente URL
          continue;
        }
      }

      // Si llegamos aquí, ninguna URL funcionó
      logger.error('No se pudo conectar con ninguna de las URLs disponibles');
      logger.info('Intentos realizados en todas las 4 URLs');
      print('❌ No se pudo conectar con ninguna de las URLs disponibles');
      _isConnected = false;
      _isConnecting = false; // 🆕 Marcar que terminamos de intentar conectar
      _safeNotifyListeners();
      
      // Intentar reconectar después de un tiempo si está habilitado
      if (_shouldAutoReconnect && !_isSystemSuspending) {
        logger.info('Iniciando ciclo de reconexión automática...');
        _scheduleReconnect();
      } else {
        logger.warning('Reconexión automática no iniciada - autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending');
      }
    } catch (e, stackTrace) {
      // 🛡️ Capturar cualquier error inesperado en _connect
      logger.error('Error crítico en _connect', error: e, stackTrace: stackTrace);
      print('❌ [${DateTime.now()}] Error crítico en _connect: $e');
      print('📋 Stack trace: $stackTrace');
      _isConnected = false;
      _isConnecting = false;
      _safeNotifyListeners();
      
      // Solo reconectar si no estamos disposed
      if (!_isDisposed && _shouldAutoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    // 🛡️ PROTECCIÓN: Envolver en try-catch
    try {
      // No intentar reconectar si se desconectó manualmente
      if (!_shouldAutoReconnect) {
        logger.warning('Reconexión automática deshabilitada');
        print('⚠️ [${DateTime.now()}] Reconexión automática deshabilitada');
        return;
      }

      // Verificar si el servicio fue disposed
      if (_isDisposed) {
        logger.warning('Servicio disposed, no se programará reconexión');
        print('⚠️ [${DateTime.now()}] Servicio disposed, no se programará reconexión');
        return;
      }

      // Cancelar cualquier temporizador anterior de forma segura
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

      // 🔥 RECONEXIÓN SUPER AGRESIVA
      // Siempre mantener intentando reconectar INDEFINIDAMENTE
      _reconnectAttempts++;

      // Intentos muy rápidos: 1s, 2s, 3s, 5s, 10s, después cada 15s
      int delaySeconds;
      if (_reconnectAttempts == 1) {
        delaySeconds = 1; // Inmediato casi
      } else if (_reconnectAttempts == 2) {
        delaySeconds = 2;
      } else if (_reconnectAttempts == 3) {
        delaySeconds = 3;
      } else if (_reconnectAttempts == 4) {
        delaySeconds = 5;
      } else if (_reconnectAttempts == 5) {
        delaySeconds = 10;
      } else {
        delaySeconds = 15; // Máximo 15 segundos
      }

      logger.info('Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...');
      print('🔄 [${DateTime.now()}] Programando reconexión #$_reconnectAttempts en ${delaySeconds}s...');

      // Programar un intento de reconexión
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        // 🛡️ PROTECCIÓN: Envolver callback en try-catch
        try {
          if (_isDisposed) {
            logger.warning('Servicio disposed en callback de reconexión');
            print('⚠️ [${DateTime.now()}] Servicio disposed en callback de reconexión');
            return;
          }

          if (!_isConnected &&
              _token != null &&
              _token!.isNotEmpty &&
              _shouldAutoReconnect) {
            logger.info('Ejecutando intento de reconexión #$_reconnectAttempts');
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
          print('❌ [${DateTime.now()}] Error crítico en callback de reconexión: $e');
          print('📋 Stack trace: $stackTrace');
          // Intentar de nuevo después de un tiempo solo si no está disposed
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

    // Deshabilitar reconexión automática cuando se desconecta manualmente
    _shouldAutoReconnect = false;

    // Cancelar temporizadores PRIMERO
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    // Resetear flags
    _isConnecting = false;
    _isConnected = false;
    _reconnectAttempts = 0;

    // Cerrar conexión
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

  /// Método público para forzar reconexión manual
  void reconnect() {
    logger.info('Reconexión manual solicitada');
    logger.debug('Estado actual: disposed=$_isDisposed, connected=$_isConnected, connecting=$_isConnecting, autoReconnect=$_shouldAutoReconnect, suspending=$_isSystemSuspending, hasToken=${_token != null && _token!.isNotEmpty}');
    
    // Verificar que no estamos disposed
    if (_isDisposed) {
      logger.warning('Servicio disposed, no se puede reconectar');
      return;
    }
    
    // Verificar que tenemos token
    if (_token == null || _token!.isEmpty) {
      logger.warning('No hay token disponible para reconectar');
      return;
    }
    
    // Habilitar autoreconnect
    _shouldAutoReconnect = true;
    logger.success('AutoReconnect habilitado');
    
    // Si ya está conectado o conectando, cancelar primero
    if (_isConnected || _isConnecting) {
      logger.info('Limpiando conexión existente antes de reconectar...');
      _emergencyCleanup();
      
      // Esperar un momento antes de reconectar
      Future.delayed(const Duration(seconds: 1), () {
        if (!_isDisposed && !_isSystemSuspending) {
          _reconnectAttempts = 0;
          _isConnecting = false;
          logger.info('Iniciando reconexión después de cleanup...');
          _connect();
        } else {
          logger.warning('Reconexión cancelada - disposed: $_isDisposed, suspending: $_isSystemSuspending');
        }
      });
    } else {
      // No hay conexión activa, conectar directamente
      _reconnectAttempts = 0;
      _isConnecting = false;
      logger.info('Iniciando reconexión directa...');
      _connect();
    }
  }

  // Iniciar heartbeat para detectar conexiones muertas
  void _startHeartbeat() {
    // 🔥 VERIFICAR: Solo disposed, NO verificar _isInBackground
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Servicio disposed, no se inicia heartbeat');
      return;
    }
    
    _heartbeatTimer?.cancel();

    // Enviar ping cada 30 segundos para mantener la conexión viva en Android
    // Esto evita que el sistema mate la conexión por inactividad
    final heartbeatInterval =
        Platform.isAndroid
            ? const Duration(seconds: 30)
            : const Duration(seconds: 15);

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      // 🛡️ PROTECCIÓN: Envolver TODO en try-catch para evitar crashes
      try {
        // Verificar si el servicio fue disposed
        if (_isDisposed) {
          print('⚠️ [${DateTime.now()}] Servicio disposed, cancelando heartbeat');
          timer.cancel();
          return;
        }

        if (_isConnected && _channel != null) {
          try {
            // Enviar un ping simple para mantener la conexión viva
            _channel!.sink.add(
              json.encode({
                'type': 'ping',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              }),
            );
            print('📡 [${DateTime.now()}] Keep-alive ping enviado');
          } catch (e) {
            print('❌ [${DateTime.now()}] Error al enviar heartbeat: $e');
            // Si falla el heartbeat, considerar la conexión como muerta
            _isConnected = false;
            _heartbeatTimer?.cancel();
            _safeNotifyListeners();
            _scheduleReconnect();
          }
        } else {
          // Si no hay conexión, intentar reconectar
          print('⚠️ [${DateTime.now()}] Heartbeat detectó desconexión, intentando reconectar...');
          timer.cancel();
          if (_shouldAutoReconnect && !_isDisposed) {
            _scheduleReconnect();
          }
        }
      } catch (e, stackTrace) {
        // 🛡️ CAPTURAR CUALQUIER ERROR INESPERADO
        print('❌ [${DateTime.now()}] Error crítico en heartbeat: $e');
        print('📋 Stack trace: $stackTrace');
        // NO dejar que crashee - intentar recuperar
        timer.cancel();
        if (_shouldAutoReconnect && !_isDisposed) {
          _scheduleReconnect();
        }
      }
    });

    // 🔥 NUEVO: Iniciar verificación periódica de conexión cada 60 segundos
    _startConnectionCheck();
  }

  // 🆕 Verificación periódica agresiva de conexión
  void _startConnectionCheck() {
    // 🔥 VERIFICAR: Solo disposed, NO verificar _isInBackground
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Servicio disposed, no se inicia connection check');
      return;
    }
    
    _connectionCheckTimer?.cancel();

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      try {
        if (_isDisposed) {
          print('⚠️ [${DateTime.now()}] Servicio disposed, cancelando connection check timer');
          timer.cancel();
          return;
        }

        print('🔍 [${DateTime.now()}] Verificación periódica de conexión...');

        // Si no está conectado y tiene token, forzar reconexión
        if (!_isConnected && _token != null && _token!.isNotEmpty && _shouldAutoReconnect && !_isConnecting) {
          print('⚠️ [${DateTime.now()}] Conexión perdida detectada, forzando reconexión...');
          _reconnectAttempts = 0; // Resetear contador para intentar de nuevo
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

  // Callback para imprimir mensaje automáticamente
  Function(String)? onNewMessage;

  void _addMessage(String message) {
    // 🛡️ Verificar que no estamos disposed
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Intento de agregar mensaje en servicio disposed');
      return;
    }
    
    // 🆕 Registrar actividad exitosa para el watchdog
    _lastSuccessfulActivity = DateTime.now();
    
    if (message.trim().isEmpty) {
      return;
    }

    try {
      // Limpiar el mensaje (eliminar caracteres no deseados)
      String cleanMessage =
          message
              .replaceAll("\r", "")
              .replaceAll("\n", " ")
              .replaceAll("%0D", "")
              .trim();

      // Ignorar mensajes de ping/pong del heartbeat
      if (cleanMessage.toLowerCase() == 'ping' ||
          cleanMessage.toLowerCase() == 'pong') {
        print('📡 Mensaje de heartbeat recibido: $cleanMessage');
        return; // Salir temprano, no procesar como mensaje de impresión
      }

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

      // Validar tipos permitidos antes de agregar al historial
      bool shouldAddToHistory = true;
      try {
        // Intentar parsear el JSON, manejando posibles arrays
        dynamic parsedData = json.decode(jsonMessage);

        // Si viene como array, tomar el primer elemento
        Map<String, dynamic> data;
        if (parsedData is List && parsedData.isNotEmpty) {
          data = parsedData[0];
        } else if (parsedData is Map<String, dynamic>) {
          data = parsedData;
        } else {
          throw FormatException('Formato de mensaje no válido');
        }

        // Buscar el tipo en ambos campos posibles: 'type' y 'tipo'
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

      // Agregar el mensaje a la lista de mensajes crudos solo si es tipo válido
      if (shouldAddToHistory) {
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

        // Guardar mensaje en almacenamiento persistente solo si es tipo válido
        ConfigService.addMessage(cleanMessage);
      }

      // Notificar a los callbacks registrados
      if (onNewMessage != null) {
        print('Enviando mensaje a impresora: [$jsonMessage]');
        try {
          onNewMessage!(jsonMessage);
        } catch (e, stackTrace) {
          print('❌ [${DateTime.now()}] Error en callback onNewMessage: $e');
          print('📋 Stack trace: $stackTrace');
          // No dejar que crashes en el callback afecten el servicio
        }
      }

      _safeNotifyListeners();
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error crítico en _addMessage: $e');
      print('📋 Stack trace: $stackTrace');
      // No dejar que crashee
    }
  }

  /// Maneja errores específicos del WebSocket con información detallada
  void _handleWebSocketError(dynamic error, String urlString) {
    String errorMessage = _getDetailedErrorMessage(error, urlString);
    logger.error('Error de WebSocket: $errorMessage', error: error);
    print('🔥 Error de WebSocket: $errorMessage');

    _isConnected = false;
    _heartbeatTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _safeNotifyListeners();

    // Intentar reconectar después de un tiempo
    _scheduleReconnect();
  }

  /// Obtiene un mensaje de error detallado basado en el tipo de excepción
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

  // 🆕 Método seguro para notificar listeners
  void _safeNotifyListeners() {
    try {
      if (!_isDisposed) {
        notifyListeners();
      } else {
        print('⚠️ [${DateTime.now()}] Intento de notificar listeners en servicio disposed');
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
    
    // Marcar como disposed PRIMERO antes de hacer cualquier otra cosa
    _isDisposed = true;
    
    // Deshabilitar reconexión al hacer dispose
    _shouldAutoReconnect = false;
    _isConnecting = false;
    
    // Cancelar TODOS los temporizadores INMEDIATAMENTE
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
      print('⚠️ [${DateTime.now()}] Error cancelando connection check timer: $e');
    }
    
    try {
      _watchdogTimer?.cancel();
      _watchdogTimer = null;
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error cancelando watchdog timer: $e');
    }

    // Cerrar conexiones
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

    // Deshabilitar wake lock al hacer dispose
    if (Platform.isAndroid) {
      try {
        WakelockPlus.disable();
      } catch (e) {
        print('⚠️ [${DateTime.now()}] Error deshabilitando wake lock: $e');
      }
    }

    _isConnected = false;
    
    // 🆕 Limpiar callbacks y listas para evitar memory leaks
    onNewMessage = null;
    onNeedRestart = null;
    _messages.clear();
    _historyItems.clear();
    
    // Llamar a super.dispose() al final
    try {
      super.dispose();
    } catch (e) {
      print('⚠️ [${DateTime.now()}] Error en super.dispose(): $e');
    }
    
    print('✅ [${DateTime.now()}] WebSocketService limpiado completamente');
  }

  /// Método para notificar que la app va a segundo plano
  void onAppPaused() {
    _isInBackground = true;
    print('⏸️ App en segundo plano - manteniendo conexión WebSocket activa');
    
    // 🔥 FIX CRÍTICO: En Windows, CANCELAR TODOS los timers durante suspensión
    // Los timers causan ACCESS_VIOLATION (c0000005) cuando intentan acceder a
    // objetos de Flutter después de que Windows suspende la aplicación
    if (Platform.isWindows) {
      print('💤 Windows detectado - CANCELANDO timers para evitar crashes durante suspensión');
      
      // Cancelar TODOS los timers de forma segura
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
      
      // Marcar que el sistema está suspendiendo
      _isSystemSuspending = true;
      
      print('✅ Todos los timers cancelados - evitando ACCESS_VIOLATION durante suspensión');
    }
    
    // En Android, el servicio de primer plano mantiene la conexión activa
    if (Platform.isAndroid) {
      print('🤖 Android - Servicio de primer plano mantiene la conexión');
    }
  }

  /// Método para notificar que la app vuelve a primer plano
  void onAppResumed() {
    // 🛡️ PROTECCIÓN: Verificar disposed al inicio
    if (_isDisposed) {
      print('⚠️ [${DateTime.now()}] Servicio disposed, ignorando onAppResumed');
      return;
    }
    
    _isInBackground = false;
    print('▶️ App en primer plano - verificando conexión WebSocket');

    // Verificar si la conexión sigue activa
    if (!_isConnected && _token != null && _token!.isNotEmpty) {
      print(
        '⚠️ Conexión perdida mientras estaba en segundo plano, reconectando...',
      );
      _shouldAutoReconnect = true;
      _reconnectAttempts = 0;
      _isConnecting = false;
      
      // Reconectar después de un pequeño delay para que el sistema se estabilice
      print('💻 Reconectando después de 2 segundos...');
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && !_isConnected && _token != null) {
          _connect();
        }
      });
    } else if (_isConnected) {
      print('✅ Conexión WebSocket sigue activa - todo funcionando correctamente');
      // Reiniciar timers si estaban cancelados (Windows)
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

  /// Limpia el historial de mensajes tanto en memoria como en almacenamiento persistente
  Future<void> clearHistory() async {
    // Limpiar listas en memoria
    _messages.clear();
    _historyItems.clear();

    try {
      // Limpiar mensajes en almacenamiento persistente
      await ConfigService.clearMessages();

      // Notificar a los oyentes sobre el cambio
      _safeNotifyListeners();

      print('Historial de impresión limpiado correctamente');
    } catch (e) {
      print('Error al limpiar el historial: $e');
    }
  }
}
