import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:anfibius_uwu/configuraciones.dart';
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:anfibius_uwu/nfc_reader_screen.dart';
import 'package:anfibius_uwu/services/nfc_pcsc_service.dart';
import 'package:anfibius_uwu/services/nfc_service.dart';
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/logger_service.dart';
import 'package:anfibius_uwu/settings_screen.dart';
import 'package:anfibius_uwu/logs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/printers.dart';
import 'package:anfibius_uwu/services/notifications_service.dart';

// Solo importar dependencias de escritorio en plataformas compatibles
import 'package:package_info_plus/package_info_plus.dart';

// Importaciones condicionales para escritorio
import 'package:anfibius_uwu/secondary_window.dart'
    if (dart.library.html) 'package:anfibius_uwu/secondary_window_stub.dart';
import 'package:tray_manager/tray_manager.dart'
    if (dart.library.html) 'package:anfibius_uwu/platform_stubs.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.html) 'package:anfibius_uwu/platform_stubs.dart';

import 'package:launch_at_startup/launch_at_startup.dart'
    if (dart.library.html) 'package:anfibius_uwu/platform_stubs.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart'
    if (dart.library.html) 'package:anfibius_uwu/platform_stubs.dart';

// Importar servicio de primer plano para Android
import 'package:anfibius_uwu/services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:anfibius_uwu/nfc_reader_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); 
final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();


void main(List<String> args) async {
  // Capturar TODOS los errores no manejados (síncronos Y asíncronos)
  runZonedGuarded(
    () async {
      await _mainInit(args);
    },
    (error, stack) {
      // Capturar errores asíncronos que ocurren en callbacks, timers, etc.
      print('❌ [${DateTime.now()}] Error asíncrono no manejado: $error');
      print('📋 Stack trace: $stack');
      // NO dejar que la app crashee - solo loggear el error
    },
  );
}

Future<void> _mainInit(List<String> args) async {
  // Capturar errores síncronos de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ [${DateTime.now()}] Flutter Error: ${details.exception}');
    print('📋 StackTrace: ${details.stack}');

    // También guardar en archivo de log si está disponible
    try {
      logger.error(
        'Flutter Error: ${details.exception}',
        stackTrace: details.stack,
      );
    } catch (e) {
      // Si falla el logger, solo mostrar en consola
    }
    // NO dejar que la app crashee - solo loggear el error
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 Inicializar servicios
  try {
    await logger.init();
    logger.success('Logger Service inicializado');
  } catch (e) {
    print('❌ Error inicializando Logger Service: $e');
  }

  // Inicializar servicio de primer plano en Android
  if (Platform.isAndroid) {
    PrinterForegroundService.initForegroundTask();
    logger.info('Servicio de primer plano inicializado para Android');
    NotificationsService().initNotifications();
  }

  // Solo ejecutar funcionalidades de escritorio en plataformas compatibles
  if (_isDesktop()) {
    // Verificar si es una ventana secundaria
    if (args.isNotEmpty && args.first == 'multi_window') {
      final windowId = int.parse(args[1]);
      final argument = args[2].isEmpty ? '{}' : args[2];

      // NO USAR windowManager en ventanas secundarias, causa error
      // Configurar y ejecutar la ventana secundaria
      runApp(
        SecondaryWindowApp(
          windowId: windowId,
          argument: argument,
          windowController: WindowController.fromWindowId(windowId),
        ),
      );
      return;
    }

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);

    // Configurar inicio automático con Windows
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName:
            packageInfo.appName.isNotEmpty
                ? packageInfo.appName
                : 'Anfibius Connect Nexus Utility',
        appPath: Platform.resolvedExecutable,
      );
      print('✅ Launch at startup configurado');
    } catch (e) {
      print('❌ Error configurando launch at startup: $e');
    }

    // Configurar el icono de la bandeja del sistema
    try {
      await trayManager.setIcon(
        'assets/icon/app_icon.ico', // Usamos el icono .ico para Windows
      );

      await trayManager.setToolTip('Anfibius Connect Nexus Utility');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Mostrar'),
            MenuItem.separator(),
            MenuItem(key: 'settings', label: 'Configuración'),
            MenuItem(key: 'printers', label: 'Impresoras'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Salir'),
          ],
        ),
      );
      print('✅ Tray manager configurado correctamente');
    } catch (e) {
      print('❌ Error configurando tray manager: $e');
      // Continuar sin tray manager si hay error
    }
  }

  try {
    await NotificationsService().init();
  } catch (e) {
    print('❌ Error inicializando NotificationsService: $e');
    // Continuar sin notificaciones si hay error
  }

  print('🚀 [${DateTime.now()}] Iniciando aplicación...');
  runApp(const MyApp());
}

bool _isDesktop() {
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (e) {
    return false; // Si no puede determinar la plataforma, asume que no es escritorio
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketService()),
        ChangeNotifierProvider(create: (_) => PrinterService()),
        ProxyProvider<PrinterService, PrintJobService>(
          update: (_, printerService, __) => PrintJobService(printerService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => StartupService()..init()),
        ChangeNotifierProvider(create: (_) => NfcPcscService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Envolver con WithForegroundTask solo en Android
          if (Platform.isAndroid) {
            return WithForegroundTask(
              child: MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'Anfibius Connect Nexus Utility',
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.lightGreen,
                  ),
                  useMaterial3: true,
                ),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.lightGreen,
                    brightness: Brightness.dark,
                  ),
                  useMaterial3: true,
                ),
                themeMode: themeService.themeMode,
                home: const MyHomePage(title: 'Anfibius Connect Nexus Utility'),
                routes: {
                  '/nfc': (context) => const NfcScreen(),
                },
              ),
            );
          }

          // Para otras plataformas, usar MaterialApp directamente
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Anfibius Connect Nexus Utility',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.lightGreen,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeService.themeMode,
            home: const MyHomePage(title: 'Anfibius Connect Nexus Utility'),
            routes: {
                  '/nfc': (context) => const NfcScreen(),
                },
          );
        },
      ),
    );
  }
}

// Servicio para gestionar el tema de la aplicación
class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isSystemTheme => _themeMode == ThemeMode.system;
  bool get isDarkMode =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TrayListener, WindowListener, WidgetsBindingObserver {
  WindowController? window;
  final Map<int, WindowController> _childWindows = {};

  // 🛡️ Flag para saber si estamos en suspensión (evita crashes en window_manager/tray_manager)
  bool _isSystemSuspended = false;

  @override
  void initState() {
    super.initState();

    // Agregar observer del ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);

    // Solo configurar listeners de escritorio si estamos en una plataforma compatible
    if (_isDesktop()) {
      trayManager.addListener(this);
      windowManager.addListener(this);

      // Configurar el receptor de mensajes desde ventanas secundarias
      DesktopMultiWindow.setMethodHandler(_handleMethodCallback);
    }

    // Iniciar servicio de primer plano en Android
    if (Platform.isAndroid) {
      _startForegroundService();
    }

    // Configurar la impresión automática cuando llegan mensajes por WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAutoPrint();
    });
  }

  Future<void> _startForegroundService() async {
    try {
      // Iniciar el servicio de primer plano
      final result = await PrinterForegroundService.startService();

      print('✅ Servicio de primer plano iniciado: $result');

      // Configurar callback para recibir datos del servicio
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    } catch (e) {
      print('❌ Error al iniciar servicio de primer plano: $e');
    }
  }

  void _onReceiveTaskData(Object data) {
    // 🛡️ PROTECCIÓN: Envolver en try-catch
    try {
      if (data is Map) {
        print(
          '📨 [${DateTime.now()}] Datos recibidos del servicio de primer plano: $data',
        );

        final type = data['type'];

        if (type == 'heartbeat') {
          // El servicio sigue activo, actualizar UI si es necesario
          print(
            '💓 [${DateTime.now()}] Heartbeat del servicio - Todo funcionando correctamente',
          );
        } else if (type == 'check_websocket') {
          // Verificar que el WebSocket sigue conectado
          try {
            final webSocketService = Provider.of<WebSocketService>(
              context,
              listen: false,
            );

            if (!webSocketService.isConnected) {
              print(
                '⚠️ [${DateTime.now()}] WebSocket desconectado detectado por el servicio, reconectando...',
              );
              webSocketService.onAppResumed();
            } else {
              print(
                '✅ [${DateTime.now()}] WebSocket confirmado como activo por verificación del servicio',
              );
            }
          } catch (e) {
            print('❌ [${DateTime.now()}] Error al verificar WebSocket: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en _onReceiveTaskData: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 🛡️ PROTECCIÓN: Envolver en try-catch
    try {
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );

      // 🆕 Obtener el PrinterService
      final printerService = Provider.of<PrinterService>(
        context,
        listen: false,
      );

      print(
        '📱 [${DateTime.now()}] Cambio de estado del ciclo de vida: $state',
      );

      switch (state) {
        case AppLifecycleState.paused:
          // App va a segundo plano o laptop entra en suspensión
          print(
            '📱 [${DateTime.now()}] App pausada (segundo plano/suspensión)',
          );

          // 🛡️ CRÍTICO: Marcar como suspendido ANTES de cualquier otra operación
          _isSystemSuspended = true;

          try {
            webSocketService.onAppPaused();
          } catch (e, stackTrace) {
            print('❌ [${DateTime.now()}] Error en onAppPaused: $e');
            print('📋 Stack trace: $stackTrace');
          }

          // 🆕 CRÍTICO: Pausar servicio de impresoras para evitar ACCESS_VIOLATION en FFI
          try {
            printerService.pauseService();
          } catch (e, stackTrace) {
            print('❌ [${DateTime.now()}] Error pausando PrinterService: $e');
            print('📋 Stack trace: $stackTrace');
          }

          if (Platform.isAndroid) {
            try {
              PrinterForegroundService.updateNotification(
                title: 'Servicio en segundo plano',
                text: 'Escuchando órdenes de impresión...',
              );
            } catch (e) {
              print(
                '⚠️ [${DateTime.now()}] Error actualizando notificación: $e',
              );
            }
          }
          break;

        case AppLifecycleState.resumed:
          // App vuelve a primer plano o laptop sale de suspensión
          print(
            '📱 [${DateTime.now()}] App reanudada (primer plano/despertar)',
          );

          // En Windows, esperar un poco para que el sistema se estabilice después de suspensión
          if (Platform.isWindows) {
            print(
              '💻 Windows: Esperando 3 segundos para estabilización del sistema...',
            );
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                // 🛡️ Marcar como NO suspendido
                _isSystemSuspended = false;

                try {
                  webSocketService.onAppResumed();
                } catch (e, stackTrace) {
                  print(
                    '❌ [${DateTime.now()}] Error en onAppResumed (delayed): $e',
                  );
                  print('📋 Stack trace: $stackTrace');
                }

                // 🆕 Reanudar servicio de impresoras
                try {
                  printerService.resumeService();
                } catch (e, stackTrace) {
                  print(
                    '❌ [${DateTime.now()}] Error reanudando PrinterService: $e',
                  );
                  print('📋 Stack trace: $stackTrace');
                }
              }
            });
          } else {
            // En otras plataformas, llamar inmediatamente
            _isSystemSuspended = false;

            try {
              webSocketService.onAppResumed();
            } catch (e, stackTrace) {
              print('❌ [${DateTime.now()}] Error en onAppResumed: $e');
              print('📋 Stack trace: $stackTrace');
            }

            try {
              printerService.resumeService();
            } catch (e, stackTrace) {
              print(
                '❌ [${DateTime.now()}] Error reanudando PrinterService: $e',
              );
              print('📋 Stack trace: $stackTrace');
            }
          }

          if (Platform.isAndroid) {
            try {
              PrinterForegroundService.updateNotification(
                title: 'Servicio de Impresión Activo',
                text: 'App en primer plano',
              );
            } catch (e) {
              print(
                '⚠️ [${DateTime.now()}] Error actualizando notificación: $e',
              );
            }
          }
          break;

        case AppLifecycleState.inactive:
          print('📱 [${DateTime.now()}] App inactiva');
          break;

        case AppLifecycleState.detached:
          print('📱 [${DateTime.now()}] App desconectada');
          break;

        case AppLifecycleState.hidden:
          print('📱 [${DateTime.now()}] App oculta');
          // En Windows, hidden puede ocurrir antes de paused
          if (Platform.isWindows) {
            // 🛡️ CRÍTICO: Marcar como suspendido INMEDIATAMENTE
            _isSystemSuspended = true;

            try {
              webSocketService.onAppPaused();
            } catch (e, stackTrace) {
              print(
                '❌ [${DateTime.now()}] Error en onAppPaused desde hidden: $e',
              );
              print('📋 Stack trace: $stackTrace');
            }

            // 🆕 También pausar PrinterService
            try {
              final printerService = Provider.of<PrinterService>(
                context,
                listen: false,
              );
              printerService.pauseService();
            } catch (e, stackTrace) {
              print(
                '❌ [${DateTime.now()}] Error pausando PrinterService desde hidden: $e',
              );
              print('📋 Stack trace: $stackTrace');
            }
          }
          break;
      }
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en didChangeAppLifecycleState: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  void _setupAutoPrint() {
    // 🛡️ Verificar que el widget sigue montado
    if (!mounted) {
      print('⚠️ Widget no montado, abortando setup de auto print');
      return;
    }
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    final printJobService = Provider.of<PrintJobService>(
      context,
      listen: false,
    );
    final printerService = Provider.of<PrinterService>(context, listen: false);
    // Configurar el callback para notificar cuando se necesita reiniciar (zombie state)
    webSocketService.onNeedRestart = () {
      // 🛡️ Verificar que el widget sigue montado antes de mostrar el diálogo
      if (!mounted) return;

      // Mostrar diálogo informando al usuario que la app necesita reiniciarse
      showDialog(
        context: context,
        barrierDismissible: false, // No permitir cerrar tocando fuera
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Reinicio Requerido'),
              ],
            ),
            content: const Text(
              'La conexión con el servidor ha dejado de responder. '
              'Por favor, reinicia la aplicación para restablecer la conexión.\n\n'
              'Esto puede ocurrir después de que la laptop entre en suspensión.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Cerrar la aplicación para forzar reinicio
                  if (Platform.isWindows ||
                      Platform.isLinux ||
                      Platform.isMacOS) {
                    windowManager.close();
                  } else {
                    SystemNavigator.pop();
                  }
                },
                child: const Text('Reiniciar Ahora'),
              ),
            ],
          );
        },
      );
    };

    // Configurar el callback para imprimir automáticamente cuando llegue un mensaje
    webSocketService.onNewMessage = (String jsonMessage) async {
      // 🛡️ PROTECCIÓN: Envolver TODO en try-catch para evitar crashes
      try {
        print(
          '🖨️ [${DateTime.now()}] Procesando impresión automática para mensaje: ${jsonMessage.length > 100 ? "${jsonMessage.substring(0, 100)}..." : jsonMessage}',
        );

        // Validar tipos permitidos antes de procesar
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
            return;
          }

          // Buscar el tipo en ambos campos posibles: 'type' y 'tipo'
          final String? type =
              data['type']?.toString() ?? data['tipo']?.toString();

          // **NUEVO: Extraer el nombre de la impresora del mensaje**
          final String? targetPrinterName =
              data['printer']?.toString() ??
              data['impresora']?.toString() ??
              data['printerName']?.toString();

          const List<String> allowedTypes = [
            'COMANDA',
            'PREFACTURA',
            'VENTA',
            'TEST',
            'SORTEO',
            'NFC', // Agregado NFC a tipos permitidos para historial
          ];

          if (type == null || !allowedTypes.contains(type.toUpperCase())) {
            return; // Salir silenciosamente sin mostrar notificación de error
          }

          if (type.toUpperCase() == 'NFC') {
            if (Platform.isAndroid || Platform.isIOS) {
              print(
                '📡 Tipo de mensaje es para lectura NFC, iniciando proceso de lectura...',
              );
              await nfc.startNFC();
              return;
            } else if (Platform.isWindows) {
              print(
                '📡 Tipo de mensaje es para lectura NFC, iniciando proceso de lectura con PCSC...',
              );
              await nfcPcsc.startNFC(webSocketService);
              return;
            }
          }

          // **NUEVO: Mostrar información de impresora solicitada**
          if (targetPrinterName != null) {
            print('🎯 Impresora solicitada: $targetPrinterName');
          } else {
            print(
              '⚠️ No se especificó impresora en el mensaje, usando la seleccionada por defecto',
            );
          }
        } catch (e) {
          print('❌ Error al parsear mensaje JSON: $e');
          return; // Salir silenciosamente si no se puede parsear el JSON
        }

        // Verificar si hay impresoras disponibles - mejorar la validación
        bool hasAvailablePrinters = false;

        if (printerService.selectedPrinter != null) {
          hasAvailablePrinters = true;
          print(
            '✅ Impresora seleccionada disponible: ${printerService.selectedPrinter?.deviceName}',
          );
        } else if (printerService.connectedPrinters.isNotEmpty) {
          hasAvailablePrinters = true;
          print(
            '✅ Impresoras conectadas disponibles: ${printerService.connectedPrinters.keys.join(", ")}',
          );
        }

        if (!hasAvailablePrinters) {
          print(
            '⚠️ No hay impresoras conectadas o seleccionadas para procesar la impresión',
          );
          NotificationsService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: 'Sin impresoras',
            body:
                'No hay impresoras configuradas para procesar la orden de impresión',
          );
          return;
        }

        print('📤 Enviando solicitud de impresión al PrintJobService...');
        final success = await printJobService.processPrintRequest(jsonMessage);

        if (success) {
          print('✅ Impresión procesada exitosamente');
          // Mostrar notificación de éxito
          NotificationsService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: 'Impresión realizada',
            body: 'Se ha procesado una nueva orden de impresión',
          );
        } else {
          print('❌ Error al procesar la impresión');
          // Mostrar notificación de error
          NotificationsService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: 'Error de impresión',
            body:
                'No se pudo procesar la orden de impresión. Verifique la configuración de impresoras.',
          );
        }
      } catch (e, stackTrace) {
        print('❌ [${DateTime.now()}] Error en impresión automática: $e');
        print('📋 Stack trace: $stackTrace');

        // 🛡️ PROTECCIÓN: No dejar que las notificaciones crasheen
        try {
          NotificationsService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: 'Error de impresión',
            body: 'Error al procesar la orden: $e',
          );
        } catch (notificationError) {
          print(
            '⚠️ [${DateTime.now()}] No se pudo mostrar notificación: $notificationError',
          );
        }
      }
    };

    print('✅ Impresión automática configurada correctamente');
    print(
      '🔗 Callback del WebSocket asignado: ${webSocketService.onNewMessage != null}',
    );
  }

  // Manejador de mensajes desde ventanas secundarias
  Future<dynamic> _handleMethodCallback(
    MethodCall call,
    int fromWindowId,
  ) async {
    if (!_isDesktop()) return;

    debugPrint('Mensaje recibido de la ventana $fromWindowId: ${call.method}');

    switch (call.method) {
      case 'onWindowClose':
        final windowId = call.arguments as int;
        setState(() {
          _childWindows.remove(windowId);
        });
        debugPrint(
          'Ventana $windowId eliminada. Ventanas restantes: ${_childWindows.length}',
        );
        break;
      case 'onDataReceived':
        final data = call.arguments as String;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos recibidos de la ventana $fromWindowId: $data'),
          ),
        );
        break;
    }

    return Future.value();
  }

  @override
  void dispose() {
    // Remover observer del ciclo de vida
    WidgetsBinding.instance.removeObserver(this);

    // Remover callback del servicio de primer plano
    if (Platform.isAndroid) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }

    if (_isDesktop()) {
      // Cerrar todas las ventanas secundarias al cerrar la ventana principal
      for (final window in _childWindows.values) {
        window.close();
      }
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }

    // 🆕 Cerrar el logger service
    logger.dispose();

    super.dispose();
  }

  @override
  void onWindowClose() {
    // 🛡️ PROTECCIÓN: No llamar a minimizeToTray durante suspensión
    if (_isSystemSuspended) {
      print(
        '⚠️ [${DateTime.now()}] Sistema suspendido, ignorando onWindowClose',
      );
      return;
    }

    try {
      minimizeToTray();
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en onWindowClose: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  void minimizeToTray() async {
    if (!_isDesktop()) return;

    // 🛡️ PROTECCIÓN: No llamar a windowManager durante suspensión
    if (_isSystemSuspended) {
      print(
        '⚠️ [${DateTime.now()}] Sistema suspendido, ignorando minimizeToTray',
      );
      return;
    }

    try {
      await windowManager.hide();
      // Mostrar notificación cuando se minimiza a la bandeja
      NotificationsService().showNotification(
        id: 1, // ID único para esta notificación
        title: 'Anfibius Connect Nexus Utility',
        body:
            'La aplicación continúa ejecutándose en segundo plano. Haz clic en el ícono de la bandeja para mostrarla nuevamente.',
      );
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en minimizeToTray: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (!_isDesktop()) return;

    // 🛡️ PROTECCIÓN: No llamar a windowManager durante suspensión
    if (_isSystemSuspended) {
      print(
        '⚠️ [${DateTime.now()}] Sistema suspendido, ignorando onTrayIconMouseDown',
      );
      return;
    }

    try {
      windowManager.show();
      windowManager.focus();
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en onTrayIconMouseDown: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (!_isDesktop()) return;

    // 🛡️ PROTECCIÓN: No llamar a windowManager durante suspensión
    if (_isSystemSuspended) {
      print(
        '⚠️ [${DateTime.now()}] Sistema suspendido, ignorando onTrayMenuItemClick: ${item.key}',
      );
      return;
    }

    try {
      switch (item.key) {
        case 'show':
          windowManager.show();
          windowManager.focus();
          break;
        case 'settings':
          windowManager.show();
          windowManager.focus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GeneralSettingsScreen(),
              ),
            );
          });
          break;
        case 'printers':
          windowManager.show();
          windowManager.focus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrinterConfig()),
            );
          });
          break;
        case 'exit':
          windowManager.destroy();
          SystemNavigator.pop();
          break;
      }
    } catch (e, stackTrace) {
      print('❌ [${DateTime.now()}] Error en onTrayMenuItemClick: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        surfaceTintColor: Colors.lightGreen,
        actions: [
          // Botón para ver logs
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
            tooltip: 'Ver logs del sistema',
          ),
          // Botón de tema
          IconButton(
            icon: Icon(
              themeService.isSystemTheme
                  ? Icons.brightness_auto
                  : themeService.isDarkMode
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              themeService.toggleTheme();
            },
            tooltip: 'Cambiar tema',
          ),
        ],
      ),
      body: const Dispositivos(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón de reconexión manual
          Consumer<WebSocketService>(
            builder: (context, webSocketService, child) {
              // Solo mostrar si no está conectado
              if (!webSocketService.isConnected) {
                return FloatingActionButton(
                  onPressed: () {
                    print(
                      '🔄 [${DateTime.now()}] Reconexión manual solicitada por el usuario',
                    );

                    // Mostrar mensaje de carga
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reconectando...'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Forzar reconexión
                    webSocketService.reconnect();
                  },
                  heroTag: 'reconnect_websocket',
                  tooltip: 'Reconectar al servidor',
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.wifi_off),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),

          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Configuraciones()),
              );
            },
            heroTag: 'general_settings',
            tooltip: 'Configuración',
            child: const Icon(Icons.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
