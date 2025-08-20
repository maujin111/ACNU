import 'package:anfibius_uwu/services/print_job_service.dart';
import 'package:anfibius_uwu/services/printer_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class Dispositivos extends StatefulWidget {
  const Dispositivos({super.key});

  @override
  State<Dispositivos> createState() => _DispositivosState();
}

class _DispositivosState extends State<Dispositivos> {
  bool _lastConnectionState = false;

  @override
  void initState() {
    super.initState();
    // Configurar el callback para imprimir mensajes automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final webSocketService = Provider.of<WebSocketService>(
        context,
        listen: false,
      );
      final printerService = Provider.of<PrinterService>(
        context,
        listen: false,
      );
      final printJobService = Provider.of<PrintJobService>(
        context,
        listen: false,
      );

      // Guardar el estado inicial de conexión
      _lastConnectionState = printerService.isConnected;

      webSocketService.onNewMessage = (message) {
        if (printerService.currentPrinter != null) {
          printJobService.processPrintRequest(message);
        }
      };
    });
  }

  // Método para verificar cambios en la conexión y mostrar mensajes
  void _checkConnectionChanges() {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final bool currentConnectionState = printerService.isConnected;

    // Si cambió el estado de conexión
    // if (currentConnectionState != _lastConnectionState &&
    //     printerService.currentPrinter != null) {
    //   if (currentConnectionState && !_lastConnectionState) {
    //     // Se conectó la impresora
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       if (context.mounted) {
    //         ScaffoldMessenger.of(context).showSnackBar(
    //           SnackBar(
    //             content: Text(
    //               'Impresora ${currentPrinterName ?? ''} conectada',
    //             ),
    //             backgroundColor: Colors.green,
    //             duration: const Duration(seconds: 2),
    //           ),
    //         );
    //         NotificationsService().showNotification(
    //           id: 1,
    //           title: 'Impresora conectada',
    //           body: 'La impresora ${_lastPrinterName ?? ''} se ha conectado',
    //           payload: 'printer_connected',
    //         );
    //       }
    //     });
    //   } else if (!currentConnectionState && _lastConnectionState) {
    //     // Se desconectó la impresora
    //     WidgetsBinding.instance.addPostFrameCallback((_) {
    //       if (context.mounted) {
    //         ScaffoldMessenger.of(context).showSnackBar(
    //           SnackBar(
    //             content: Text(
    //               'Impresora ${_lastPrinterName ?? ''} desconectada',
    //             ),
    //             backgroundColor: Colors.red,
    //             duration: const Duration(seconds: 2),
    //           ),
    //         );
    //         NotificationsService().showNotification(
    //           id: 1,
    //           title: 'Impresora desconectada',
    //           body: 'La impresora ${_lastPrinterName ?? ''} se ha desconectado',
    //           payload: 'printer_disconnected',
    //         );
    //       }
    //     });
    //   }
    // }

    // Actualizar los valores para la próxima comparación
    _lastConnectionState = currentConnectionState;
  }

  @override
  void didUpdateWidget(Dispositivos oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Verificar si el estado de conexión ha cambiado
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final bool currentConnectionState = printerService.isConnected;

    if (currentConnectionState != _lastConnectionState && context.mounted) {
      _lastConnectionState = currentConnectionState;
      final String? printerName = printerService.currentPrinter?.deviceName;

      // Mostrar mensaje según el nuevo estado
      if (currentConnectionState) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impresora ${printerName ?? ''} conectada'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (printerName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impresora ${printerName} desconectada'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerService = Provider.of<PrinterService>(context);
    final webSocketService = Provider.of<WebSocketService>(context);

    // Verificar cambios en la conexión
    _checkConnectionChanges();

    return Scaffold(
      body: Center(
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Botón de acción principal
                const SizedBox(height: 20),

                // Estado del WebSocket
                Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Estado de conexión",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  webSocketService.isConnected
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color:
                                      webSocketService.isConnected
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  webSocketService.isConnected
                                      ? "Conectado"
                                      : "Desconectado",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            webSocketService.token != null &&
                                    webSocketService.token!.isNotEmpty
                                ? ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Reconectar"),
                                  onPressed: () {
                                    if (webSocketService.token != null) {
                                      webSocketService.connect(
                                        webSocketService.token!,
                                      );
                                    }
                                  },
                                )
                                : Container(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Información de la impresora

                // Nueva sección: Múltiples Impresoras
                if (printerService.connectedPrinters.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Todas las Impresoras",
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "${printerService.connectedPrinters.length} impresora(s) configurada(s)",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 15),
                          ...printerService.connectedPrinters.entries.map((
                            entry,
                          ) {
                            final printerName = entry.key;
                            final printer = entry.value;
                            final isConnected = printerService
                                .isPrinterConnected(printerName);
                            final paperSize = printerService.getPaperSize(
                              printerName,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                      isConnected ? Colors.green : Colors.red,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                                color:
                                    isConnected
                                        ? Colors.green.withOpacity(0.05)
                                        : Colors.red.withOpacity(0.05),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getPrinterIcon(printer.typePrinter),
                                        color:
                                            isConnected
                                                ? Colors.green
                                                : Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          printerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isConnected
                                                  ? Colors.green
                                                  : Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            12.0,
                                          ),
                                        ),
                                        child: Text(
                                          isConnected
                                              ? "Conectada"
                                              : "Desconectada",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Tipo: ${_getPrinterTypeName(printer.typePrinter)}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (printer.address != null)
                                            Text(
                                              "Dir: ${printer.address}",
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          Text(
                                            "Papel: ${_getPaperSizeName(paperSize)}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isConnected
                                                  ? Icons.link_off
                                                  : Icons.link,
                                              size: 18,
                                              color:
                                                  isConnected
                                                      ? Colors.orange
                                                      : Colors.blue,
                                            ),
                                            onPressed: () async {
                                              if (isConnected) {
                                                await printerService
                                                    .disconnectPrinter(
                                                      printerName,
                                                    );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        '$printerName desconectada',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                }
                                              } else {
                                                final success =
                                                    await printerService
                                                        .connectToPrinter(
                                                          printerName,
                                                        );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        success
                                                            ? '$printerName conectada'
                                                            : 'Error al conectar $printerName',
                                                      ),
                                                      backgroundColor:
                                                          success
                                                              ? Colors.green
                                                              : Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            tooltip:
                                                isConnected
                                                    ? 'Desconectar'
                                                    : 'Conectar',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.print,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            onPressed:
                                                isConnected &&
                                                        webSocketService
                                                            .historyItems
                                                            .isNotEmpty
                                                    ? () {
                                                      final printJobService =
                                                          Provider.of<
                                                            PrintJobService
                                                          >(
                                                            context,
                                                            listen: false,
                                                          );
                                                      // Modificar el JSON para incluir el nombre de la impresora
                                                      final lastMessage =
                                                          webSocketService
                                                              .historyItems
                                                              .last
                                                              .rawJson;
                                                      printJobService
                                                          .processPrintRequest(
                                                            lastMessage,
                                                          );
                                                    }
                                                    : null,
                                            tooltip: 'Imprimir último',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                // Lista de impresiones
                Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Historial",
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.print),
                              label: const Text("Imprimir último"),
                              onPressed:
                                  webSocketService.historyItems.isNotEmpty &&
                                          printerService.currentPrinter != null
                                      ? () {
                                        if (webSocketService
                                            .historyItems
                                            .isNotEmpty) {
                                          final printJobService =
                                              Provider.of<PrintJobService>(
                                                context,
                                                listen: false,
                                              );
                                          printJobService.processPrintRequest(
                                            webSocketService
                                                .historyItems
                                                .last
                                                .rawJson,
                                          );
                                        }
                                      }
                                      : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (webSocketService.historyItems.isEmpty)
                          const Text(
                            "No hay historial de impresiones",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          SizedBox(
                            height: 300,
                            child: ListView.builder(
                              itemCount: webSocketService.historyItems.length,
                              itemBuilder: (context, index) {
                                // Mostramos los elementos del historial en orden inverso (más recientes primero)
                                final item =
                                    webSocketService
                                        .historyItems[webSocketService
                                            .historyItems
                                            .length -
                                        1 -
                                        index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: _getIconForDocumentType(item.tipo),
                                    title: Text(
                                      "${item.tipo.toUpperCase()} - ID: ${item.id}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "Fecha: ${item.formattedTimestamp}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.print),
                                      color: Colors.blue,
                                      onPressed:
                                          printerService.currentPrinter != null
                                              ? () {
                                                final printJobService =
                                                    Provider.of<
                                                      PrintJobService
                                                    >(context, listen: false);
                                                printJobService
                                                    .processPrintRequest(
                                                      item.rawJson,
                                                    );
                                              }
                                              : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (webSocketService.historyItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text("Limpiar historial"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirmar'),
                                content: const Text(
                                  '¿Estás seguro de limpiar todo el historial?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      webSocketService.clearHistory();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Limpiar'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPrinterTypeName(dynamic type) {
    switch (type) {
      case 0:
        return 'Bluetooth';
      case 1:
        return 'USB';
      case 2:
        return 'Red';
      default:
        return 'Desconocido';
    }
  }

  String _getPaperSizeName(dynamic paperSize) {
    if (paperSize == null) return 'No disponible';

    try {
      // Convertir a string y procesar el nombre
      String paperSizeStr = paperSize.toString();

      // Detectar el formato específico: Instance of 'PaperSize' o PaperSize.mm80
      if (paperSizeStr.contains('PaperSize.')) {
        // Formato esperado: PaperSize.mm80
        String value = paperSizeStr.split('.').last;
        return _formatPaperSizeName(value);
      } else if (paperSizeStr.contains("Instance of 'PaperSize'")) {
        // Usar una estrategia alternativa
        // Intenta acceder al índice del enum o algún otro identificador disponible
        int? index;
        try {
          index = paperSize.value;
        } catch (_) {}

        if (index != null) {
          switch (index) {
            case 0:
              return '58mm (Ticket)';
            case 1:
              return '80mm (Estándar)';
            case 2:
              return '72mm';
            case 3:
              return 'A4';
            default:
              return 'Tamaño $index';
          }
        }

        // Si no podemos determinarlo, consultamos la configuración del servicio
        // de impresión directamente
        return '80mm (Por defecto)';
      }

      // Si llegamos aquí, usamos el string directamente
      return _formatPaperSizeName(paperSizeStr);
    } catch (e) {
      print('Error procesando tamaño de papel: $e');
      return '80mm (Por defecto)';
    }
  }

  String _formatPaperSizeName(String paperSizeCode) {
    switch (paperSizeCode.toLowerCase()) {
      case 'mm58':
        return '58mm (Ticket)';
      case 'mm80':
        return '80mm (Estándar)';
      case 'mm72':
        return '72mm';
      case 'a4':
        return 'A4';
      default:
        if (paperSizeCode.contains('mm')) {
          return paperSizeCode; // ya tiene formato legible
        }
        return 'Personalizado ($paperSizeCode)';
    }
  }

  // Devuelve un icono adecuado según el tipo de documento
  Widget _getIconForDocumentType(String tipo) {
    // Convertir a minúsculas para hacer la comparación insensible a mayúsculas/minúsculas
    switch (tipo.toLowerCase()) {
      case 'comanda':
        return const Icon(Icons.restaurant, color: Colors.orange);
      case 'prefactura':
        return const Icon(Icons.receipt, color: Colors.blue);
      case 'venta':
        return const Icon(Icons.shopping_cart, color: Colors.green);
      case 'test':
        return const Icon(Icons.bug_report, color: Colors.purple);
      case 'sorteo':
        return const Icon(Icons.casino, color: Colors.red);
      default:
        return const Icon(Icons.description, color: Colors.grey);
    }
  }

  // Método auxiliar para obtener el icono según el tipo de impresora
  IconData _getPrinterIcon(PrinterType type) {
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
