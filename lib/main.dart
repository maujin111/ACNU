import 'dart:io' show Platform;
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:anfibius_uwu/services/objetivos_service.dart';
import 'package:anfibius_uwu/services/employee_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/services/notifications_service.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/screens/main_screen.dart';


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
        ChangeNotifierProvider(create: (_) => AuthService()),
        ProxyProvider<AuthService, FingerprintReaderService>(
          update: (_, authService, __) => FingerprintReaderService(authService),
        ),
        ChangeNotifierProvider(create: (_) => ObjetivosService()),
        ProxyProvider<PrinterService, PrintJobService>(
          update: (_, printerService, __) => PrintJobService(printerService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => StartupService()..init()),
        ProxyProvider<AuthService, EmployeeService>(
          update: (_, authService, __) => EmployeeService(authService),
        ),
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
            home: const MainScreen(),
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
