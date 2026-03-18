import 'dart:io';

import 'package:anfibius_uwu/services/config_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:provider/provider.dart';

class PrinterConfig extends StatefulWidget {
  const PrinterConfig({super.key});

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
                    initialValue: printerService.printerType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de impresora',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items: <DropdownMenuItem<PrinterType>>[
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

                // BLE option for Android and Windows
                Visibility(
                  visible:
                      (Platform.isAndroid || Platform.isWindows) &&
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

                // Reconnect option for Android and Windows
                Visibility(
                  visible:
                      (Platform.isAndroid || Platform.isWindows) &&
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

                // Devices list and controls
                const SizedBox(height: 10),
                if (printerService.printerType != PrinterType.network) ...[
                  // List of devices

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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showAddPrinterDialog(
                                    context,
                                    printerService,
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar'),
                              ),
                            ],
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${printer.typePrinter.name.toUpperCase()} - ${isConnected ? "Conectada" : "Desconectada"}',
                              ),
                              Text(
                                'Tamaño: ${printerService.getPaperSizeDescriptionForPrinter(printerName)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón para probar tamaño de papel
                              IconButton(
                                icon: const Icon(
                                  Icons.print,
                                  color: Colors.green,
                                ),
                                onPressed:
                                    isConnected
                                        ? () async {
                                          final printerService =
                                              Provider.of<PrinterService>(
                                                context,
                                                listen: false,
                                              );
                                          final success = await printerService
                                              .printPaperSizeTestForPrinter(
                                                printerName,
                                              );

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Prueba de papel enviada a $printerName'
                                                      : 'Error al imprimir prueba en $printerName',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        : null,
                                tooltip: 'Probar tamaño de papel',
                              ),
                              // Botón para configurar tamaño de papel
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.blue,
                                ),
                                onPressed:
                                    () => _showPaperSizeDialog(printerName),
                                tooltip: 'Configurar tamaño de papel',
                              ),
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

  // Mostrar diálogo para configurar tamaño de papel de una impresora específica
  void _showPaperSizeDialog(String printerName) {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final currentPaperSize = printerService.getPaperSize(printerName);
    PaperSize selectedPaperSize = currentPaperSize;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Configurar tamaño de papel\n$printerName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tamaño actual: ${printerService.getPaperSizeDescriptionForPrinter(printerName)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Seleccionar nuevo tamaño:'),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder:
                      (context, setDialogState) => Column(
                        children: [
                          RadioListTile<PaperSize>(
                            title: const Text('58mm'),
                            subtitle: const Text('Papel térmico pequeño'),
                            value: PaperSize.mm58,
                            groupValue: selectedPaperSize,
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedPaperSize = value;
                                });
                              }
                            },
                          ),
                          RadioListTile<PaperSize>(
                            title: const Text('72mm'),
                            subtitle: const Text('Papel térmico mediano'),
                            value: PaperSize.mm72,
                            groupValue: selectedPaperSize,
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedPaperSize = value;
                                });
                              }
                            },
                          ),
                          RadioListTile<PaperSize>(
                            title: const Text('80mm'),
                            subtitle: const Text('Papel térmico estándar'),
                            value: PaperSize.mm80,
                            groupValue: selectedPaperSize,
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedPaperSize = value;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await printerService.setPaperSizeForPrinter(
                    printerName,
                    selectedPaperSize,
                  );

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tamaño de papel actualizado para $printerName: ${selectedPaperSize == PaperSize.mm58
                            ? "58mm"
                            : selectedPaperSize == PaperSize.mm72
                            ? "72mm"
                            : "80mm"}',
                      ),
                    ),
                  );
                },
                child: const Text('Guardar'),
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
