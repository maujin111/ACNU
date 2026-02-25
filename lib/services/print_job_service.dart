import 'dart:convert';

import 'package:anfibius_uwu/models/print_request.dart';
import 'package:anfibius_uwu/services/config_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart';

// Función utilitaria para formatear valores numéricos
String formatearValorNumerico(dynamic valor) {
  if (valor == null) return '0.00';

  if (valor is num) {
    return valor.toStringAsFixed(2);
  }

  // Si es una cadena que ya tiene un formato "0.00", mantenerlo
  final valorStr = valor.toString().trim();
  final regexNumero = RegExp(r'^\d+\.\d{2}$');
  if (regexNumero.hasMatch(valorStr)) {
    return valorStr;
  }

  // Intentar convertir a número
  final valorDouble = double.tryParse(valorStr) ?? 0.0;
  return valorDouble.toStringAsFixed(2);
}

// Función para verificar si un valor es mayor que cero
bool esValorMayorQueCero(dynamic valor) {
  if (valor == null) return false;

  if (valor is num) {
    return valor > 0;
  }

  // Si es una cadena, intentar convertirla a número
  final valorStr = valor.toString().trim();
  // Si la cadena está vacía, no es mayor que cero
  if (valorStr.isEmpty) return false;

  final valorDouble = double.tryParse(valorStr) ?? 0.0;
  return valorDouble > 0;
}

class PrintJobService {
  final PrinterService printerService;

  PrintJobService(this.printerService);

  /// Obtiene el tamaño de papel desde la configuración guardada para una impresora específica
  Future<PaperSize> _getPaperSizeForPrinter(String? printerName) async {
    if (printerName != null) {
      print(
        '🔍 Cargando tamaño de papel desde configuración para: $printerName',
      );

      // Primero verificar si está en el PrinterService (configuración en memoria)
      final printerServiceSize = printerService.getPaperSize(printerName);
      print(
        '📊 Tamaño en PrinterService para $printerName: ${_getPaperSizeDisplayName(printerServiceSize)}',
      );

      // Luego verificar configuración guardada
      final savedPaperSize = await ConfigService.loadPrinterPaperSize(
        printerName,
      );

      if (savedPaperSize != null) {
        String paperSizeName = _getPaperSizeDisplayName(savedPaperSize);
        print(
          '✅ Tamaño de papel cargado desde configuración para $printerName: $paperSizeName (${savedPaperSize.toString()})',
        );

        // Verificar si hay diferencia entre PrinterService y configuración guardada
        if (printerServiceSize != savedPaperSize) {
          print(
            '⚠️ Diferencia detectada: PrinterService=${_getPaperSizeDisplayName(printerServiceSize)} vs Guardado=${_getPaperSizeDisplayName(savedPaperSize)}',
          );
          print(
            '✅ Usando configuración guardada como autoridad: ${_getPaperSizeDisplayName(savedPaperSize)}',
          );
        }

        return savedPaperSize;
      } else {
        print(
          '⚠️ No hay tamaño de papel guardado para $printerName, usando configuración del PrinterService: ${_getPaperSizeDisplayName(printerServiceSize)}',
        );

        // Si no hay configuración guardada, usar la del PrinterService y guardarla
        await ConfigService.savePrinterPaperSize(
          printerName,
          printerServiceSize,
        );
        print(
          '💾 Guardado tamaño ${_getPaperSizeDisplayName(printerServiceSize)} para $printerName',
        );

        return printerServiceSize;
      }
    } else {
      print(
        '⚠️ No se especificó impresora, usando tamaño detectado del servicio',
      );
      return printerService.getCurrentPaperSize();
    }
  }

  /// Sincronizar configuración de papel entre PrinterService y configuración guardada
  Future<void> syncPaperSizeConfiguration() async {
    print('🔄 Sincronizando configuración de tamaños de papel...');

    // Obtener todas las impresoras conectadas
    final connectedPrinters = printerService.connectedPrinters.keys.toList();
    if (printerService.selectedPrinter != null) {
      final selectedName = printerService.selectedPrinter!.deviceName;
      if (selectedName != null && !connectedPrinters.contains(selectedName)) {
        connectedPrinters.add(selectedName);
      }
    }

    for (String printerName in connectedPrinters) {
      final serviceSize = printerService.getPaperSize(printerName);
      final savedSize = await ConfigService.loadPrinterPaperSize(printerName);

      if (savedSize == null) {
        // No hay configuración guardada, guardar la del servicio
        await ConfigService.savePrinterPaperSize(printerName, serviceSize);
        print(
          '💾 Guardada configuración inicial para $printerName: ${_getPaperSizeDisplayName(serviceSize)}',
        );
      } else if (serviceSize != savedSize) {
        // Hay diferencia, dar prioridad a la configuración guardada y actualizar el servicio
        printerService.setPaperSizeForPrinter(printerName, savedSize);
        print(
          '🔄 Sincronizado $printerName: ${_getPaperSizeDisplayName(savedSize)}',
        );
      }
    }
  }

  /// Convierte PaperSize enum a nombre legible para mostrar en logs
  String _getPaperSizeDisplayName(PaperSize paperSize) {
    switch (paperSize) {
      case PaperSize.mm58:
        return '58mm';
      case PaperSize.mm72:
        return '72mm';
      case PaperSize.mm80:
        return '80mm';
      default:
        return 'Desconocido';
    }
  }

  /// Procesa un mensaje JSON recibido del WebSocket
  Future<bool> processPrintRequest(String jsonMessage) async {
    try {
      print(jsonMessage);

      // Sincronizar configuración de papel al inicio
      await syncPaperSizeConfiguration();

      // Verificar si hay un JSON válido
      if (jsonMessage.trim().isEmpty) {
        print('❌ Mensaje recibido vacío o inválido');
        return false;
      }

      // Imprimir el mensaje para depuración (limitado a 200 caracteres)
      final previewMessage =
          jsonMessage.length > 200
              ? '${jsonMessage.substring(0, 200)}...'
              : jsonMessage;
      print('📥 Recibido mensaje para impresión: $previewMessage');

      // Parsear el mensaje como una solicitud de impresión estándar
      final request = PrintRequest.fromJson(jsonMessage);

      if (!request.isValid) {
        print('❌ Solicitud de impresión inválida: falta tipo o ID');
        return false;
      }

      // **NUEVO: Verificar si se especifica una impresora específica**
      String? targetPrinterName;

      // Intentar extraer el nombre de la impresora del JSON directamente
      try {
        dynamic parsedData = json.decode(jsonMessage);
        Map<String, dynamic> data;
        if (parsedData is List && parsedData.isNotEmpty) {
          data = parsedData[0];
        } else if (parsedData is Map<String, dynamic>) {
          data = parsedData;
        } else {
          data = {};
        }

        // Buscar en múltiples campos posibles para el nombre de la impresora
        targetPrinterName =
            data['printer']?.toString() ??
            data['impresora']?.toString() ??
            data['printerName']?.toString() ??
            data['printer_name']?.toString() ??
            data['nombreImpresora']?.toString();

        print('📋 Campos disponibles en JSON: ${data.keys.join(", ")}');
        print('🔍 Impresora extraída del JSON: $targetPrinterName');
      } catch (e) {
        print('⚠️ Error al extraer nombre de impresora del JSON: $e');
      }

      // Si no se encontró en el JSON, usar el campo del request
      if (targetPrinterName == null || targetPrinterName.isEmpty) {
        targetPrinterName =
            request.printerName.isNotEmpty ? request.printerName : null;
        print('🔍 Impresora desde request.printerName: $targetPrinterName');
      }

      // Si se especifica una impresora, verificar que esté conectada
      if (targetPrinterName != null && targetPrinterName.isNotEmpty) {
        print('🔎 Buscando impresora: "$targetPrinterName"');
        print(
          '📊 Impresoras conectadas disponibles: ${printerService.connectedPrinterNames.join(", ")}',
        );

        // Verificar si la impresora está conectada (comparación case-insensitive)
        bool isConnected = false;
        String? exactPrinterName;

        for (var printerName in printerService.connectedPrinterNames) {
          if (printerName.toLowerCase() == targetPrinterName.toLowerCase()) {
            isConnected = true;
            exactPrinterName = printerName;
            break;
          }
        }

        if (!isConnected) {
          print(
            '⚠️ Impresora "$targetPrinterName" no encontrada por nombre exacto, buscando parcialmente...',
          );
          // Intentar buscar por nombre parcial
          final foundPrinter = printerService.findPrinterByName(
            targetPrinterName,
          );
          if (foundPrinter == null) {
            print(
              '❌ Impresora "$targetPrinterName" no está conectada o no existe',
            );
            print(
              '💡 Sugerencia: Verifica que el nombre en el mensaje JSON coincida exactamente con el nombre de la impresora configurada',
            );
            return false;
          } else {
            // Usar el nombre exacto encontrado
            exactPrinterName = foundPrinter.deviceName;
            print(
              '✅ Impresora encontrada por coincidencia parcial: $exactPrinterName',
            );
          }
        }

        targetPrinterName = exactPrinterName;
        print('🎯 Imprimiendo en impresora específica: $targetPrinterName');
      } else {
        // Si no se especifica impresora, verificar si hay alguna conectada
        print('⚠️ No se especificó impresora en el mensaje');
        print(
          '📊 Impresoras disponibles: ${printerService.connectedPrinterNames.join(", ")}',
        );

        // Si hay exactamente una impresora conectada, usarla
        if (printerService.connectedPrinterNames.length == 1) {
          targetPrinterName = printerService.connectedPrinterNames.first;
          print(
            '🔄 Auto-seleccionando única impresora conectada: $targetPrinterName',
          );
        } else if (printerService.connectedPrinterNames.length > 1) {
          print(
            '❌ Hay múltiples impresoras conectadas. Debes especificar cuál usar en el mensaje JSON',
          );
          print(
            '� Agrega el campo "printer" o "impresora" con el nombre exacto de la impresora',
          );
          print(
            '📋 Impresoras disponibles: ${printerService.connectedPrinterNames.join(", ")}',
          );
          return false;
        } else {
          print('❌ No hay impresoras conectadas');
          return false;
        }
      }

      // Validar que el tipo de solicitud sea permitido
      final tipoSolicitud = request.tipo.toUpperCase();
      const tiposPermitidos = [
        'COMANDA',
        'PREFACTURA',
        'VENTA',
        'TEST',
        'SORTEO',
      ];

      if (!tiposPermitidos.contains(tipoSolicitud)) {
        print('❌ Tipo de impresión no permitido: $tipoSolicitud');
        print('✅ Tipos permitidos: ${tiposPermitidos.join(', ')}');
        return false;
      }

      // Procesar según el tipo de solicitud
      print('🖨️ Procesando solicitud de tipo válido: $tipoSolicitud');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(targetPrinterName);

      print(
        '📄 Tamaño de papel para $targetPrinterName: ${_getPaperSizeDisplayName(paperSize)}',
      );

      switch (tipoSolicitud) {
        case 'COMANDA':
          print('🍽️ Imprimiendo comanda...');
          return await printComanda(request, targetPrinterName);
        case 'PREFACTURA':
          print('💰 Imprimiendo prefactura...');
          return await printPrefactura(request, targetPrinterName);
        case 'VENTA':
          print('🧾 Imprimiendo factura de venta...');
          // Verificar si es el formato nuevo directo o el formato tradicional
          if (request.data is Map<String, dynamic> &&
              (((request.data.containsKey('detalles') ||
                          request.data.containsKey('detalle')) &&
                      (request.data.containsKey('empleado') ||
                          request.data.containsKey('vendedor'))) ||
                  request.data.containsKey('formaPago') ||
                  request.data.containsKey('numeroFactura'))) {
            print(
              '📝 Detectado formato directo para VENTA, usando formato directo...',
            );
            return await printVentaDirecto(request, targetPrinterName);
          } else {
            return await printVentaDirecto(request, targetPrinterName);
          }
        case 'TEST':
          print('🧪 Imprimiendo prueba...');
          return await printTest(targetPrinterName);
        case 'SORTEO':
          print('🎲 Imprimiendo sorteo...');
          return await printSorteo(request, targetPrinterName);
        default:
          // Este caso no debería ocurrir nunca debido a la validación previa
          print(
            '❌ Error interno: Tipo de impresión no manejado: $tipoSolicitud',
          );
          return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error procesando la solicitud de impresión: $e');
      print('📋 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Imprime una comanda
  Future<bool> printComanda(PrintRequest request, [String? printerName]) async {
    try {
      // Extraer datos de la comanda
      if (request.data == null) {
        print('No hay datos para imprimir la comanda');
        return false;
      }

      final comandaData = ComandaData.fromJson(request.data);

      // Generar los bytes para la impresión
      List<int> bytes = []; // Usar el mismo perfil que en printDirectRequest
      final profile = await CapabilityProfile.load(name: 'ITPP047');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      // Debug detallado para resolución del problema
      print('🔧 === DEBUG DETALLADO COMANDA ===');
      print('🔧 Impresora objetivo: $printerName');
      print('🔧 PaperSize resuelto: $paperSize');
      print('🔧 PaperSize display: ${_getPaperSizeDisplayName(paperSize)}');
      print('🔧 === FIN DEBUG ===');

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel para comanda: ${_getPaperSizeDisplayName(paperSize)}',
      );

      // Establece la tabla de caracteres correcta
      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      // Estilo base con soporte para tildes
      final baseStyle = PosStyles(codeTable: '(Latvian)');

      // Encabezado
      bytes += generator.text(
        'Mesa ${comandaData.hameName ?? ""}   Piso ${comandaData.pisoName ?? ""}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(2);
      bytes += generator.text(
        'Fecha:${comandaData.fecha} - Hora:${comandaData.hora}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      // Cabecera de detalles
      bytes += generator.row([
        PosColumn(
          text: 'Cant',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'UMD',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'Descripcion',
          width: 7,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);

      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      // Detalles
      for (var detalle in comandaData.detalles) {
        bytes += generator.row([
          PosColumn(
            text: detalle.cant.toStringAsFixed(2),
            width: 2,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: detalle.umedNombre ?? "",
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearTexto(
              detalle.descripcion ?? "",
              _getDescriptionWidth(paperSize),
              paperSize: paperSize,
            ),
            width: 7,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);

        if (detalle.observacion != null && detalle.observacion!.isNotEmpty) {
          bytes += generator.emptyLines(1);
          bytes += generator.text(
            '${_getObservationPadding(paperSize)}${detalle.observacion}',
            styles: baseStyle,
          );
          bytes += generator.emptyLines(1);
        }
      }
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'Mesero: ${comandaData.empleado ?? ""}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);

      // Añadir comandos de cajón y sonido si están habilitados
      //bytes += await _getPostPrintCommands(generator);

      // Finalizar
      bytes += generator.cut(mode: PosCutMode.full);

      // Imprimir el número de copias solicitado
      int copias = int.tryParse(request.copias) ?? 1;
      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir comanda en $printerName');
            return false;
          }
        } else {
          await printerService.printBytes(bytes);
        }
      }

      return true;
    } catch (e) {
      print('Error imprimiendo comanda: $e');
      return false;
    }
  }

  Future<bool> printTest([String? printerName]) async {
    try {
      print('🧪 ===== INICIANDO IMPRESIÓN DE PRUEBA =====');
      print('🧪 Impresora especificada: $printerName');
      print(
        '🧪 Impresora seleccionada en servicio: ${printerService.selectedPrinter?.deviceName}',
      );
      print(
        '🧪 Impresoras conectadas: ${printerService.connectedPrinters.keys.join(", ")}',
      );

      // Verificar si hay impresoras disponibles
      if (printerName == null && printerService.selectedPrinter == null) {
        print('❌ No hay impresora seleccionada ni especificada para la prueba');
        return false;
      }

      String targetPrinter =
          printerName ??
          printerService.selectedPrinter?.deviceName ??
          'Desconocida';
      print('🎯 Impresora objetivo: $targetPrinter');

      // Generar los bytes para la impresión
      List<int> bytes = [];
      final profile = await CapabilityProfile.load();

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel para prueba: ${_getPaperSizeDisplayName(paperSize)}',
      );

      bytes += generator.setGlobalCodeTable('CP1252');
      // Encabezado
      bytes += generator.reset();

      bytes += generator.text('=== PRUEBA DE IMPRESION ===');
      bytes += generator.text(
        'Fecha: ${DateTime.now().toString().substring(0, 19)}',
      );
      bytes += generator.text('Impresora: $targetPrinter');
      bytes += generator.text('Tamaño papel: ${paperSize.toString()}');
      bytes += generator.text('');
      bytes += generator.text(
        'Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ',
      );
      bytes += generator.text('Special 1: àÀ èÈ éÉ ûÛ üÜ çÇ ôÔ');
      bytes += generator.text('Special 2: blåbærgrød');
      bytes += generator.text('');
      bytes += generator.text('Bold text', styles: PosStyles(bold: true));
      bytes += generator.text('Reverse text', styles: PosStyles(reverse: true));
      bytes += generator.text(
        'Underlined text',
        styles: PosStyles(underline: true),
        linesAfter: 1,
      );
      bytes += generator.text(
        'Align left',
        styles: PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Align center',
        styles: PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Align right',
        styles: PosStyles(align: PosAlign.right),
        linesAfter: 1,
      );

      bytes += generator.text(
        'Text size 200%',
        styles: PosStyles(height: PosTextSize.size2, width: PosTextSize.size2),
      );

      bytes += generator.text('');
      bytes += generator.text('=== FIN DE PRUEBA ===');

      bytes += generator.feed(2);

      // Añadir comandos de cajón y sonido si están habilitados
      bytes += await _getPostPrintCommands(generator);
      
      bytes += generator.cut();

      print('📋 Bytes generados para impresión: ${bytes.length} bytes');

      int copias = 1;
      bool printSuccess = false;

      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          print('🖨️ Imprimiendo en impresora específica: $printerName');
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir prueba en $printerName');
            return false;
          }
          print('✅ Prueba impresa exitosamente en $printerName');
          printSuccess = true;
        } else {
          print(
            '🖨️ Imprimiendo en impresora seleccionada: ${printerService.selectedPrinter?.deviceName}',
          );
          try {
            await printerService.printBytes(bytes);
            print('✅ Prueba enviada a impresora seleccionada');
            printSuccess = true;
          } catch (e) {
            print('❌ Error al enviar a impresora seleccionada: $e');
            return false;
          }
        }
      }

      print('🧪 ===== FIN IMPRESIÓN DE PRUEBA - Éxito: $printSuccess =====');
      return printSuccess;
    } catch (e, stackTrace) {
      print('❌ Error imprimiendo prueba: $e');
      print('📋 Stack trace: $stackTrace');
      return false;
    }
  }

  // **NUEVO: Método para imprimir hoja de prueba en impresora específica**
  Future<bool> printTestPageToSpecificPrinter(String printerName) async {
    try {
      print('🧪 Imprimiendo hoja de prueba en: $printerName');

      final targetPrinter = printerService.findPrinterByName(printerName);
      if (targetPrinter == null) {
        print('❌ Impresora "$printerName" no encontrada para hoja de prueba');
        return false;
      }

      // Guardar impresora actual
      final originalSelectedPrinter = printerService.selectedPrinter;

      // Seleccionar la impresora para la prueba temporalmente
      bool selected = printerService.selectPrinterByName(printerName);

      if (!selected) {
        print('❌ No se pudo seleccionar impresora para prueba: $printerName');
        return false;
      }

      // Procesar la impresión de prueba
      final result = await printTest(printerName);

      // Restaurar impresora original
      if (originalSelectedPrinter != null) {
        printerService.selectedPrinter = originalSelectedPrinter;
        print('🔄 Impresora restaurada después de prueba');
      }

      return result;
    } catch (e) {
      print('❌ Error imprimiendo hoja de prueba: $e');
      return false;
    }
  }

  /// Imprime un sorteo
  Future<bool> printSorteo(PrintRequest request, [String? printerName]) async {
    try {
      // Extraer datos del sorteo
      if (request.data == null) {
        print('No hay datos para imprimir el sorteo');
        return false;
      }

      final sorteoData = SorteoData.fromJson(request.data);
      // Generar los bytes para la impresión
      List<int> bytes = [];

      // Cargar la imagen del logo
      final ByteData data = await rootBundle.load('assets/icon/OIP.png');
      final Uint8List imageBytes = data.buffer.asUint8List();
      final Image? image = decodeImage(imageBytes);

      // Usar el mismo perfil que en printDirectRequest
      final profile = await CapabilityProfile.load(name: 'ITPP047');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel para sorteo: ${_getPaperSizeDisplayName(paperSize)}',
      );

      // Establece la tabla de caracteres correcta
      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      // Estilo base con soporte para tildes
      final baseStyle = PosStyles(codeTable: '(Latvian)');

      if (image != null) {
        bytes += generator.image(image);
        bytes += generator.emptyLines(1);
      }
      // bytes += generateLine(generator: generator);

      // Encabezado del sorteo
      bytes += generator.text(
        sorteoData.evento,
        styles: baseStyle.copyWith(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.emptyLines(1);
      // Agregar imagen si se pudo decodificar

      // Fecha y hora
      bytes += generator.text(
        'Fecha: ${sorteoData.fecha}       Hora: ${sorteoData.hora}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
      // bytes += generateLine(generator: generator);

      // Número de sorteo
      bytes += generator.text(
        'NÚMERO',
        styles: baseStyle.copyWith(align: PosAlign.center, bold: true),
      );

      bytes += generator.text(
        sorteoData.numeroSorteo,
        styles: baseStyle.copyWith(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size3,
          width: PosTextSize.size3,
        ),
      );
      bytes += generator.emptyLines(1);
      // bytes += generateLine(generator: generator);
      bytes += generator.emptyLines(1); // Datos del participante

      bytes += generator.text(
        'Nombre: ${sorteoData.nombreCompleto}',
        styles: baseStyle.copyWith(align: PosAlign.left),
      );

      bytes += generator.text(
        'Cédula: ${sorteoData.cedula}',
        styles: baseStyle.copyWith(align: PosAlign.left),
      );

      bytes += generator.text(
        'Teléfono: ${sorteoData.telefono}',
        styles: baseStyle.copyWith(align: PosAlign.left),
      );
      bytes += generator.emptyLines(1);
      // bytes += generateLine(generator: generator);
      bytes += generator.emptyLines(1);

      // Mensaje personalizado
      if (sorteoData.mensaje.isNotEmpty) {
        bytes += generator.text(
          sorteoData.mensaje,
          styles: baseStyle.copyWith(align: PosAlign.center),
        );
        bytes += generator.emptyLines(1);
        //bytes += generateLine(generator: generator);
      }

      // Pie de página
      if (sorteoData.pie.isNotEmpty) {
        bytes += generator.text(
          sorteoData.pie,
          styles: baseStyle.copyWith(
            align: PosAlign.center,
            fontType: PosFontType.fontA,
          ),
        );
        bytes += generator.emptyLines(1);
      }

      bytes += generator.emptyLines(2);

      // Añadir comandos de cajón y sonido si están habilitados
      //bytes += await _getPostPrintCommands(generator);

      bytes += generator.cut(mode: PosCutMode.full);

      // Imprimir el número de copias solicitado
      int copias = int.tryParse(request.copias) ?? 1;
      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir sorteo en $printerName');
            return false;
          }
        } else {
          await printerService.printBytes(bytes);
        }
      }

      return true;
    } catch (e) {
      print('Error imprimiendo sorteo: $e');
      return false;
    }
  }

  /// Imprime una prefactura
  Future<bool> printPrefactura(
    PrintRequest request, [
    String? printerName,
  ]) async {
    try {
      // Extraer datos de la prefactura
      if (request.data == null) {
        print('No hay datos para imprimir la prefactura');
        return false;
      }

      print('🔍 Intentando procesar datos de prefactura:');
      // Imprimir el JSON para depuración (truncado si es muy largo)
      final jsonPreview = jsonEncode(request.data).substring(
        0,
        jsonEncode(request.data).length > 300
            ? 300
            : jsonEncode(request.data).length,
      );
      print('📋 JSON recibido: $jsonPreview...');

      // Verificar si el campo numero existe y su tipo antes de procesar
      if (request.data is Map) {
        Map<String, dynamic> data = request.data;
        final numero = data['numero'] ?? data['doin_numero'];
        print('🔢 Campo numero en datos: $numero (${numero.runtimeType})');
      }

      final prefacturaData = PrefacturaData.fromJson(request.data);
      print(
        '✅ PrefacturaData parseada correctamente: Número ${prefacturaData.numero}',
      );

      // Generar los bytes para la impresión
      List<int> bytes = [];

      // Usar el mismo perfil que en printDirectRequest
      final profile = await CapabilityProfile.load(name: 'ITPP047');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel para prefactura: ${_getPaperSizeDisplayName(paperSize)}',
      );

      // Establece la tabla de caracteres correcta
      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      // Estilo base con soporte para tildes
      final baseStyle = PosStyles(codeTable: '(Latvian)');

      // Encabezado
      bytes += generator.text(
        'Pedido # ${prefacturaData.numero}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        'Mesa ${prefacturaData.hameName ?? ""} - Piso ${prefacturaData.pisoName ?? ""}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(2);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      // Detalles
      bytes += generator.row([
        PosColumn(
          text: 'CAN.',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'DETALLE',
          width: 5,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'V.U',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'V.T',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);

      bytes += generateLine(generator: generator, paperSize: paperSize);

      for (var detalle in prefacturaData.detalles) {
        bytes += generator.row([
          PosColumn(
            text: detalle.cantidad.toStringAsFixed(2),
            width: 2,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearTexto(
              detalle.descripcion,
              _getDescriptionWidth(paperSize),
              paperSize: paperSize,
            ),
            width: 5,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: detalle.valorUnitario.toStringAsFixed(2),
            width: 2,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: detalle.total.toStringAsFixed(2),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);

        if (detalle.observacion != null && detalle.observacion!.isNotEmpty) {
          bytes += generator.emptyLines(1);
          bytes += generator.text(
            '${_getObservationPadding(paperSize)}${detalle.observacion}',
            styles: baseStyle,
          );
          bytes += generator.emptyLines(1);
        }
      }

      // Totales
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      for (var total in prefacturaData.totales!) {
        // Los totales vienen como Map<String, dynamic>, no como objetos
        if (total is Map<String, dynamic>) {
          final descripcion = total['descripcion']?.toString() ?? '';
          final valorRaw = total['valor'];
          final valor =
              valorRaw is num
                  ? valorRaw.toDouble()
                  : double.tryParse(valorRaw?.toString() ?? '0') ?? 0.0;
          if (valor == 0.0) continue; // Omitir totales con valor cero
          bytes += generator.row([
            PosColumn(
              text: descripcion,
              width: 9,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
            PosColumn(
              text: valor.toStringAsFixed(2),
              width: 3,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
          ]);
        }
      }

      bytes += generator.emptyLines(2);

      bytes += generator.text(
        'Mesero: ${prefacturaData.empleado ?? ""}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Cliente: ${prefacturaData.cliente ?? ""}',
        styles: baseStyle,
      );

      // Sección para datos del cliente
      bytes += generator.emptyLines(2);
      bytes += generator.text(
        'Datos',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.text(
        'C.I: ___________________________',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Nombre: ________________________',
        styles: baseStyle,
      );
      bytes += generator.text(
        'DIR: ___________________________',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Telefono: ______________________',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Propina: _______________________',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(3);

      // Añadir comandos de cajón y sonido si están habilitados
      //bytes += await _getPostPrintCommands(generator);

      bytes += generator.cut(mode: PosCutMode.full);

      // Imprimir el número de copias solicitado
      int copias = int.tryParse(request.copias) ?? 1;
      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir prefactura en $printerName');
            return false;
          }
        } else {
          await printerService.printBytes(bytes);
        }
      }

      return true;
    } catch (e) {
      print('Error imprimiendo prefactura: $e');
      return false;
    }
  }

  /// Imprime una factura de venta
  Future<bool> printVenta(PrintRequest request, [String? printerName]) async {
    try {
      // Extraer datos de la venta
      if (request.data == null) {
        print('No hay datos para imprimir la factura de venta');
        return false;
      }

      print('🔍 Procesando datos de factura:');
      final ventaData = VentaData.fromJson(request.data);

      // Generar los bytes para la impresión
      List<int> bytes = [];

      // Usar el mismo perfil que en printDirectRequest
      final profile = await CapabilityProfile.load(name: 'ITPP047');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      // Debug detallado para resolución del problema
      print('🔧 === DEBUG DETALLADO VENTA ===');
      print('🔧 Impresora objetivo: $printerName');
      print('🔧 PaperSize resuelto: $paperSize');
      print('🔧 PaperSize display: ${_getPaperSizeDisplayName(paperSize)}');
      print('🔧 === FIN DEBUG ===');

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel para factura: ${_getPaperSizeDisplayName(paperSize)}',
      );

      // Establece la tabla de caracteres correcta
      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      // Estilo base con soporte para tildes
      final baseStyle = PosStyles(codeTable: '(Latvian)');

      // Encabezado
      bytes += generator.text(
        ventaData.sucursal ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        ventaData.empresa ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        ventaData.razonSocial ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        'RUC ${ventaData.ruc ?? ''}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        ventaData.regimen ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.text(ventaData.direccion ?? '', styles: baseStyle);
      bytes += generator.text(
        'Tel: ${ventaData.telefono ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'AMBIENTE ${ventaData.ambiente ?? ''}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.text(
        'Cliente: ${ventaData.cliente ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Ruc/Ci: ${ventaData.rucCliente ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Fecha: ${ventaData.fechaVenta ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Direccion: ${ventaData.direccionCliente ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      bytes += generator.text(
        'FACTURA ${ventaData.numeroFactura ?? ''}',
        styles: baseStyle.copyWith(bold: true),
      );
      bytes += generator.text('Clave de acceso', styles: baseStyle);
      bytes += generator.text(ventaData.claveAcceso ?? '', styles: baseStyle);
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      // Detalles
      bytes += generator.row([
        PosColumn(
          text: 'CANT.',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'DETALLE',
          width: 5,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'PRECIO',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'TOTAL',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      for (var detalle in ventaData.detalles) {
        bytes += generator.row([
          PosColumn(
            text: detalle.cantidad.toStringAsFixed(2),
            width: 2,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearTexto(
              detalle.descripcion,
              _getDescriptionWidth(paperSize),
              paperSize: paperSize,
            ),
            width: 5,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: detalle.valorUnitario.toStringAsFixed(2),
            width: 2,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: detalle.total.toStringAsFixed(2),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);

        final observacion = detalle.getObservacionFormateada();
        if (observacion.isNotEmpty) {
          bytes += generator.emptyLines(1);
          bytes += generator.text(
            '         $observacion                   ',
            styles: baseStyle,
          );
          bytes += generator.emptyLines(1);
        }
      }

      // Totales
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      // Usar rows para todos los totales como en printDirectRequest
      bytes += generator.row([
        PosColumn(
          text: 'SUBTOTAL 0%:',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
        PosColumn(
          text: ventaData.base0.toStringAsFixed(4),
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
      ]);

      if (ventaData.subtotal5 > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 5%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: ventaData.subtotal5.toStringAsFixed(4),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      if (ventaData.subtotal8 > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 8%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: ventaData.subtotal8.toStringAsFixed(4),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      if (ventaData.subtotal12 > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 12%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: ventaData.subtotal12.toStringAsFixed(4),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      if (ventaData.subtotal15 > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 15%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: ventaData.subtotal15.toStringAsFixed(4),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // Agregar servicio 10% si es mayor que 0
      if (esValorMayorQueCero(ventaData.recargo)) {
        bytes += generator.row([
          PosColumn(
            text: 'SERVICIO 10%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(ventaData.recargo),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // TOTAL en negrita
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL:',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: ventaData.total.toStringAsFixed(2),
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);

      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.row([
        PosColumn(
          text: 'Forma de pago',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
        PosColumn(
          text: 'Valor',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
      ]);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      for (var formaPago in ventaData.formasPago) {
        bytes += generator.row([
          PosColumn(
            text: formaPago.detalle ?? '',
            width: 8,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formaPago.importe.toStringAsFixed(2).padLeft(8),
            width: 4,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      bytes += generator.emptyLines(2);
      bytes += generator.text(
        'Vende: ${ventaData.empleadoNombre ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'Para revisar su factura electrónica ingrese a su correo:',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);

      // Añadir comandos de cajón y sonido si están habilitados
      bytes += await _getPostPrintCommands(generator);

      bytes += generator.cut(mode: PosCutMode.full);

      // Imprimir el número de copias solicitado
      int copias = int.tryParse(request.copias) ?? 1;
      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir venta en $printerName');
            return false;
          }
        } else {
          await printerService.printBytes(bytes);
        }
      }
      return true;
    } catch (e, stackTrace) {
      print('❌ Error imprimiendo factura de venta: $e');
      print('📋 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Imprime una factura de venta directa (formato nuevo)
  Future<bool> printVentaDirecto(
    PrintRequest request, [
    String? printerName,
  ]) async {
    try {
      // Extraer datos de la venta en formato directo
      if (request.data == null) {
        print('❌ No hay datos para imprimir la factura de venta directa');
        return false;
      }

      print('🔍 Procesando datos de factura en formato directo:');

      // Convertir los datos al formato esperado
      Map<String, dynamic> dataMap = request.data;
      print('📝 Claves disponibles en los datos: ${dataMap.keys.join(', ')}');

      // Log detallado de los datos para depuración
      try {
        print('📊 Empleado: ${dataMap['empleado']}');
        print('🧾 Factura #: ${dataMap['numeroFactura']}');

        final detallesCount =
            dataMap['detalles'] is List
                ? (dataMap['detalles'] as List).length
                : 0;
        final formaPagoCount =
            dataMap['formaPago'] is List
                ? (dataMap['formaPago'] as List).length
                : 0;

        print(
          '📋 Número de detalles: $detallesCount, Formas de pago: $formaPagoCount',
        );
      } catch (e) {
        print('⚠️ Error al obtener información de depuración: $e');
      }

      // Generar los bytes para la impresión
      List<int> bytes = [];

      // Usar el perfil compatible con caracteres especiales
      final profile = await CapabilityProfile.load(name: 'ITPP047');

      // Obtener el tamaño de papel desde la configuración guardada
      final paperSize = await _getPaperSizeForPrinter(printerName);

      final generator = Generator(paperSize, profile);
      print(
        '📄 Usando tamaño de papel: ${_getPaperSizeDisplayName(paperSize)}',
      );

      // Establece la tabla de caracteres correcta
      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      // Estilo base con soporte para tildes
      final baseStyle = PosStyles(codeTable: '(Latvian)');

      // Cabecera
      bytes += generator.text(
        dataMap['sucursal'] ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        dataMap['empresa'] ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        dataMap['nombre'] ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        'RUC ${dataMap['ruc'] ?? ''}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.text(
        dataMap['regimen'] ?? '',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.text(dataMap['direccion'] ?? '', styles: baseStyle);
      bytes += generator.text(
        'Tel: ${dataMap['telefono'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'AMBIENTE ${dataMap['ambiente'] ?? ''}',
        styles: baseStyle.copyWith(align: PosAlign.center),
      );
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.text(
        'Cliente: ${dataMap['cliente'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Ruc/Ci: ${dataMap['rucCliente'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Fecha: ${dataMap['fecha'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.text(
        'Direccion: ${dataMap['direccionCliente'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      bytes += generator.text(
        'FACTURA ${dataMap['numeroFactura'] ?? ''}',
        styles: baseStyle.copyWith(bold: true),
      );
      bytes += generator.text('Clave de acceso', styles: baseStyle);
      bytes += generator.text(dataMap['claveAcceso'] ?? '', styles: baseStyle);
      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      // Cabecera de detalles
      bytes += generator.row([
        PosColumn(
          text: 'CANT.',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'DETALLE',
          width: 5,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'PRECIO',
          width: 2,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: 'TOTAL',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);
      bytes += generateLine(generator: generator, paperSize: paperSize);

      // Procesar detalles
      if (dataMap['detalles'] != null && dataMap['detalles'] is List) {
        for (var detalleMap in dataMap['detalles']) {
          final descripcion = detalleMap['descripcion'] ?? '';
          final String descripcionFormateada = formatearTexto(
            descripcion,
            _getDescriptionWidth(paperSize),
            paperSize: paperSize,
          );

          // Obtener los valores numéricos como strings y formatearlos correctamente
          double cant = 0.0;
          if (detalleMap['cant'] is num) {
            cant = (detalleMap['cant'] as num).toDouble();
          } else {
            cant =
                double.tryParse(detalleMap['cant']?.toString() ?? '0') ?? 0.0;
          }

          // Formatear valores para mostrar
          final valUnitario = formatearValorNumerico(detalleMap['valUnitario']);
          final valTotal = formatearValorNumerico(detalleMap['valTotal']);

          bytes += generator.row([
            PosColumn(
              text: cant.toStringAsFixed(2),
              width: 2,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
            PosColumn(
              text: descripcionFormateada,
              width: 5,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
            PosColumn(
              text: valUnitario,
              width: 2,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
            PosColumn(
              text: valTotal,
              width: 3,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
          ]);

          // Procesar observación si existe
          final observacion = detalleMap['observacion']?.toString() ?? '';
          if (observacion.isNotEmpty) {
            bytes += generator.emptyLines(1);
            bytes += generator.text(
              '         $observacion                   ',
              styles: baseStyle,
            );
            bytes += generator.emptyLines(1);
          }
        }
      }

      // Totales
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.emptyLines(1);

      // SUBTOTAL 0%
      bytes += generator.row([
        PosColumn(
          text: 'SUBTOTAL 0%:',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
        PosColumn(
          text: formatearValorNumerico(dataMap['subTotal0']),
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
      ]);

      // SUBTOTAL 15%
      if (esValorMayorQueCero(dataMap['subtotal15'])) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 15%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['subtotal15']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // SUBTOTAL 12%
      if (esValorMayorQueCero(dataMap['subtotal12'])) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 12%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['subtotal12']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // SUBTOTAL 5%
      if (esValorMayorQueCero(dataMap['subtotal5'])) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 5%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['subtotal5']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // SUBTOTAL 8%
      if (esValorMayorQueCero(dataMap['subTotal8'])) {
        bytes += generator.row([
          PosColumn(
            text: 'SUBTOTAL 8%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['subTotal8']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // SUBTOTAL SIN IMPUESTOS
      bytes += generator.row([
        PosColumn(
          text: 'SUBTOTAL SIN IMPUESTOS:',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
        PosColumn(
          text: formatearValorNumerico(dataMap['subTotalSI']),
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
      ]);

      // DESCUENTO
      if (esValorMayorQueCero(dataMap['totalDescuento'])) {
        bytes += generator.row([
          PosColumn(
            text: 'TOTAL Descuento:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['totalDescuento']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // ICE
      if (esValorMayorQueCero(dataMap['ice'])) {
        bytes += generator.row([
          PosColumn(
            text: 'ICE:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['ice']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // IVA 5%
      if (esValorMayorQueCero(dataMap['iva05'])) {
        bytes += generator.row([
          PosColumn(
            text: 'IVA 5%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['iva05']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // IVA 8%
      if (esValorMayorQueCero(dataMap['iva8'])) {
        bytes += generator.row([
          PosColumn(
            text: 'IVA 8%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['iva8']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // IVA 12%
      if (esValorMayorQueCero(dataMap['iva12'])) {
        bytes += generator.row([
          PosColumn(
            text: 'IVA 12%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['iva12']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // SERVICIO 10% (antes del IVA 15%)
      if (esValorMayorQueCero(dataMap['vent_recargo'] ?? dataMap['recargo'])) {
        bytes += generator.row([
          PosColumn(
            text: 'SERVICIO 10%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(
              dataMap['vent_recargo'] ?? dataMap['recargo'],
            ),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // IVA 15%
      if (esValorMayorQueCero(dataMap['iva15'])) {
        bytes += generator.row([
          PosColumn(
            text: 'IVA 15%:',
            width: 9,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
          PosColumn(
            text: formatearValorNumerico(dataMap['iva15']),
            width: 3,
            styles: baseStyle.copyWith(align: PosAlign.left),
          ),
        ]);
      }

      // TOTAL
      bytes += generator.row([
        PosColumn(
          text: 'TOTAL:',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
        PosColumn(
          text: formatearValorNumerico(dataMap['total']),
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left, bold: true),
        ),
      ]);

      bytes += generator.emptyLines(1);
      bytes += generateLine(generator: generator, paperSize: paperSize);
      bytes += generator.row([
        PosColumn(
          text: 'Forma de pago',
          width: 9,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
        PosColumn(
          text: 'Valor',
          width: 3,
          styles: baseStyle.copyWith(align: PosAlign.left),
        ),
      ]);
      bytes += generator.emptyLines(1);

      // Formas de pago
      if (dataMap['formaPago'] != null && dataMap['formaPago'] is List) {
        for (var formaPagoMap in dataMap['formaPago']) {
          double importe = 0.0;
          if (formaPagoMap['importe'] is num) {
            importe = formaPagoMap['importe'].toDouble();
          } else {
            importe =
                double.tryParse(formaPagoMap['importe']?.toString() ?? '0') ??
                0.0;
          }

          bytes += generator.row([
            PosColumn(
              text: formaPagoMap['detalle']?.toString() ?? '',
              width: 8,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
            PosColumn(
              text: importe.toStringAsFixed(2).padLeft(8),
              width: 4,
              styles: baseStyle.copyWith(align: PosAlign.left),
            ),
          ]);
        }
      }

      bytes += generator.emptyLines(2);
      bytes += generator.text(
        'Vende: ${dataMap['empleado'] ?? ''}',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);
      bytes += generator.text(
        'Para revisar su factura electrónica ingrese a su correo:',
        styles: baseStyle,
      );
      bytes += generator.emptyLines(1);

      // Añadir comandos de cajón y sonido si están habilitados
      bytes += await _getPostPrintCommands(generator);

      bytes += generator.cut(mode: PosCutMode.full);

      // Imprimir el número de copias solicitado
      int copias = 1; // valor por defecto
      if (dataMap['copias'] is int) {
        copias = dataMap['copias'];
      } else if (dataMap['copias'] is String) {
        copias = int.tryParse(dataMap['copias'].toString()) ?? 1;
      } else {
        copias = int.tryParse(request.copias) ?? 1;
      }

      for (int i = 0; i < copias; i++) {
        if (printerName != null) {
          final success = await printerService.printBytesToPrinter(
            bytes,
            printerName,
          );
          if (!success) {
            print('❌ Error al imprimir venta directa en $printerName');
            return false;
          }
        } else {
          await printerService.printBytes(bytes);
        }
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error imprimiendo factura de venta directa: $e');
      print('📋 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Genera los bytes para los comandos de post-impresión (cajón, sonido)
  Future<List<int>> _getPostPrintCommands(Generator generator) async {
    List<int> commands = [];
    try {
      final bool openDrawer = await ConfigService.loadOpenDrawer();
      final bool doBeep = await ConfigService.loadBeep();

      if (openDrawer) {
        commands += generator.drawer();
        print('✅ Comando para abrir cajón añadido.');
      }

      if (doBeep) {
        commands += generator.beep(n: 2, duration: PosBeepDuration.beep200ms);
        print('✅ Comando de sonido (beep) añadido.');
      }
    } catch (e) {
      print('❌ Error al obtener comandos de post-impresión: $e');
    }
    return commands;
  }

  List<int> generateLine({
    required Generator generator,
    required PaperSize paperSize,
    String char = '-',
    PosAlign align = PosAlign.left,
    PosStyles? style,
  }) {
    // Determinar el largo de línea según tamaño del papel
    int length;
    switch (paperSize) {
      case PaperSize.mm58:
        length = 32;
        break;
      case PaperSize.mm72:
        length = 42;
        break;
      case PaperSize.mm80:
      default:
        length = 48; // Corregido: 80mm debe usar ~48 caracteres
        break;
    }

    final line = List.filled(length, char).join();

    return generator.text(line, styles: style ?? PosStyles(align: align));
  }

  /// Imprime una solicitud en formato directo

  /// Calcula el padding correcto para observaciones según el tamaño del papel
  String _getObservationPadding(PaperSize paperSize) {
    // El padding debe ser proporcional al ancho del papel
    switch (paperSize) {
      case PaperSize.mm58:
        return '     '; // 5 espacios para 58mm (32 chars)
      case PaperSize.mm72:
        return '       '; // 7 espacios para 72mm (42 chars)
      case PaperSize.mm80:
      default:
        return '         '; // 9 espacios para 80mm (48 chars)
    }
  }

  /// Calcula el ancho máximo para descripción según el tamaño del papel
  int _getDescriptionWidth(PaperSize paperSize) {
    switch (paperSize) {
      case PaperSize.mm58:
        return 20; // Menor ancho para 58mm
      case PaperSize.mm72:
        return 28; // Ancho medio para 72mm
      case PaperSize.mm80:
      default:
        return 35; // Ancho mayor para 80mm
    }
  }

  // Método para formatear texto largo, respetando saltos de línea y ajustando al ancho
  String formatearTexto(
    String? texto,
    int anchoMax, {
    PaperSize? paperSize,
    String? customPadding,
  }) {
    if (texto == null || texto.isEmpty) return '';

    // Eliminar caracteres que puedan causar problemas en la impresión
    String textoLimpio = texto.replaceAll('\r', '');

    // Si contiene saltos de línea, los respetamos
    if (textoLimpio.contains('\n')) {
      // Dividir por saltos de línea y formatear cada línea
      List<String> lineas = textoLimpio.split('\n');
      StringBuffer resultado = StringBuffer();

      // Usar padding dinámico o personalizado
      String padding =
          customPadding ?? _getObservationPadding(paperSize ?? PaperSize.mm58);

      for (int i = 0; i < lineas.length; i++) {
        if (i > 0) {
          resultado.write(
            '\n$padding',
          ); // Indentación dinámica para líneas adicionales
        }
        // Limpiar la línea y asegurar que no exceda el ancho máximo
        String lineaLimpia = lineas[i].trim();
        resultado.write(
          lineaLimpia.length <= anchoMax
              ? lineaLimpia.padRight(anchoMax)
              : lineaLimpia.substring(0, anchoMax),
        );
      }

      return resultado.toString();
    }

    // Si no tiene saltos de línea, simplemente ajustamos al ancho
    textoLimpio = textoLimpio.trim();
    return textoLimpio.length <= anchoMax
        ? textoLimpio.padRight(anchoMax)
        : textoLimpio.substring(0, anchoMax);
  }
}
