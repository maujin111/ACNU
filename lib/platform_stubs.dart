// Stubs para plataformas no compatibles con escritorio

import 'dart:ui' show Size, Rect;
import 'package:flutter/services.dart';

// Stub para tray_manager
class TrayManager {
  static TrayManager get instance => TrayManager();

  Future<void> setIcon(String iconPath) async {}
  Future<void> setToolTip(String tooltip) async {}
  Future<void> setContextMenu(Menu menu) async {}
  void addListener(TrayListener listener) {}
  void removeListener(TrayListener listener) {}
}

class Menu {
  final List<MenuItem> items;
  Menu({required this.items});
}

class MenuItem {
  final String? key;
  final String? label;
  MenuItem({this.key, this.label});
  static MenuItem separator() => MenuItem();
}

class TrayListener {}

final trayManager = TrayManager.instance;

// Stub para window_manager
class WindowManager {
  static WindowManager get instance => WindowManager();

  Future<void> ensureInitialized() async {}
  Future<void> setPreventClose(bool prevent) async {}
  Future<void> setMinimizable(bool minimizable) async {}
  Future<void> waitUntilReadyToShow(
    WindowOptions options,
    Function() callback,
  ) async {
    callback();
  }

  Future<void> show() async {}
  Future<void> focus() async {}
  Future<void> hide() async {}
  Future<void> destroy() async {}
  Future<bool> isPreventClose() async => false;
  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
}

class WindowOptions {
  final Size size;
  final bool center;
  final bool skipTaskbar;
  final String title;
  final Size minimumSize;

  const WindowOptions({
    required this.size,
    required this.center,
    required this.skipTaskbar,
    required this.title,
    required this.minimumSize,
  });
}

class WindowListener {
  void onWindowClose() {}
}

final windowManager = WindowManager.instance;

// Stub para launch_at_startup
class LaunchAtStartup {
  Future<void> setup({
    required String appName,
    required String appPath,
  }) async {}
  Future<bool> isEnabled() async => false;
  Future<void> enable() async {}
  Future<void> disable() async {}
}

final launchAtStartup = LaunchAtStartup();

// Stub para desktop_multi_window
class DesktopMultiWindow {
  static Future<WindowController> createWindow(String jsonArgument) async {
    return WindowController.fromWindowId(0);
  }

  static void setMethodHandler(Function(MethodCall, int) handler) {}

  static Future<dynamic> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async {
    return null;
  }
}

class WindowController {
  final int windowId;

  WindowController.fromWindowId(this.windowId);

  Future<void> setFrame(Rect frame) async {}
  Future<void> center() async {}
  Future<void> setTitle(String title) async {}
  Future<void> show() async {}
  Future<void> close() async {}
}
