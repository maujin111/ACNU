import 'dart:convert';
import 'dart:io' show Platform;
import 'package:anfibius_uwu/configuraciones.dart';
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:anfibius_uwu/services/objetivos_service.dart';
import 'package:anfibius_uwu/settings_screen.dart';
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

void main(List<String> args) async {
  // Capturar errores no manejados
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('StackTrace: ${details.stack}');
  };

  WidgetsFlutterBinding.ensureInitialized();

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
    print('✅ NotificationsService inicializado');
  } catch (e) {
    print('❌ Error inicializando NotificationsService: $e');
    // Continuar sin notificaciones si hay error
  }

  print('🚀 Iniciando aplicación...');
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
        ChangeNotifierProvider(create: (_) => FingerprintReaderService()),
        ChangeNotifierProvider(create: (_) => ObjetivosService()),
        ProxyProvider<PrinterService, PrintJobService>(
          update: (_, printerService, __) => PrintJobService(printerService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => StartupService()..init()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
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
    with TrayListener, WindowListener {
  WindowController? window;
  final Map<int, WindowController> _childWindows = {};

  @override
  void initState() {
    super.initState();

    // Solo configurar listeners de escritorio si estamos en una plataforma compatible
    if (_isDesktop()) {
      trayManager.addListener(this);
      windowManager.addListener(this);

      // Configurar el receptor de mensajes desde ventanas secundarias
      DesktopMultiWindow.setMethodHandler(_handleMethodCallback);
    }

    // Configurar la impresión automática cuando llegan mensajes por WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAutoPrint();
      _setupFingerprintIntegration();
    });
  }

  void _setupAutoPrint() {
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    final printJobService = Provider.of<PrintJobService>(
      context,
      listen: false,
    );
    final printerService = Provider.of<PrinterService>(context, listen: false);

    // Configurar el callback para imprimir automáticamente cuando llegue un mensaje
    webSocketService.onNewMessage = (String jsonMessage) async {
      try {
        print(
          '🖨️ Procesando impresión automática para mensaje: ${jsonMessage.length > 100 ? "${jsonMessage.substring(0, 100)}..." : jsonMessage}',
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
            print('❌ Formato de mensaje no válido');
            return;
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
              '⚠️ Tipo de documento "$type" no permitido. Solo se permiten: ${allowedTypes.join(", ")}',
            );
            return; // Salir silenciosamente sin mostrar notificación de error
          }

          print('✅ Tipo de documento válido: $type');
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
        print('❌ Error en impresión automática: $e');
        print('📋 Stack trace: $stackTrace');
        NotificationsService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: 'Error de impresión',
          body: 'Error al procesar la orden: $e',
        );
      }
    };

    print('✅ Impresión automática configurada correctamente');
    print(
      '🔗 Callback del WebSocket asignado: ${webSocketService.onNewMessage != null}',
    );
  }

  void _setupFingerprintIntegration() {
    final webSocketService = Provider.of<WebSocketService>(
      context,
      listen: false,
    );
    final fingerprintService = Provider.of<FingerprintReaderService>(
      context,
      listen: false,
    );
    final objetivosService = Provider.of<ObjetivosService>(
      context,
      listen: false,
    );

    // Configurar el callback para enviar huellas por WebSocket cuando se detecten
    fingerprintService.onFingerprintRead = (String fingerprintData) async {
      try {
        print('👆 Enviando huella dactilar por WebSocket...');
        print(
          '📄 Datos de huella: ${fingerprintData.length > 100 ? "${fingerprintData.substring(0, 100)}..." : fingerprintData}',
        );

        // OBJETIVO 1: Detectar huella automáticamente ✅
        await objetivosService.completarObjetivo('detectar_huella');

        // Enviar los datos de la huella directamente por WebSocket
        await webSocketService.sendMessage(fingerprintData);

        // OBJETIVO 2: Enviar por WebSocket ✅
        await objetivosService.completarObjetivo('enviar_websocket');

        // OBJETIVO 3: Registrar estado ✅
        await objetivosService.completarObjetivo('registrar_estado');

        print('✅ Huella dactilar enviada por WebSocket exitosamente');
        // Mostrar notificación de éxito
        NotificationsService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: 'Huella detectada',
          body:
              'Huella dactilar enviada correctamente por WebSocket (${objetivosService.getResumenProgreso()})',
        );
      } catch (e, stackTrace) {
        print('❌ Error al enviar huella por WebSocket: $e');
        print('📋 Stack trace: $stackTrace');

        NotificationsService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: 'Error de huella',
          body: 'No se pudo enviar la huella por WebSocket: $e',
        );
      }
    };

    // Configurar el callback de cambio de conexión
    fingerprintService.onConnectionChanged = (bool isConnected) {
      print(
        isConnected
            ? '✅ Lector de huellas conectado exitosamente'
            : '❌ Lector de huellas desconectado',
      );

      NotificationsService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        title: isConnected ? 'Lector conectado' : 'Lector desconectado',
        body:
            isConnected
                ? 'El lector de huellas está listo para usar'
                : 'Se perdió la conexión con el lector de huellas',
      );
    };

    print('✅ Integración de lector de huellas configurada correctamente');
    print('🔗 Callbacks del servicio de huellas asignados');
    print(
      '🎯 Estado inicial de objetivos: ${objetivosService.getResumenProgreso()}',
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
    if (_isDesktop()) {
      // Cerrar todas las ventanas secundarias al cerrar la ventana principal
      for (final window in _childWindows.values) {
        window.close();
      }
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() {
    minimizeToTray();
  }

  void minimizeToTray() async {
    if (!_isDesktop()) return;

    await windowManager.hide();
    // Mostrar notificación cuando se minimiza a la bandeja
    NotificationsService().showNotification(
      id: 1, // ID único para esta notificación
      title: 'Anfibius Connect Nexus Utility',
      body:
          'La aplicación continúa ejecutándose en segundo plano. Haz clic en el ícono de la bandeja para mostrarla nuevamente.',
    );
  }

  @override
  void onTrayIconMouseDown() {
    if (!_isDesktop()) return;

    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (!_isDesktop()) return;

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
