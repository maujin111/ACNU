import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:window_manager/window_manager.dart';

final List<String> imgList = [
  'https://santasalitas.com/wp-content/uploads/2025/05/Lunes.png',
  'https://santasalitas.com/wp-content/uploads/2025/05/martes.png',
  'https://santasalitas.com/wp-content/uploads/2025/05/miercoles.png',
  'https://santasalitas.com/wp-content/uploads/2025/05/domingo2.png',
];

class SecondaryWindowApp extends StatefulWidget {
  final int windowId;
  final String argument;
  final WindowController windowController;
  const SecondaryWindowApp({
    super.key,
    required this.windowId,
    required this.argument,
    required this.windowController,
  });
  @override
  State<SecondaryWindowApp> createState() => _SecondaryWindowAppState();
}

class _SecondaryWindowAppState extends State<SecondaryWindowApp>
    with WindowListener {
  Map<String, dynamic> _receivedData = {};
  final List<String> _messages = [];
  // bool _isFullScreen = false; // Original
  bool _isFullScreen =
      true; // Modificado: La ventana inicia en pantalla completa
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initWindow();
    // Configurar el manejador de mensajes
    DesktopMultiWindow.setMethodHandler(_handleMethodCallback);
    // La solicitud de foco se gestionará dentro de _initWindow
    // después de que la ventana esté configurada.
  }

  @override
  void dispose() {
    _focusNode.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  // Manejar el cierre de la ventana
  @override
  void onWindowClose() async {
    // Notificar a la ventana principal que esta ventana se ha cerrado
    await _notifyWindowClosed();
    // Pequeña pausa para asegurar que la notificación se envíe correctamente
    await Future.delayed(const Duration(milliseconds: 300));
    // Cerrar completamente la ventana
    windowManager.destroy();
  }

  Future<void> _initWindow() async {
    await windowManager.waitUntilReadyToShow();
    windowManager.addListener(this);
    // await windowManager.setFullScreen(true); // Original
    // Usar el estado _isFullScreen que ya está inicializado a true
    await windowManager.setFullScreen(_isFullScreen);

    // Solicitar foco después de que la ventana esté configurada y visible.
    // Esto es crucial para que KeyboardListener funcione desde el inicio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Asegurarse de que el widget todavía está en el árbol
        _focusNode.requestFocus();
      }
    });
  }

  // Notificar a la ventana principal que esta ventana se ha cerrado
  Future<void> _notifyWindowClosed() async {
    try {
      // Intentar enviar múltiples veces para asegurar que la notificación llegue
      for (int i = 0; i < 3; i++) {
        try {
          await DesktopMultiWindow.invokeMethod(
            0, // ID de la ventana principal
            'onWindowClose',
            widget.windowId,
          ).timeout(const Duration(milliseconds: 500));

          debugPrint(
            'Notificación de cierre enviada correctamente: ${widget.windowId}',
          );
          break; // Si tiene éxito, salimos del bucle
        } catch (e) {
          debugPrint('Intento $i fallido: $e');
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint(
        'Error al notificar cierre de ventana después de múltiples intentos: $e',
      );
    }
  }

  // Manejador de mensajes desde la ventana principal
  Future<dynamic> _handleMethodCallback(
    MethodCall call,
    int fromWindowId,
  ) async {
    debugPrint('Mensaje recibido de la ventana $fromWindowId: ${call.method}');

    if (call.method == 'receiveData') {
      final data = call.arguments as String;
      setState(() {
        _receivedData = jsonDecode(data);
        _messages.add(
          'Recibido: ${_receivedData['message']} (${DateTime.now().toIso8601String()})',
        );
      });

      // Opcionalmente, enviamos una confirmación de vuelta
      DesktopMultiWindow.invokeMethod(
        0, // ID de la ventana principal
        'onDataReceived',
        'Datos recibidos correctamente en ventana ${widget.windowId}',
      );
    } else if (call.method == 'ping') {
      // Responder al ping para indicar que la ventana sigue activa
      debugPrint('Ping recibido de la ventana principal, respondiendo pong');
      return "pong";
    } else if (call.method == 'closeWindow') {
      // Cerrar la ventana secundaria
      windowManager.close();
    }

    return Future.value();
  }

  // Función para alternar el modo de pantalla completa
  Future<void> _toggleFullScreen() async {
    try {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
      await windowManager.setFullScreen(_isFullScreen);
      // Volver a solicitar el foco después de cambiar el modo de pantalla completa,
      // ya que la ventana puede perder el foco durante esta operación.
      _focusNode.requestFocus();
    } catch (e) {
      debugPrint('Error al cambiar modo pantalla completa: $e');
    }
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        _toggleFullScreen();
      } else if (event.logicalKey == LogicalKeyboardKey.escape &&
          _isFullScreen) {
        _toggleFullScreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      themeMode: ThemeMode.system,
      home: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: CarouselSlider(
            options: CarouselOptions(
              autoPlay: true,
              aspectRatio: 2.0,
              enlargeCenterPage: true,
            ),
            items:
                imgList
                    .map(
                      (item) => Container(
                        child: Center(
                          child: Image.network(
                            item,
                            fit: BoxFit.cover,
                            width: 1000,
                            height: height,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleFullScreen,
            tooltip:
                _isFullScreen
                    ? 'Salir de pantalla completa'
                    : 'Pantalla completa',
            child: Icon(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            ),
          ),
        ),
      ),
    );
  }
}
