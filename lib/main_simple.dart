import 'dart:io' show Platform;
import 'package:anfibius_uwu/dispositivos.dart';
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/services/notifications_service.dart';

// Importaciones condicionales para escritorio (sin window_manager por problemas)
import 'package:tray_manager/tray_manager.dart'
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
        ChangeNotifierProvider(create: (_) => StartupService()),
        ProxyProvider2<PrinterService, WebSocketService, PrintJobService>(
          update:
              (_, printerService, webSocketService, __) =>
                  PrintJobService(printerService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Anfibius Connect Nexus Utility',
            theme: themeService.currentTheme,
            home: const MyHomePage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, TrayListener {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    Dispositivos(),
    Text('Impresoras - En desarrollo'),
    Text('Configuración - En desarrollo'),
    GeneralSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isDesktop()) {
      trayManager.addListener(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isDesktop()) {
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) {
      // Cuando la aplicación se oculta (minimiza a bandeja)
      print('App minimizada a bandeja del sistema');
    } else if (state == AppLifecycleState.resumed) {
      // Cuando la aplicación vuelve a primer plano
      print('App restaurada desde bandeja del sistema');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void onTrayIconMouseDown() {
    // Mostrar la ventana cuando se hace clic en el icono de la bandeja
    print('Tray icon clicked - showing window');
    // Sin window_manager, no podemos controlar la ventana de la misma manera
  }

  @override
  void onTrayIconRightMouseDown() {
    // El menú contextual se muestra automáticamente
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        print('Showing window from tray menu');
        // Sin window_manager, no podemos mostrar la ventana
        break;
      case 'settings':
        _onItemTapped(3);
        break;
      case 'printers':
        _onItemTapped(1);
        break;
      case 'exit':
        SystemNavigator.pop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Dispositivos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.print), label: 'Impresoras'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Sistema'),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

// Servicio para manejar temas
class ThemeService extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme {
    return _isDarkMode ? ThemeData.dark() : ThemeData.light();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
