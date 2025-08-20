import 'dart:io' show Platform;
import 'package:anfibius_uwu/configuraciones.dart';
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
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

    // Configurar inicio automático con Windows
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: '', // La ruta se configura automáticamente en Windows
    );

    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      skipTaskbar: false,
      title: "Anfibius Connect Nexus Utility",
      minimumSize: Size(400, 300),
    );

    // Configurar para que no se cierre la aplicación al cerrar la ventana
    await windowManager.setPreventClose(true);
    await windowManager.setMinimizable(true);

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Configurar el icono de la bandeja del sistema
    try {
      await trayManager.setIcon(
        'assets/icon/app_icon.ico', // Usamos el icono .ico para Windows
      );
    } catch (e) {
      // Si no existe el icono .ico, usaremos el .png como respaldo
      await trayManager.setIcon('assets/icon/app_icon.ico');
    }

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
  }

  await NotificationsService().init();

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
  void onWindowClose() async {
    if (!_isDesktop()) return;

    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      minimizeToTray(); // Minimiza a la bandeja del sistema
    }
  }

  void minimizeToTray() async {
    if (!_isDesktop()) return;

    await windowManager.hide();
    // Opcional: mostrar notificación cuando se minimiza a la bandeja
    NotificationsService().showNotification(
      id: 1, // ID único para esta notificación
      title: 'Anfibius Web Connect Utility',
      body: 'La aplicación sigue ejecutándose en segundo plano',
    );
  }

  @override
  void onTrayIconMouseDown() {
    if (!_isDesktop()) return;

    windowManager
        .show(); // Muestra la ventana al hacer clic en el ícono de la bandeja
    windowManager.focus(); // Aseguramos que la ventana tome el foco
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
