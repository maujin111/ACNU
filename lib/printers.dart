import 'dart:io';

import 'package:anfibius_uwu/services/config_service.dart';
import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:provider/provider.dart';

class PrinterConfig extends StatefulWidget {
  const PrinterConfig({Key? key}) : super(key: key);

  @override
  State<PrinterConfig> createState() => _PrinterConfigState();
}

class _PrinterConfigState extends State<PrinterConfig> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  final _customWidthController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _portController.text = '9100';
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    // Cargar token WebSocket
    final token = await ConfigService.loadWebSocketToken();
    if (token != null) {
      // Limpiar el token de caracteres no deseados
      final cleanToken = token.replaceAll("%0D", "").trim();
      _tokenController.text = cleanToken;

      // Si hay diferencia, guardar el token limpio
      if (cleanToken != token) {
        await ConfigService.saveWebSocketToken(cleanToken);
      }
    }

    // Cargar configuración de impresora de red
    final printer = await ConfigService.loadSelectedPrinter();
    if (printer != null && printer.typePrinter == PrinterType.network) {
      _ipController.text = printer.address ?? '';
      _portController.text = printer.port ?? '9100';
    }

    // Inicializar el controlador de ancho personalizado
    final printerService = Provider.of<PrinterService>(context, listen: false);
    _customWidthController.text =
        printerService.customPaperWidth > 0
            ? printerService.customPaperWidth.toString()
            : '80';
  }

  @override
  void dispose() {
    _portController.dispose();
    _ipController.dispose();
    _tokenController.dispose();
    _customWidthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printerService = Provider.of<PrinterService>(context);

    return Scaffold(
      body: Center(
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Impresora",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        // Botón para olvidar la impresora actual
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<PrinterType>(
                    value: printerService.printerType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de impresora',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items: <DropdownMenuItem<PrinterType>>[
                      if (!Platform.isWindows)
                        const DropdownMenuItem(
                          value: PrinterType.bluetooth,
                          child: Text('Bluetooth'),
                        ),
                      const DropdownMenuItem(
                        value: PrinterType.usb,
                        child: Text('USB'),
                      ),
                      const DropdownMenuItem(
                        value: PrinterType.network,
                        child: Text('Red'),
                      ),
                    ],
                    onChanged: (PrinterType? value) {
                      if (value != null) {
                        printerService.setPrinterType(value);
                      }
                    },
                  ),
                ),

                // Printer type selection

                // BLE option for Android
                Visibility(
                  visible:
                      Platform.isAndroid &&
                      printerService.printerType == PrinterType.bluetooth,
                  child: SwitchListTile.adaptive(
                    title: const Text('BLE'),
                    subtitle: const Text('Bluetooth de baja energía'),
                    value: printerService.isBle,
                    onChanged: (bool? value) {
                      if (value != null) {
                        printerService.isBle = value;
                      }
                    },
                  ),
                ),

                // Reconnect option for Android
                Visibility(
                  visible:
                      Platform.isAndroid &&
                      printerService.printerType == PrinterType.bluetooth,
                  child: SwitchListTile.adaptive(
                    title: const Text('Reconectar automáticamente'),
                    subtitle: const Text('Solo funciona con Bluetooth normal'),
                    value: printerService.reconnect,
                    onChanged:
                        printerService.isBle
                            ? null
                            : (bool? value) {
                              if (value != null) {
                                printerService.reconnect = value;
                              }
                            },
                  ),
                ),

                // Network printer settings
                Visibility(
                  visible: printerService.printerType == PrinterType.network,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección IP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),

                Visibility(
                  visible: printerService.printerType == PrinterType.network,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Puerto',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),

                // Network printer connect button
                Visibility(
                  visible: printerService.printerType == PrinterType.network,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_ipController.text.isNotEmpty) {
                          printerService.setNetworkPrinter(
                            _ipController.text,
                            _portController.text,
                          );
                        }
                      },
                      child: const Text('Conectar Impresora de Red'),
                    ),
                  ),
                ),

                // Tamaño de papel manual
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Tamaño de papel",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value:
                            printerService.usingCustomPaperSize
                                ? 'custom'
                                : 'auto',
                        decoration: const InputDecoration(
                          labelText: 'Modo de configuración',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text('Autodetectar (recomendado)'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('Manual'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == 'auto') {
                            printerService.useDetectedPaperSize();
                          } else if (value == 'custom') {
                            // Activar modo manual con el ancho actual
                            final int initialWidth;
                            switch (printerService.detectedPaperSize) {
                              case PaperSize.mm58:
                                initialWidth = 58;
                                break;
                              case PaperSize.mm72:
                                initialWidth = 72;
                                break;
                              default:
                                initialWidth = 80;
                            }
                            printerService.setCustomPaperWidth(initialWidth);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      // Campo para el ancho personalizado
                      Visibility(
                        visible: printerService.usingCustomPaperSize,
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              value:
                                  printerService.customPaperWidth > 0
                                      ? printerService.customPaperWidth
                                      : 80, // Valor por defecto si es 0
                              decoration: const InputDecoration(
                                labelText: 'Ancho del papel',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 58,
                                  child: Text('58mm'),
                                ),
                                DropdownMenuItem(
                                  value: 72,
                                  child: Text('72mm'),
                                ),
                                DropdownMenuItem(
                                  value: 80,
                                  child: Text('80mm'),
                                ),
                              ],
                              onChanged: (int? value) {
                                if (value != null) {
                                  printerService.setCustomPaperWidth(value);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Seleccione el ancho de papel adecuado para su impresora',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Devices list and controls
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Impresoras",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        printerService.scanDevices();
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                ),
                const SizedBox(height: 10),
                if (printerService.printerType != PrinterType.network) ...[
                  // List of devices
                  for (var device in printerService.availableDevices)
                    ListTile(
                      title: Text(device.deviceName ?? 'Desconocido'),
                      subtitle: Text(device.address ?? ''),
                      onTap: () {
                        printerService.selectDevice(device);
                      },
                      leading:
                          printerService.currentPrinter?.address ==
                                  device.address
                              ? Icon(
                                Icons.check_circle,
                                color:
                                    printerService.isConnected
                                        ? Colors.green
                                        : Colors.orange,
                                size: 30,
                              )
                              : Icon(
                                Icons.circle_outlined,
                                color: Colors.grey,
                                size: 30,
                              ),
                      trailing:
                          printerService.currentPrinter?.address ==
                                  device.address
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Estado de conexión
                                  Icon(
                                    printerService.isConnected
                                        ? Icons.link
                                        : Icons.link_off,
                                    color:
                                        printerService.isConnected
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  // Icono de impresora
                                  const Icon(Icons.print, color: Colors.blue),
                                ],
                              )
                              : null,
                    ),
                  const SizedBox(height: 20),

                  // NUEVA SECCIÓN: Gestión de múltiples impresoras
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Impresoras Conectadas",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showAddPrinterDialog(context, printerService);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Lista de impresoras conectadas
                  if (printerService.connectedPrinters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No hay impresoras adicionales conectadas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...printerService.connectedPrinters.entries.map((entry) {
                      final printerName = entry.key;
                      final printer = entry.value;
                      final isConnected = printerService.isPrinterConnected(
                        printerName,
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.print,
                            color: isConnected ? Colors.green : Colors.red,
                          ),
                          title: Text(printerName),
                          subtitle: Text(
                            '${printer.typePrinter.name.toUpperCase()} - ${isConnected ? "Conectada" : "Desconectada"}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isConnected ? Icons.link_off : Icons.link,
                                  color:
                                      isConnected ? Colors.orange : Colors.blue,
                                ),
                                onPressed: () async {
                                  if (isConnected) {
                                    await printerService.disconnectPrinter(
                                      printerName,
                                    );
                                  } else {
                                    await printerService.connectToPrinter(
                                      printerName,
                                    );
                                  }
                                },
                                tooltip:
                                    isConnected ? 'Desconectar' : 'Conectar',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text('Confirmar'),
                                          content: Text(
                                            '¿Eliminar la impresora "$printerName"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                  );

                                  if (confirm == true) {
                                    await printerService.removePrinter(
                                      printerName,
                                    );
                                  }
                                },
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SegmentedButton<String>(
              style: ButtonStyle(
                iconColor: WidgetStatePropertyAll<Color>(Colors.green.shade900),
              ),
              segments: const [
                ButtonSegment<String>(
                  value: 'print',
                  label: Text('Prueba'),
                  icon: Icon(Icons.print),
                ),
                ButtonSegment<String>(
                  value: 'size',
                  label: Text('Tamaño'),
                  icon: Icon(Icons.straighten),
                ),
                ButtonSegment<String>(
                  value: 'detect',
                  label: Text('Papel'),
                  icon: Icon(Icons.search),
                ),
              ],
              selected: const <String>{},
              onSelectionChanged: (Set<String> newSelection) async {
                if (printerService.currentPrinter == null) return;

                if (newSelection.contains('print')) {
                  final printJobService = Provider.of<PrintJobService>(
                    context,
                    listen: false,
                  );
                  String testJson =
                      '{"tipo":"TEST","id":"test","copias":"1","orden":"1","printerName":"${printerService.currentPrinter?.deviceName}","data":{"hame_nombre":"PRUEBA","piso_nombre":"1","detalle":[{"ddin_cantidad":"1","umed_nombre":"UNI","prod_descripcion":"Impresión de prueba","ddin_observacion":""}]}}';
                  await printJobService.processPrintRequest(testJson);
                } else if (newSelection.contains('size')) {
                  await printerService.printPaperSizeTest();
                } else if (newSelection.contains('detect')) {
                  await printerService.detectPaperSize();
                  if (context.mounted) {
                    String paperSizeText;
                    if (printerService.usingCustomPaperSize) {
                      paperSizeText =
                          "Personalizado (${printerService.customPaperWidth}mm)";
                    } else {
                      paperSizeText =
                          printerService.detectedPaperSize == PaperSize.mm58
                              ? "58mm"
                              : printerService.detectedPaperSize ==
                                  PaperSize.mm80
                              ? "80mm"
                              : printerService.detectedPaperSize ==
                                  PaperSize.mm72
                              ? "72mm"
                              : "Desconocido";
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tamaño de papel: $paperSizeText'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              emptySelectionAllowed: true,
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  // Método para mostrar el diálogo de agregar impresora
  void _showAddPrinterDialog(
    BuildContext context,
    PrinterService printerService,
  ) {
    if (printerService.availableDevices.isEmpty) {
      // Si no hay dispositivos disponibles, escanear primero
      printerService.scanDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escaneando dispositivos disponibles...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Esperar un poco y luego mostrar el diálogo
      Future.delayed(const Duration(seconds: 3), () {
        _showDeviceSelectionDialog(context, printerService);
      });
    } else {
      _showDeviceSelectionDialog(context, printerService);
    }
  }

  // Método para mostrar la lista de dispositivos disponibles
  void _showDeviceSelectionDialog(
    BuildContext context,
    PrinterService printerService,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Seleccionar Impresora'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child:
                  printerService.availableDevices.isEmpty
                      ? const Center(
                        child: Text(
                          'No se encontraron dispositivos disponibles',
                        ),
                      )
                      : ListView.builder(
                        itemCount: printerService.availableDevices.length,
                        itemBuilder: (context, index) {
                          final device = printerService.availableDevices[index];
                          final deviceName =
                              device.deviceName ?? 'Dispositivo desconocido';

                          // Verificar si ya está en la lista de conectadas
                          final alreadyConnected = printerService
                              .connectedPrinters
                              .containsKey(deviceName);

                          return ListTile(
                            leading: Icon(
                              _getDeviceIcon(device.typePrinter),
                              color:
                                  alreadyConnected ? Colors.grey : Colors.blue,
                            ),
                            title: Text(
                              deviceName,
                              style: TextStyle(
                                color: alreadyConnected ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text(
                              '${device.typePrinter.name.toUpperCase()}${alreadyConnected ? " (Ya conectada)" : ""}',
                              style: TextStyle(
                                color: alreadyConnected ? Colors.grey : null,
                              ),
                            ),
                            enabled: !alreadyConnected,
                            onTap:
                                alreadyConnected
                                    ? null
                                    : () async {
                                      Navigator.pop(context);

                                      try {
                                        await printerService.addPrinter(device);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Impresora "$deviceName" agregada exitosamente',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error al agregar impresora: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  printerService.scanDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escaneando dispositivos...')),
                  );
                },
                child: const Text('Actualizar'),
              ),
            ],
          ),
    );
  }

  // Método auxiliar para obtener el icono según el tipo de dispositivo
  IconData _getDeviceIcon(PrinterType type) {
    switch (type) {
      case PrinterType.bluetooth:
        return Icons.bluetooth;
      case PrinterType.usb:
        return Icons.usb;
      case PrinterType.network:
        return Icons.wifi;
    }
  }
}
