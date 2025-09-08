import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;

  PrinterType typePrinter;
  bool? state;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.state,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isBle = false,
  });

  // Convertir a Map para guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'address': address,
      'port': port,
      'vendorId': vendorId,
      'productId': productId,
      'typePrinter': typePrinter.index,
      'isBle': isBle,
    };
  }

  // Crear desde Map al cargar desde SharedPreferences
  factory BluetoothPrinter.fromJson(Map<String, dynamic> json) {
    return BluetoothPrinter(
      deviceName: json['deviceName'],
      address: json['address'],
      port: json['port'],
      vendorId: json['vendorId'],
      productId: json['productId'],
      typePrinter: PrinterType.values[json['typePrinter']],
      isBle: json['isBle'],
    );
  }
}

class ConfigService {
  static const String _printerKey = 'printer';
  static const String _tokenKey = 'websocket_token';
  static const String _messagesKey = 'websocket_messages';
  static const String _customPaperWidthKey = 'custom_paper_width';
  static const String _usingCustomPaperSizeKey = 'using_custom_paper_size';
  static const String _connectedPrintersKey = 'connected_printers';

  // Guardar la impresora seleccionada
  static Future<void> saveSelectedPrinter(BluetoothPrinter? printer) async {
    final prefs = await SharedPreferences.getInstance();
    if (printer == null) {
      await prefs.remove(_printerKey);
      return;
    }
    await prefs.setString(_printerKey, jsonEncode(printer.toJson()));
  }

  // Cargar la impresora seleccionada
  static Future<BluetoothPrinter?> loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerData = prefs.getString(_printerKey);
    if (printerData == null) return null;

    try {
      return BluetoothPrinter.fromJson(jsonDecode(printerData));
    } catch (e) {
      print('Error al cargar la impresora: $e');
      return null;
    }
  }

  // Guardar el token de WebSocket
  static Future<void> saveWebSocketToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Cargar el token de WebSocket
  static Future<String?> loadWebSocketToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Guardar mensajes recibidos del WebSocket
  static Future<void> saveMessages(List<String> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_messagesKey, messages);
  }

  // Cargar mensajes del WebSocket
  static Future<List<String>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_messagesKey) ?? [];
  }

  // Agregar un nuevo mensaje a la lista
  static Future<void> addMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = prefs.getStringList(_messagesKey) ?? [];
    messages.add(message);
    // Limitar a los últimos 100 mensajes para no ocupar demasiado espacio
    if (messages.length > 100) {
      messages.removeRange(0, messages.length - 100);
    }
    await prefs.setStringList(_messagesKey, messages);
  }

  // Limpiar todos los mensajes almacenados
  static Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_messagesKey, []);
  }

  // Guardar configuración de tamaño de papel personalizado
  static Future<void> saveCustomPaperWidth(int width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customPaperWidthKey, width);
  }

  // Cargar configuración de tamaño de papel personalizado
  static Future<int?> loadCustomPaperWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_customPaperWidthKey);
  }

  // Guardar estado de uso de tamaño personalizado
  static Future<void> saveUsingCustomPaperSize(bool using) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usingCustomPaperSizeKey, using);
  }

  // Cargar estado de uso de tamaño personalizado
  static Future<bool?> loadUsingCustomPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_usingCustomPaperSizeKey);
  }

  // MÉTODOS PARA MÚLTIPLES IMPRESORAS
  // Guardar una impresora conectada
  static Future<void> saveConnectedPrinter(
    String printerName,
    BluetoothPrinter printer,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_connectedPrintersKey}_$printerName';
    await prefs.setString(key, jsonEncode(printer.toJson()));
  }

  // Cargar una impresora conectada por nombre
  static Future<BluetoothPrinter?> loadConnectedPrinter(
    String printerName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_connectedPrintersKey}_$printerName';
    final printerData = prefs.getString(key);
    if (printerData == null) return null;

    try {
      return BluetoothPrinter.fromJson(jsonDecode(printerData));
    } catch (e) {
      print('Error al cargar la impresora $printerName: $e');
      return null;
    }
  }

  // Remover una impresora conectada
  static Future<void> removeConnectedPrinter(String printerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_connectedPrintersKey}_$printerName';
    await prefs.remove(key);
  }

  // Cargar todas las impresoras conectadas
  static Future<Map<String, BluetoothPrinter>>
  loadAllConnectedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(_connectedPrintersKey))
            .toList();

    final Map<String, BluetoothPrinter> printers = {};

    for (final key in keys) {
      final printerName = key.replaceFirst('${_connectedPrintersKey}_', '');
      final printerData = prefs.getString(key);

      if (printerData != null) {
        try {
          final printer = BluetoothPrinter.fromJson(jsonDecode(printerData));
          printers[printerName] = printer;
        } catch (e) {
          print('Error al cargar impresora $printerName: $e');
        }
      }
    }

    return printers;
  }

  // Limpiar todas las impresoras conectadas
  static Future<void> clearAllConnectedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(_connectedPrintersKey))
            .toList();

    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Constantes para tamaños de papel por impresora
  static const String _printerPaperSizeKey = 'printer_paper_size';

  // Guardar tamaño de papel para una impresora específica
  static Future<void> savePrinterPaperSize(
    String printerName,
    PaperSize paperSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_printerPaperSizeKey}_$printerName';

    // Convertir PaperSize a string para guardar
    String paperSizeString;
    if (paperSize == PaperSize.mm58) {
      paperSizeString = 'mm58';
    } else if (paperSize == PaperSize.mm72) {
      paperSizeString = 'mm72';
    } else if (paperSize == PaperSize.mm80) {
      paperSizeString = 'mm80';
    } else {
      paperSizeString = 'mm80'; // por defecto
    }

    await prefs.setString(key, paperSizeString);
  }

  // Cargar tamaño de papel para una impresora específica
  static Future<PaperSize?> loadPrinterPaperSize(String printerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_printerPaperSizeKey}_$printerName';
    final paperSizeString = prefs.getString(key);

    if (paperSizeString != null) {
      switch (paperSizeString) {
        case 'mm58':
          return PaperSize.mm58;
        case 'mm72':
          return PaperSize.mm72;
        case 'mm80':
          return PaperSize.mm80;
        default:
          return PaperSize.mm80;
      }
    }
    return null;
  }

  // Cargar todos los tamaños de papel guardados
  static Future<Map<String, PaperSize>> loadAllPrinterPaperSizes() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(_printerPaperSizeKey))
            .toList();

    final Map<String, PaperSize> paperSizes = {};

    for (final key in keys) {
      final printerName = key.replaceFirst('${_printerPaperSizeKey}_', '');
      final paperSizeString = prefs.getString(key);

      if (paperSizeString != null) {
        switch (paperSizeString) {
          case 'mm58':
            paperSizes[printerName] = PaperSize.mm58;
            break;
          case 'mm72':
            paperSizes[printerName] = PaperSize.mm72;
            break;
          case 'mm80':
            paperSizes[printerName] = PaperSize.mm80;
            break;
          default:
            paperSizes[printerName] = PaperSize.mm80;
        }
      }
    }

    return paperSizes;
  }

  // Remover tamaño de papel de una impresora
  static Future<void> removePrinterPaperSize(String printerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_printerPaperSizeKey}_$printerName';
    await prefs.remove(key);
  }
}
