import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import '../services/config_service.dart';

class PrinterService extends ChangeNotifier {
  var defaultPrinterType = PrinterType.bluetooth;
  var _isBle = false;
  var _reconnect = false;
  var printerManager = PrinterManager.instance;
  var devices = <BluetoothPrinter>[];

  // Lista de impresoras virtuales a ignorar
  final List<String> _virtualPrintersToIgnore = [
    'microsoft print to pdf',
    'microsoft xps document writer',
    'onenote',
    'fax',
    'onenote for windows',
    'onenote (desktop)',
    'send to onenote',
    'printer to pdf',
    'pdf creator',
    'adobe pdf',
    'doro pdf writer',
    'print to pdf',
    'foxit pdf',
    'pdf printer',
    'pdf24',
    'nitro pdf',
    'cutepdf',
    'bullzip',
    'xps',
    'document writer',
    'virtual printer',
  ];

  // SOPORTE PARA MÚLTIPLES IMPRESORAS
  // Mapa de impresoras conectadas [nombre -> impresora]
  final Map<String, BluetoothPrinter> _connectedPrinters = {};
  // Mapa de estados de conexión [nombre -> estado]
  final Map<String, bool> _connectionStatus = {};
  // Mapa de tamaños de papel detectados [nombre -> tamaño]
  final Map<String, PaperSize> _paperSizes = {};

  // Variables para retrocompatibilidad (impresora principal)
  BluetoothPrinter? selectedPrinter;
  var _isConnected = false;

  StreamSubscription<PrinterDevice>? _subscription;
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<USBStatus>? _subscriptionUsbStatus;
  BTStatus _currentStatus = BTStatus.none;
  USBStatus _currentUsbStatus = USBStatus.none;
  List<int>? pendingTask;

  // Variables para configuración de impresora de red
  String _ipAddress = '';
  String _port = '9100';

  // Tamaño de papel detectado (para retrocompatibilidad)
  PaperSize _detectedPaperSize = PaperSize.mm80;
  int _customPaperWidth = 80;
  bool _usingCustomPaperSize = false;

  // Timer para verificar automáticamente el estado de las impresoras
  Timer? _connectionCheckTimer;
  // Callback para notificar cambios en el estado de conexión
  Function(bool isConnected, String? printerName)? onConnectionChanged;

  PrinterService() {
    // En Windows, preferir USB por defecto pero permitir Bluetooth también
    if (Platform.isWindows) {
      defaultPrinterType = PrinterType.usb; // USB como predeterminado
    }
    _initListeners();
    _loadSavedPrinter();
    // Iniciar la verificación automática del estado
    _initConnectionChecker();
  }
  bool get isConnected => _isConnected;
  bool get isBle => _isBle;
  bool get reconnect => _reconnect;
  List<BluetoothPrinter> get availableDevices => devices;
  BluetoothPrinter? get currentPrinter => selectedPrinter;
  PrinterType get printerType => defaultPrinterType;
  // Getter para obtener la dirección IP actual
  String get ipAddress => _ipAddress;

  // Getter para obtener el tamaño de papel detectado
  PaperSize get detectedPaperSize => _detectedPaperSize;
  // Getter para el ancho personalizado del papel
  int get customPaperWidth => _customPaperWidth;
  // Getter para saber si se está usando un tamaño personalizado
  bool get usingCustomPaperSize => _usingCustomPaperSize;

  // GETTERS PARA MÚLTIPLES IMPRESORAS
  // Obtener todas las impresoras conectadas
  Map<String, BluetoothPrinter> get connectedPrinters =>
      Map.unmodifiable(_connectedPrinters);
  // Obtener el estado de todas las impresoras
  Map<String, bool> get printerConnectionStatus =>
      Map.unmodifiable(_connectionStatus);
  // Obtener una impresora específica por nombre
  BluetoothPrinter? getPrinterByName(String name) => _connectedPrinters[name];
  // Verificar si una impresora específica está conectada
  bool isPrinterConnected(String name) => _connectionStatus[name] ?? false;
  // Método para debuggear información de impresoras
  void debugPrinterInfo() {
    print('📊 === DEBUG PRINTER INFO ===');
    print('📊 _connectedPrinters: ${_connectedPrinters.keys.toList()}');
    print('📊 _paperSizes Map:');
    _paperSizes.forEach((name, size) {
      String sizeStr = size.toString().split('.').last; // mm58, mm72, mm80
      print('📊   $name: $sizeStr');
    });
    print('📊 _connectionStatus: $_connectionStatus');
    print('📊 === END DEBUG ===');
  }

  // Obtener el tamaño de papel de una impresora específica
  PaperSize getPaperSize(String name) {
    final paperSize = _paperSizes[name] ?? PaperSize.mm80;
    String sizeStr = paperSize.toString().split('.').last; // mm58, mm72, mm80
    print(
      '🔍 getPaperSize para $name: $sizeStr (disponible en _paperSizes: ${_paperSizes.containsKey(name)})',
    );
    return paperSize;
  }

  // Método para corregir configuraciones existentes (útil para debugging)
  Future<void> fixExistingPrinterConfiguration(
    String printerName,
    PaperSize correctSize,
  ) async {
    // Debug temporal para entender qué está pasando
    print('🔧 === INICIO DEBUG DETALLADO ===');
    print('🔧 printerName: $printerName');
    print('🔧 correctSize recibido: $correctSize');
    print('🔧 correctSize == PaperSize.mm58: ${correctSize == PaperSize.mm58}');
    print('🔧 correctSize == PaperSize.mm72: ${correctSize == PaperSize.mm72}');
    print('🔧 correctSize == PaperSize.mm80: ${correctSize == PaperSize.mm80}');
    print('🔧 Valor actual en _paperSizes: ${_paperSizes[printerName]}');
    print('🔧 === FIN DEBUG DETALLADO ===');

    String sizeStr = correctSize.toString().split('.').last; // mm58, mm72, mm80
    print('🔧 Corrigiendo configuración de $printerName a $sizeStr');

    // Actualizar en memoria
    _paperSizes[printerName] = correctSize;

    // Guardar en configuración
    await ConfigService.savePrinterPaperSize(printerName, correctSize);

    String confirmedSizeStr = _paperSizes[printerName].toString().split('.').last;
    print('✅ Configuración corregida para $printerName: $confirmedSizeStr');
    notifyListeners();
  }

  // Configurar el tamaño de papel para una impresora específica
  Future<void> setPaperSizeForPrinter(
    String printerName,
    PaperSize paperSize,
  ) async {
    print('🔧 setPaperSizeForPrinter llamado para $printerName con $paperSize');
    print(
      '🔧 Impresora existe en _connectedPrinters: ${_connectedPrinters.containsKey(printerName)}',
    );
    print('🔧 Valor anterior en _paperSizes: ${_paperSizes[printerName]}');

    if (_connectedPrinters.containsKey(printerName)) {
      _paperSizes[printerName] = paperSize;

      // Guardar en configuración
      await ConfigService.savePrinterPaperSize(printerName, paperSize);

      print('📄 Tamaño de papel configurado para $printerName: $paperSize');
      print('🔧 Valor actualizado en _paperSizes: ${_paperSizes[printerName]}');
      notifyListeners();
    } else {
      print('❌ Impresora $printerName no está en _connectedPrinters');
    }
  }

  // Obtener lista de nombres de impresoras conectadas
  List<String> get connectedPrinterNames => _connectedPrinters.keys.toList();

  set isBle(bool value) {
    _isBle = value;
    notifyListeners();
  }

  set reconnect(bool value) {
    _reconnect = value;
    notifyListeners();
  }

  // Inicializar listeners para el estado de la impresora
  void _initListeners() {
    // Bluetooth
    _subscriptionBtStatus = PrinterManager.instance.stateBluetooth.listen((
      status,
    ) {
      _currentStatus = status;

      // Si es la impresora bluetooth seleccionada, actualizar estado de conexión
      if (selectedPrinter?.typePrinter == PrinterType.bluetooth) {
        if (status == BTStatus.connected && !_isConnected) {
          _isConnected = true;
          notifyListeners();
          print('✅ Estado de Bluetooth actualizado: Conectado');
        } else if (status == BTStatus.none && _isConnected) {
          _isConnected = false;
          notifyListeners();
          print('❌ Estado de Bluetooth actualizado: Desconectado');
        }
      }

      if (status == BTStatus.connected && pendingTask != null) {
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(
              type: PrinterType.bluetooth,
              bytes: pendingTask!,
            );
            pendingTask = null;
          });
        } else if (Platform.isIOS) {
          PrinterManager.instance.send(
            type: PrinterType.bluetooth,
            bytes: pendingTask!,
          );
          pendingTask = null;
        }
      }
    }); // USB
    _subscriptionUsbStatus = PrinterManager.instance.stateUSB.listen((status) {
      _currentUsbStatus =
          status; // Actualiza el estado actual de la conexión USB
      print('Estado USB actual: $_currentUsbStatus'); // Log para depuración

      // Actualizar el estado de conexión basado en el estado USB
      if (selectedPrinter?.typePrinter == PrinterType.usb) {
        bool newConnectionState = (status == USBStatus.connected);
        if (newConnectionState != _isConnected) {
          _isConnected = newConnectionState;
          notifyListeners();
          print(
            newConnectionState
                ? '✅ Estado de USB actualizado: Conectado'
                : '❌ Estado de USB actualizado: Desconectado',
          );
        }
      }

      if (Platform.isAndroid) {
        if (status == USBStatus.connected && pendingTask != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            PrinterManager.instance.send(
              type: PrinterType.usb,
              bytes: pendingTask!,
            );
            pendingTask = null;
          });
        }
      }
    });
  }

  // Inicializar el timer para verificar el estado de conexión
  void _initConnectionChecker() {
    // Cancelar cualquier timer existente
    _connectionCheckTimer?.cancel();

    // Crear un nuevo timer para verificar la conexión cada 5 segundos
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPrinterConnection();
    });
  }

  // Verificar el estado de conexión de la impresora
  Future<void> _checkPrinterConnection() async {
    if (selectedPrinter == null) return;

    try {
      bool isConnectedNow = false;

      // Intentar verificar si la impresora está conectada según su tipo
      switch (selectedPrinter!.typePrinter) {
        case PrinterType.bluetooth:
          // Para Bluetooth, utilizamos el estado actual del stream
          isConnectedNow = (_currentStatus == BTStatus.connected);
          break;

        case PrinterType.usb:
          // Para USB, utilizamos el estado actual del stream USB
          isConnectedNow = (_currentUsbStatus == USBStatus.connected);
          break;

        case PrinterType.network:
          // Para impresoras de red, intentamos una "ping" básica
          try {
            // Verificamos la impresora intentando abrir una conexión
            await printerManager.connect(
              type: PrinterType.network,
              model: TcpPrinterInput(
                ipAddress: selectedPrinter!.address!,
                port: int.tryParse(selectedPrinter!.port ?? '9100') ?? 9100,
                timeout: const Duration(
                  seconds: 2,
                ), // Timeout corto para verificación
              ),
            );
            isConnectedNow = true;
          } catch (e) {
            print('❌ Impresora de red no disponible: ${e.toString()}');
            isConnectedNow = false;
          }
          break;
      }

      // Si el estado cambió, actualizar y notificar
      if (isConnectedNow != _isConnected) {
        _isConnected = isConnectedNow;
        notifyListeners();
        print(
          isConnectedNow
              ? '✅ Impresora conectada: ${selectedPrinter!.deviceName}'
              : '❌ Impresora desconectada: ${selectedPrinter!.deviceName}',
        );
      }
    } catch (e) {
      print('❌ Error al verificar estado de la impresora: $e');
    }
  }

  // Cargar impresora guardada
  Future<void> _loadSavedPrinter() async {
    try {
      // Cargar impresora principal (para retrocompatibilidad)
      final printer = await ConfigService.loadSelectedPrinter();
      if (printer != null) {
        selectedPrinter = printer;
        defaultPrinterType = printer.typePrinter;
        _isBle = printer.isBle ?? false;

        // Si es una impresora de red, actualizar las variables locales
        if (printer.typePrinter == PrinterType.network &&
            printer.address != null) {
          _ipAddress = printer.address!;
          _port = printer.port ?? '9100';
        }

        // Detectar tamaño de papel
        await detectPaperSize();

        // Intentar conectar a la impresora
        await _connectToPrinter();
      }

      // Cargar todas las impresoras conectadas
      final connectedPrinters = await ConfigService.loadAllConnectedPrinters();
      // Cargar todos los tamaños de papel guardados
      final savedPaperSizes = await ConfigService.loadAllPrinterPaperSizes();

      for (final entry in connectedPrinters.entries) {
        final printerName = entry.key;
        final printerData = entry.value;

        print('📂 Cargando impresora guardada: $printerName');

        // Agregar a la lista de conectadas
        _connectedPrinters[printerName] = printerData;

        // Cargar tamaño de papel guardado o detectar automáticamente
        PaperSize paperSize;
        if (savedPaperSizes.containsKey(printerName)) {
          paperSize = savedPaperSizes[printerName]!;
          print('📄 Tamaño de papel cargado para $printerName: $paperSize');
        } else {
          paperSize = await _detectPaperSizeForPrinter(printerData);
          print('📄 Tamaño de papel detectado para $printerName: $paperSize');
        }
        _paperSizes[printerName] = paperSize;

        // Intentar conectar
        final isConnected = await _connectToPrinterByName(printerName);
        _connectionStatus[printerName] = isConnected;

        print(
          '✅ Impresora $printerName ${isConnected ? "conectada" : "cargada"}',
        );
      }

      // Cargar la configuración de tamaño de papel personalizado
      final customWidth = await ConfigService.loadCustomPaperWidth();
      final usingCustom = await ConfigService.loadUsingCustomPaperSize();

      if (customWidth != null && customWidth > 0) {
        _customPaperWidth = customWidth;
      }

      if (usingCustom != null) {
        _usingCustomPaperSize = usingCustom;
      }

      notifyListeners();
    } catch (e) {
      print('Error al cargar las impresoras guardadas: $e');
    }
  }

  // Método para detectar automáticamente el tamaño de papel según tipo de impresora
  Future<PaperSize> detectPaperSize() async {
    if (selectedPrinter == null) {
      print('No hay impresora seleccionada para detectar tamaño de papel');
      return PaperSize.mm80; // Valor por defecto
    }

    try {
      // Según el tipo de impresora, podemos aplicar diferentes estrategias
      switch (selectedPrinter!.typePrinter) {
        case PrinterType.usb:
          // Para impresoras USB, podemos usar el ID del producto para detectar el modelo
          if (selectedPrinter!.vendorId != null) {
            print(
              'Detectando tamaño de papel para impresora USB: ${selectedPrinter!.vendorId}',
            );

            // Ejemplos de vendorId para diferentes tamaños (ajustar según tus impresoras)
            final vendorIdStr = selectedPrinter!.vendorId?.toString();
            if (vendorIdStr == '1155' || vendorIdStr == '7358') {
              _detectedPaperSize = PaperSize.mm58;
              print('Detectado tamaño de papel: 58mm para impresora USB');
            } else if (vendorIdStr == '1659' || vendorIdStr == '8137') {
              _detectedPaperSize = PaperSize.mm80;
              print('Detectado tamaño de papel: 80mm para impresora USB');
            } else {
              _detectedPaperSize = PaperSize.mm80; // Valor por defecto
              print(
                'Usando tamaño de papel por defecto: 80mm para impresora USB',
              );
            }
          }
          break;

        case PrinterType.bluetooth:
          // Para impresoras Bluetooth, podemos usar el nombre del dispositivo
          print(
            'Detectando tamaño de papel para impresora Bluetooth: ${selectedPrinter!.deviceName}',
          );
          final deviceName = selectedPrinter!.deviceName?.toLowerCase() ?? '';

          if (deviceName.contains('58') ||
              deviceName.contains('5802') ||
              deviceName.contains('58mm')) {
            _detectedPaperSize = PaperSize.mm58;
            print(
              'Detectado tamaño de papel: 58mm basado en nombre del dispositivo Bluetooth',
            );
          } else if (deviceName.contains('80') ||
              deviceName.contains('8002') ||
              deviceName.contains('80mm')) {
            _detectedPaperSize = PaperSize.mm80;
            print(
              'Detectado tamaño de papel: 80mm basado en nombre del dispositivo Bluetooth',
            );
          } else {
            _detectedPaperSize = PaperSize.mm80; // Valor por defecto
            print(
              'Usando tamaño de papel por defecto: 80mm para impresora Bluetooth',
            );
          }
          break;

        case PrinterType.network:
          // Para impresoras de red, podríamos usar información almacenada o configuración
          print(
            'Detectando tamaño de papel para impresora de red: ${selectedPrinter!.address}',
          );
          // Aquí podrías añadir lógica específica para tus impresoras de red
          _detectedPaperSize = PaperSize.mm80; // Valor por defecto para red
          print(
            'Usando tamaño de papel por defecto: 80mm para impresora de red',
          );
          break;
      }

      notifyListeners();
      return _detectedPaperSize;
    } catch (e) {
      print('Error al detectar tamaño de papel: $e');
      _detectedPaperSize = PaperSize.mm80; // Valor seguro por defecto
      return _detectedPaperSize;
    }
  } // Escanear dispositivos

  void scanDevices() {
    devices.clear();
    _subscription?.cancel();
    _subscription = printerManager
        .discovery(type: defaultPrinterType, isBle: _isBle)
        .listen((device) {
          // Verificar si es una impresora virtual que debemos ignorar
          final deviceNameLower = device.name.toLowerCase();
          bool isVirtualPrinter = _virtualPrintersToIgnore.any(
            (virtualName) => deviceNameLower.contains(virtualName),
          );

          // Solo agregar si no es una impresora virtual
          if (!isVirtualPrinter) {
            devices.add(
              BluetoothPrinter(
                deviceName: device.name,
                address: device.address,
                isBle: _isBle,
                vendorId: device.vendorId,
                productId: device.productId,
                typePrinter: defaultPrinterType,
              ),
            );
            notifyListeners();
          } else {
            print('Ignorando impresora virtual: ${device.name}');
          }
        });
  }

  // Seleccionar dispositivo
  Future<void> selectDevice(BluetoothPrinter device) async {
    // Para retrocompatibilidad, mantener la impresora principal
    if (selectedPrinter != null) {
      if ((device.address != selectedPrinter!.address) ||
          (device.typePrinter == PrinterType.usb &&
              selectedPrinter!.vendorId != device.vendorId)) {
        await PrinterManager.instance.disconnect(
          type: selectedPrinter!.typePrinter,
        );
      }
    }

    selectedPrinter = device;
    await ConfigService.saveSelectedPrinter(device);

    // Detectar el tamaño de papel al seleccionar una nueva impresora
    await detectPaperSize();

    // Intentar conectar a la impresora
    await _connectToPrinter();

    // Solo agregar a la lista de impresoras conectadas si no está ya presente
    final deviceName = device.deviceName ?? 'Unknown';
    if (!_connectedPrinters.containsKey(deviceName)) {
      await addPrinter(device);
    }

    notifyListeners();
  }

  // MÉTODOS PARA MÚLTIPLES IMPRESORAS
  // Agregar una impresora a la lista de conectadas con configuración manual de tamaño
  Future<void> addPrinterWithManualSize(
    BluetoothPrinter printer,
    PaperSize paperSize,
  ) async {
    final printerName = printer.deviceName ?? 'Unknown';

    print(
      '🖨️ Agregando impresora: $printerName con tamaño manual: $paperSize',
    );

    // Agregar a la lista de conectadas
    _connectedPrinters[printerName] = printer;

    // Configurar el tamaño de papel especificado manualmente
    _paperSizes[printerName] = paperSize;

    // Intentar conectar
    final isConnected = await _connectToPrinterByName(printerName);
    _connectionStatus[printerName] = isConnected;

    // Guardar en configuración
    await ConfigService.saveConnectedPrinter(printerName, printer);
    await ConfigService.savePrinterPaperSize(printerName, paperSize);

    print(
      '✅ Impresora $printerName ${isConnected ? "conectada" : "agregada pero no conectada"} con tamaño $paperSize',
    );
    notifyListeners();
  }

  // Agregar una impresora a la lista de conectadas (método existente para retrocompatibilidad)
  Future<void> addPrinter(BluetoothPrinter printer) async {
    final printerName = printer.deviceName ?? 'Unknown';

    print('🖨️ Agregando impresora: $printerName');

    // Agregar a la lista de conectadas
    _connectedPrinters[printerName] = printer;

    // Verificar si ya tiene un tamaño de papel configurado
    PaperSize paperSize;
    if (_paperSizes.containsKey(printerName)) {
      // Usar el tamaño ya configurado
      paperSize = _paperSizes[printerName]!;
      print(
        '📄 Usando tamaño de papel ya configurado para $printerName: $paperSize',
      );
    } else {
      // Cargar desde configuración guardada o usar tamaño por defecto
      final savedPaperSize = await ConfigService.loadPrinterPaperSize(
        printerName,
      );
      if (savedPaperSize != null) {
        paperSize = savedPaperSize;
        print(
          '📄 Tamaño de papel cargado desde configuración para $printerName: $paperSize',
        );
      } else {
        // En lugar de auto-detectar, usar 80mm por defecto y requerir configuración manual
        paperSize = PaperSize.mm80;
        print(
          '📄 Usando tamaño por defecto para $printerName: $paperSize - requiere configuración manual',
        );
      }
      _paperSizes[printerName] = paperSize;
    }

    // Intentar conectar
    final isConnected = await _connectToPrinterByName(printerName);
    _connectionStatus[printerName] = isConnected;

    // Guardar en configuración
    await ConfigService.saveConnectedPrinter(printerName, printer);

    print(
      '✅ Impresora $printerName ${isConnected ? "conectada" : "agregada pero no conectada"}',
    );
    notifyListeners();
  }

  // Método para corregir configuraciones incorrectas de impresoras existentes
  Future<void> fixPrinterConfiguration(
    String printerName,
    PaperSize correctSize,
  ) async {
    if (_connectedPrinters.containsKey(printerName)) {
      print('🔧 Corrigiendo configuración de $printerName a $correctSize');

      // Actualizar en memoria
      _paperSizes[printerName] = correctSize;

      // Guardar en configuración
      await ConfigService.savePrinterPaperSize(printerName, correctSize);

      print('✅ Configuración de $printerName corregida a $correctSize');
      notifyListeners();
    }
  }

  // Método específico para corregir POS58 Printer a 58mm
  Future<void> fixPOS58Configuration() async {
    const printerName = 'POS58 Printer';
    if (_connectedPrinters.containsKey(printerName)) {
      await fixPrinterConfiguration(printerName, PaperSize.mm58);
    }
  }

  // Remover una impresora de la lista
  Future<void> removePrinter(String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer != null) {
      print('🗑️ Removiendo impresora: $printerName');

      // Desconectar si está conectada
      try {
        await PrinterManager.instance.disconnect(type: printer.typePrinter);
      } catch (e) {
        print('Error al desconectar impresora $printerName: $e');
      }

      // Remover de todas las listas
      _connectedPrinters.remove(printerName);
      _connectionStatus.remove(printerName);
      _paperSizes.remove(printerName);

      // Remover de configuración
      await ConfigService.removeConnectedPrinter(printerName);
      await ConfigService.removePrinterPaperSize(printerName);

      // Si era la impresora principal, limpiar
      if (selectedPrinter?.deviceName == printerName) {
        selectedPrinter = null;
        _isConnected = false;
      }

      print('✅ Impresora $printerName removida');
      notifyListeners();
    }
  }

  // Conectar a una impresora específica por nombre
  Future<bool> connectToPrinter(String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer == null) {
      print('❌ Impresora no encontrada: $printerName');
      return false;
    }

    final isConnected = await _connectToPrinterByName(printerName);
    _connectionStatus[printerName] = isConnected;
    notifyListeners();
    return isConnected;
  }

  // Desconectar una impresora específica
  Future<void> disconnectPrinter(String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer != null) {
      try {
        await PrinterManager.instance.disconnect(type: printer.typePrinter);
        _connectionStatus[printerName] = false;

        // Si era la impresora principal, actualizar estado
        if (selectedPrinter?.deviceName == printerName) {
          _isConnected = false;
        }

        print('✅ Impresora $printerName desconectada');
        notifyListeners();
      } catch (e) {
        print('❌ Error al desconectar impresora $printerName: $e');
      }
    }
  }

  // Detectar tamaño de papel para una impresora específica
  Future<PaperSize> _detectPaperSizeForPrinter(BluetoothPrinter printer) async {
    try {
      PaperSize detectedSize = PaperSize.mm80; // Valor por defecto

      switch (printer.typePrinter) {
        case PrinterType.usb:
          if (printer.vendorId != null) {
            print(
              'Detectando tamaño de papel para impresora USB: ${printer.vendorId}',
            );

            final vendorIdStr = printer.vendorId.toString();
            if (vendorIdStr == '1155' || vendorIdStr == '7358') {
              detectedSize = PaperSize.mm58;
            } else if (vendorIdStr == '1659' || vendorIdStr == '8137') {
              detectedSize = PaperSize.mm80;
            }
          }
          break;

        case PrinterType.bluetooth:
          final deviceName = printer.deviceName?.toLowerCase() ?? '';
          print(
            'Detectando tamaño de papel para impresora Bluetooth: ${printer.deviceName}',
          );

          if (deviceName.contains('58') ||
              deviceName.contains('5802') ||
              deviceName.contains('58mm')) {
            detectedSize = PaperSize.mm58;
          } else if (deviceName.contains('80') ||
              deviceName.contains('8002') ||
              deviceName.contains('80mm')) {
            detectedSize = PaperSize.mm80;
          }
          break;

        case PrinterType.network:
          print(
            'Detectando tamaño de papel para impresora de red: ${printer.address}',
          );
          detectedSize = PaperSize.mm80; // Valor por defecto para red
          break;
      }

      print(
        'Tamaño de papel detectado para ${printer.deviceName}: $detectedSize',
      );
      return detectedSize;
    } catch (e) {
      print('Error al detectar tamaño de papel para ${printer.deviceName}: $e');
      return PaperSize.mm80;
    }
  }

  // Conectar a una impresora específica por nombre (método interno)
  Future<bool> _connectToPrinterByName(String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer == null) {
      print('❌ Impresora no encontrada para conectar: $printerName');
      return false;
    }

    print(
      'Intentando conectar a impresora: $printerName (${printer.typePrinter})',
    );

    try {
      switch (printer.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
            type: printer.typePrinter,
            model: UsbPrinterInput(
              name: printer.deviceName,
              productId: printer.productId,
              vendorId: printer.vendorId,
            ),
          );
          print('✅ Conectado exitosamente a impresora USB: $printerName');
          return true;

        case PrinterType.bluetooth:
          await printerManager.connect(
            type: printer.typePrinter,
            model: BluetoothPrinterInput(
              name: printer.deviceName,
              address: printer.address!,
              isBle: printer.isBle ?? false,
              autoConnect: _reconnect,
            ),
          );
          print(
            '📡 Solicitud de conexión Bluetooth enviada para: $printerName',
          );
          // Para Bluetooth, el estado se actualiza en el listener
          return true;

        case PrinterType.network:
          await printerManager.connect(
            type: printer.typePrinter,
            model: TcpPrinterInput(
              ipAddress: printer.address!,
              port: int.tryParse(printer.port ?? '9100') ?? 9100,
            ),
          );
          print('✅ Conectado exitosamente a impresora de red: $printerName');
          return true;
      }
    } catch (e) {
      print('❌ Error al conectar con la impresora $printerName: $e');
      return false;
    }
  }

  Future<void> _connectToPrinter() async {
    if (selectedPrinter == null) return;

    print(
      'Intentando conectar a impresora: ${selectedPrinter!.deviceName} (${selectedPrinter!.typePrinter})',
    );

    try {
      switch (selectedPrinter!.typePrinter) {
        case PrinterType.usb:
          print('Conectando a impresora USB: ${selectedPrinter!.deviceName}');
          await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: UsbPrinterInput(
              name: selectedPrinter!.deviceName,
              productId: selectedPrinter!.productId,
              vendorId: selectedPrinter!.vendorId,
            ),
          );
          _isConnected = true;
          print('Conectado exitosamente a impresora USB');
          break;

        case PrinterType.bluetooth:
          print(
            'Conectando a impresora Bluetooth: ${selectedPrinter!.deviceName} (${selectedPrinter!.address})',
          );
          await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: BluetoothPrinterInput(
              name: selectedPrinter!.deviceName,
              address: selectedPrinter!.address!,
              isBle: selectedPrinter!.isBle ?? false,
              autoConnect: _reconnect,
            ),
          );
          print('Solicitud de conexión Bluetooth enviada');
          break;

        case PrinterType.network:
          print(
            'Conectando a impresora de red: ${selectedPrinter!.address}:${selectedPrinter!.port ?? "9100"}',
          );
          await printerManager.connect(
            type: selectedPrinter!.typePrinter,
            model: TcpPrinterInput(
              ipAddress: selectedPrinter!.address!,
              port: int.tryParse(selectedPrinter!.port ?? '9100') ?? 9100,
            ),
          );
          _isConnected = true;
          print('Conectado exitosamente a impresora de red');
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Error al conectar con la impresora: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // Método público para reconectarse a la impresora
  Future<void> reconnectPrinter() async {
    if (selectedPrinter == null) return;

    try {
      // Primero desconectamos
      await printerManager.disconnect(type: selectedPrinter!.typePrinter);
      _isConnected = false;
      notifyListeners();

      // Esperamos un momento antes de reconectar
      await Future.delayed(const Duration(milliseconds: 500));

      // Luego reconectamos
      await _connectToPrinter();
    } catch (e) {
      print('Error al reconectar la impresora: $e');
    }
  }

  // Imprimir mensaje de texto simple
  Future<void> printMessage(String message) async {
    if (selectedPrinter == null) return;

    List<int> bytes = [];
    final profile = await CapabilityProfile.load(name: 'XP-N160I');

    // Usar el tamaño de papel actual (detectado o personalizado)
    final paperSize = getCurrentPaperSize();
    final generator = Generator(paperSize, profile);

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(message);

    _printEscPos(bytes, generator);
  }

  // Imprimir bytes directamente
  Future<void> printBytes(List<int> bytes) async {
    if (selectedPrinter == null) return;
    _printRawData(bytes);
  }

  // NUEVO: Imprimir bytes a una impresora específica
  Future<bool> printBytesToPrinter(List<int> bytes, String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer == null) {
      print('❌ Impresora no encontrada: $printerName');
      return false;
    }

    if (!isPrinterConnected(printerName)) {
      print('❌ Impresora no conectada: $printerName');
      return false;
    }

    print('🖨️ Imprimiendo en: $printerName (${printer.typePrinter})');

    try {
      await printerManager.send(type: printer.typePrinter, bytes: bytes);
      print('✅ Impresión enviada exitosamente a: $printerName');
      return true;
    } catch (e) {
      print('❌ Error al imprimir en $printerName: $e');
      return false;
    }
  }

  // NUEVO: Generar bytes de impresión usando el tamaño de papel específico de la impresora
  Future<List<int>> generatePrintBytesForPrinter(
    String printerName,
    String content, {
    PosStyles? styles,
    bool addCut = true,
    bool addFeed = true,
  }) async {
    final printer = _connectedPrinters[printerName];
    if (printer == null) {
      throw Exception('Impresora no encontrada: $printerName');
    }

    // Obtener el tamaño de papel específico de esta impresora
    final paperSize = getPaperSize(printerName);

    print('📄 Generando contenido para $printerName con tamaño: $paperSize');

    List<int> bytes = [];
    final profile = await CapabilityProfile.load(name: 'XP-N160I');
    final generator = Generator(paperSize, profile);

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(content, styles: styles ?? const PosStyles());

    if (addFeed) {
      bytes += generator.feed(2);
    }

    if (addCut) {
      bytes += generator.cut();
    }

    return bytes;
  }

  // NUEVO: Imprimir contenido a una impresora específica usando su tamaño de papel
  Future<bool> printContentToPrinter(
    String printerName,
    String content, {
    PosStyles? styles,
    bool addCut = true,
    bool addFeed = true,
  }) async {
    try {
      final bytes = await generatePrintBytesForPrinter(
        printerName,
        content,
        styles: styles,
        addCut: addCut,
        addFeed: addFeed,
      );

      return await printBytesToPrinter(bytes, printerName);
    } catch (e) {
      print('❌ Error al imprimir contenido en $printerName: $e');
      return false;
    }
  }

  // Método para imprimir datos RAW
  void _printRawData(List<int> bytes) async {
    if (selectedPrinter == null) {
      print('❌ No hay impresora seleccionada para imprimir datos');
      return;
    }

    var bluetoothPrinter = selectedPrinter!;
    print(
      '🖨️ Intentando imprimir en: ${bluetoothPrinter.deviceName} (${bluetoothPrinter.typePrinter})',
    );

    try {
      // Verificar si la impresora ya está conectada
      bool needsConnection = !_isConnected;

      if (needsConnection) {
        print('📡 Conectando a la impresora...');
        switch (bluetoothPrinter.typePrinter) {
          case PrinterType.usb:
            await printerManager.connect(
              type: bluetoothPrinter.typePrinter,
              model: UsbPrinterInput(
                name: bluetoothPrinter.deviceName,
                productId: bluetoothPrinter.productId,
                vendorId: bluetoothPrinter.vendorId,
              ),
            );
            _isConnected = true;
            print(
              '✅ Conectado a impresora USB: ${bluetoothPrinter.deviceName}',
            );
            break;

          case PrinterType.bluetooth:
            await printerManager.connect(
              type: bluetoothPrinter.typePrinter,
              model: BluetoothPrinterInput(
                name: bluetoothPrinter.deviceName,
                address: bluetoothPrinter.address!,
                isBle: bluetoothPrinter.isBle ?? false,
                autoConnect: _reconnect,
              ),
            );
            print(
              '✅ Conectado a impresora Bluetooth: ${bluetoothPrinter.deviceName}',
            );
            break;

          case PrinterType.network:
            print(
              '📡 Conectando a impresora de red: ${bluetoothPrinter.address}:${bluetoothPrinter.port ?? "9100"}',
            );
            await printerManager.connect(
              type: bluetoothPrinter.typePrinter,
              model: TcpPrinterInput(
                ipAddress: bluetoothPrinter.address!,
                port: int.tryParse(bluetoothPrinter.port ?? '9100') ?? 9100,
              ),
            );
            _isConnected = true;
            print(
              '✅ Conectado a impresora de red: ${bluetoothPrinter.address}',
            );
            break;
        }
      } else {
        print('ℹ️ Impresora ya conectada, enviando datos directamente');
      }

      // Enviar los bytes a la impresora
      print('📤 Enviando ${bytes.length} bytes a la impresora...');
      await printerManager.send(
        type: bluetoothPrinter.typePrinter,
        bytes: bytes,
      );
      print('✅ Datos enviados correctamente a la impresora');
    } catch (e, stackTrace) {
      print('❌ Error al imprimir datos RAW: $e');
      print('📋 Stack trace: $stackTrace');

      // Intentar reconectar si hubo un error de conexión
      if (!_isConnected) {
        print('🔄 Intentando reconectar a la impresora...');
        try {
          await reconnectPrinter();
        } catch (reconnectError) {
          print('❌ Error al reconectar: $reconnectError');
        }
      }
    }
  }

  // Método para imprimir
  void _printEscPos(List<int> bytes, Generator generator) async {
    if (selectedPrinter == null) return;
    var bluetoothPrinter = selectedPrinter!;
    switch (bluetoothPrinter.typePrinter) {
      case PrinterType.usb:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: UsbPrinterInput(
            name: bluetoothPrinter.deviceName,
            productId: bluetoothPrinter.productId,
            vendorId: bluetoothPrinter.vendorId,
          ),
        );
        pendingTask = null;
        break;
      case PrinterType.bluetooth:
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: BluetoothPrinterInput(
            name: bluetoothPrinter.deviceName,
            address: bluetoothPrinter.address!,
            isBle: bluetoothPrinter.isBle ?? false,
            autoConnect: _reconnect,
          ),
        );
        pendingTask = null;
        if (Platform.isAndroid) pendingTask = bytes;
        break;
      case PrinterType.network:
        bytes += generator.feed(2);
        bytes += generator.cut();
        await printerManager.connect(
          type: bluetoothPrinter.typePrinter,
          model: TcpPrinterInput(ipAddress: bluetoothPrinter.address!),
        );
        break;
    }
    if (bluetoothPrinter.typePrinter == PrinterType.bluetooth &&
        Platform.isAndroid) {
      if (_currentStatus == BTStatus.connected) {
        printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
        pendingTask = null;
      }
    } else {
      printerManager.send(type: bluetoothPrinter.typePrinter, bytes: bytes);
    }
  }

  // Configurar impresora de red
  void setNetworkPrinter(String ipAddress, String port) {
    _ipAddress = ipAddress;
    _port = port.isEmpty ? '9100' : port;
    print('Configurando impresora de red en $_ipAddress:$_port');

    // Crear un nombre descriptivo para la impresora de red
    final deviceName = 'Red-$ipAddress:$_port';

    var device = BluetoothPrinter(
      deviceName: deviceName,
      address: ipAddress,
      port: _port,
      typePrinter: PrinterType.network,
      state: false,
    );

    print('Registrando impresora de red: $deviceName');
    selectDevice(device);
  }

  // Cambiar tipo de impresora
  void setPrinterType(PrinterType type) {
    defaultPrinterType = type;
    scanDevices();
    notifyListeners();
  }

  // Setter para configurar un ancho personalizado
  void setCustomPaperWidth(int width) {
    if (width > 0) {
      _customPaperWidth = width;
      _usingCustomPaperSize = true;
      // Guardar en preferencias
      ConfigService.saveCustomPaperWidth(width);
      ConfigService.saveUsingCustomPaperSize(true);
      notifyListeners();
    }
  }

  // Método para usar el tamaño de papel detectado (deshabilitar personalizado)
  void useDetectedPaperSize() {
    _usingCustomPaperSize = false;
    // Guardar en preferencias
    ConfigService.saveUsingCustomPaperSize(false);
    notifyListeners();
  }

  // Obtener el tamaño de papel actual a usar (detectado o personalizado)
  PaperSize getCurrentPaperSize() {
    if (_usingCustomPaperSize) {
      // Si el ancho es cercano a los valores estándar, usar esos
      if (_customPaperWidth >= 76 && _customPaperWidth <= 84) {
        return PaperSize.mm80;
      } else if (_customPaperWidth >= 54 && _customPaperWidth <= 62) {
        return PaperSize.mm58;
      } else if (_customPaperWidth >= 68 && _customPaperWidth <= 76) {
        return PaperSize.mm72;
      }

      // Si no se ajusta a un estándar, usar el más cercano
      if (_customPaperWidth < 65) {
        return PaperSize.mm58;
      } else if (_customPaperWidth < 76) {
        return PaperSize.mm72;
      } else {
        return PaperSize.mm80;
      }
    }
    return _detectedPaperSize;
  }

  // Obtener una descripción legible del tamaño de papel actual
  String getPaperSizeDescription() {
    if (_usingCustomPaperSize) {
      return "Personalizado (${_customPaperWidth}mm)";
    } else {
      final paperSize = _detectedPaperSize;
      return paperSize == PaperSize.mm58
          ? "58mm"
          : paperSize == PaperSize.mm80
          ? "80mm"
          : paperSize == PaperSize.mm72
          ? "72mm"
          : "Desconocido";
    }
  }

  // Obtener descripción legible del tamaño de papel de una impresora específica
  String getPaperSizeDescriptionForPrinter(String printerName) {
    final paperSize = getPaperSize(printerName);
    return paperSize == PaperSize.mm58
        ? "58mm"
        : paperSize == PaperSize.mm80
        ? "80mm"
        : paperSize == PaperSize.mm72
        ? "72mm"
        : "Desconocido";
  }

  // Método para probar y verificar el tamaño de papel actual
  Future<bool> printPaperSizeTest() async {
    if (selectedPrinter == null) {
      print('❌ No hay impresora seleccionada para la prueba');
      return false;
    }

    try {
      // Detectar papel (por si acaso no se ha hecho antes)
      await detectPaperSize();

      List<int> bytes = []; // Usar el mismo perfil que en printDirectRequest
      final profile = await CapabilityProfile.load(name: 'ITPP047');
      final paperSize = getCurrentPaperSize();
      final generator = Generator(paperSize, profile);

      // Encabezado
      // Establece la tabla de caracteres correcta      bytes += generator.setGlobalCodeTable('(Latvian)');
      bytes += generator.reset();

      bytes += generator.text(
        'PRUEBA DE TAMAÑO DE PAPEL',
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        '------------------------',
        styles: PosStyles(align: PosAlign.center),
      );

      bytes += generator.text('ññ', styles: PosStyles(align: PosAlign.center));

      // Mostrar tamaño de papel actual (detectado o personalizado)
      String paperSizeText;
      if (_usingCustomPaperSize) {
        paperSizeText = "Personalizado (${_customPaperWidth}mm)";
      } else {
        paperSizeText =
            paperSize == PaperSize.mm58
                ? "58mm"
                : paperSize == PaperSize.mm80
                ? "80mm"
                : paperSize == PaperSize.mm72
                ? "72mm"
                : "Desconocido";
      }

      bytes += generator.text(
        'Tamaño actual: $paperSizeText',
        styles: PosStyles(align: PosAlign.center, bold: true),
      );

      if (_usingCustomPaperSize) {
        bytes += generator.text(
          'Tamaño base: ${_detectedPaperSize == PaperSize.mm58
              ? "58mm"
              : _detectedPaperSize == PaperSize.mm80
              ? "80mm"
              : _detectedPaperSize == PaperSize.mm72
              ? "72mm"
              : "Desconocido"}',
          styles: PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(1);

      // Información de la impresora
      bytes += generator.text(
        'Impresora: ${selectedPrinter!.deviceName ?? "Desconocida"}',
        styles: PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Tipo: ${selectedPrinter!.typePrinter.toString().split('.').last}',
        styles: PosStyles(align: PosAlign.left),
      );

      if (selectedPrinter!.typePrinter == PrinterType.bluetooth) {
        bytes += generator.text(
          'Dirección: ${selectedPrinter!.address ?? "Desconocida"}',
          styles: PosStyles(align: PosAlign.left),
        );
        bytes += generator.text(
          'BLE: ${selectedPrinter!.isBle ?? false ? "Sí" : "No"}',
          styles: PosStyles(align: PosAlign.left),
        );
      } else if (selectedPrinter!.typePrinter == PrinterType.usb) {
        bytes += generator.text(
          'Vendor ID: ${selectedPrinter!.vendorId ?? "Desconocido"}',
          styles: PosStyles(align: PosAlign.left),
        );
        bytes += generator.text(
          'Product ID: ${selectedPrinter!.productId ?? "Desconocido"}',
          styles: PosStyles(align: PosAlign.left),
        );
      } else if (selectedPrinter!.typePrinter == PrinterType.network) {
        bytes += generator.text(
          'IP: ${selectedPrinter!.address ?? "Desconocida"}',
          styles: PosStyles(align: PosAlign.left),
        );
        bytes += generator.text(
          'Puerto: ${selectedPrinter!.port ?? "9100"}',
          styles: PosStyles(align: PosAlign.left),
        );
      }
      bytes += generator.feed(1);

      // Indicadores de ancho según el tamaño actual
      if (paperSize == PaperSize.mm58) {
        bytes += generator.text(
          '1234567890123456789012345678901234',
          styles: PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '         58mm - 34 caracteres        ',
          styles: PosStyles(align: PosAlign.center),
        );
      } else if (paperSize == PaperSize.mm72) {
        bytes += generator.text(
          '123456789012345678901234567890123456789012',
          styles: PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '         72mm - 42 caracteres        ',
          styles: PosStyles(align: PosAlign.center),
        );
      } else {
        bytes += generator.text(
          '123456789012345678901234567890123456789012345678',
          styles: PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '            80mm - 48 caracteres            ',
          styles: PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Imprimir
      await printBytes(bytes);

      print('✅ Prueba de tamaño de papel enviada a la impresora');
      return true;
    } catch (e) {
      print('❌ Error al imprimir prueba de tamaño de papel: $e');
      return false;
    }
  }

  // NUEVO: Método para probar el tamaño de papel de una impresora específica
  Future<bool> printPaperSizeTestForPrinter(String printerName) async {
    final printer = _connectedPrinters[printerName];
    if (printer == null) {
      print('❌ Impresora no encontrada: $printerName');
      return false;
    }

    if (!isPrinterConnected(printerName)) {
      print('❌ Impresora no conectada: $printerName');
      return false;
    }

    try {
      // Obtener el tamaño de papel específico de esta impresora
      final paperSize = getPaperSize(printerName);

      print(
        '📄 Generando prueba de tamaño de papel para $printerName: $paperSize',
      );

      List<int> bytes = [];
      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final generator = Generator(paperSize, profile);

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.reset();

      bytes += generator.text(
        'PRUEBA DE TAMAÑO DE PAPEL',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        '========================',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Información de la impresora
      bytes += generator.text(
        'Impresora: $printerName',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Tipo: ${printer.typePrinter.toString().split('.').last.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Mostrar tamaño de papel configurado
      final paperSizeText =
          paperSize == PaperSize.mm58
              ? "58mm"
              : paperSize == PaperSize.mm80
              ? "80mm"
              : paperSize == PaperSize.mm72
              ? "72mm"
              : "Desconocido";

      bytes += generator.text(
        'Tamaño configurado: $paperSizeText',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.feed(1);

      // Indicadores de ancho según el tamaño configurado
      if (paperSize == PaperSize.mm58) {
        bytes += generator.text(
          '1234567890123456789012345678901234',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '    58mm - 34 caracteres aprox.    ',
          styles: const PosStyles(align: PosAlign.center),
        );
      } else if (paperSize == PaperSize.mm72) {
        bytes += generator.text(
          '123456789012345678901234567890123456789012',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '    72mm - 42 caracteres aprox.    ',
          styles: const PosStyles(align: PosAlign.center),
        );
      } else {
        bytes += generator.text(
          '123456789012345678901234567890123456789012345678',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          '     80mm - 48 caracteres aprox.     ',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      // Imprimir usando el método específico para esa impresora
      final success = await printBytesToPrinter(bytes, printerName);

      if (success) {
        print('✅ Prueba de tamaño de papel enviada a $printerName');
      }

      return success;
    } catch (e) {
      print(
        '❌ Error al imprimir prueba de tamaño de papel para $printerName: $e',
      );
      return false;
    }
  }

  // Método para liberar recursos cuando se destruye la instancia
  @override
  void dispose() {
    // Cancelar suscripciones
    _subscription?.cancel();
    _subscriptionBtStatus?.cancel();
    _subscriptionUsbStatus?.cancel();

    // Cancelar el timer de verificación
    _connectionCheckTimer?.cancel();

    // Desconectar de la impresora si está conectada
    if (_isConnected && selectedPrinter != null) {
      printerManager.disconnect(type: selectedPrinter!.typePrinter);
    }

    super.dispose();
  }

  // Olvidar la impresora seleccionada actualmente
  Future<void> forgetCurrentPrinter() async {
    if (selectedPrinter != null) {
      try {
        // Desconectar de la impresora actual si está conectada
        if (_isConnected) {
          await PrinterManager.instance.disconnect(
            type: selectedPrinter!.typePrinter,
          );
          _isConnected = false;
        }

        // Eliminar de la configuración guardada
        await ConfigService.saveSelectedPrinter(null);

        // Limpiar la referencia local
        selectedPrinter = null;

        print('Impresora olvidada correctamente');
        notifyListeners();
      } catch (e) {
        print('Error al olvidar la impresora: $e');
      }
    }
  }
}
