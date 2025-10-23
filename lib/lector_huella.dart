import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';

class LectorHuella extends StatefulWidget {
  const LectorHuella({super.key});

  @override
  State<LectorHuella> createState() => _LectorHuellaState();
}

class _LectorHuellaState extends State<LectorHuella> {
  @override
  Widget build(BuildContext context) {
    final fingerprintService = Provider.of<FingerprintReaderService>(context);

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
                // Sección del Lector de Huellas
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Lector de Huellas Dactilares',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                // Estado de conexión del lector
                ListTile(
                  leading: Icon(
                    fingerprintService.isConnected
                        ? Icons.fingerprint
                        : Icons.fingerprint_outlined,
                    color:
                        fingerprintService.isConnected
                            ? Colors.green
                            : Colors.grey,
                  ),
                  title: Text(
                    fingerprintService.isConnected
                        ? 'Conectado'
                        : 'Desconectado',
                  ),
                  subtitle: Text(
                    fingerprintService.selectedDevice?.name ??
                        'Ningún dispositivo seleccionado',
                  ),
                  trailing:
                      fingerprintService.isConnected
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : Icon(Icons.error_outline, color: Colors.red),
                ),
                // Dispositivo seleccionado
                if (fingerprintService.selectedDevice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.devices,
                                  size: 20,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Dispositivo Actual',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Nombre: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Text(
                                    fingerprintService.selectedDevice!.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Tipo: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        fingerprintService
                                                    .selectedDevice!
                                                    .type ==
                                                'Hikvision SDK'
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    fingerprintService.selectedDevice!.type,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          fingerprintService
                                                      .selectedDevice!
                                                      .type ==
                                                  'Hikvision SDK'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'ID: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(fingerprintService.selectedDevice!.id),
                              ],
                            ),
                            if (fingerprintService.isScanning) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Escuchando huellas dactilares...',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                // Botones de acción
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await fingerprintService.scanDevices();
                            if (mounted) {
                              _showDeviceSelectionDialog(
                                context,
                                fingerprintService,
                              );
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar Dispositivos'),
                        ),
                        if (fingerprintService.isConnected) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              await fingerprintService.disconnect();
                            },
                            icon: const Icon(Icons.link_off),
                            label: const Text('Desconectar'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                        if (fingerprintService.selectedDevice != null &&
                            !fingerprintService.isConnected) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              await fingerprintService.connectToDevice();
                            },
                            icon: const Icon(Icons.link),
                            label: const Text('Conectar'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                        ],
                        if (fingerprintService.isConnected &&
                            !fingerprintService.isScanning) ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              fingerprintService.startListening();
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Iniciar Escucha'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ],
                        if (fingerprintService.isConnected &&
                            fingerprintService.isScanning) ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              fingerprintService.stopListening();
                            },
                            icon: const Icon(Icons.stop),
                            label: const Text('Detener Escucha'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(),
                // Imagen de la lectura de huellas
                if (fingerprintService.lastFingerprintImage != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Última Huella Capturada',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (fingerprintService.lastCaptureTime != null)
                          Text(
                            'Capturada: ${_formatDateTime(fingerprintService.lastCaptureTime!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 200,
                                height: 280,
                                color: Colors.grey[100],
                                child: _buildFingerprintImage(
                                  fingerprintService.lastFingerprintImage!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay imagen de huella disponible',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fingerprintService.isConnected
                                ? 'Coloque el dedo en el lector para capturar'
                                : 'Conecte un dispositivo para empezar',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Formatear fecha y hora para mostrar
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Construir el widget de imagen de huella
  Widget _buildFingerprintImage(Uint8List imageData) {
    try {
      print('🖼️ Procesando imagen de huella: ${imageData.length} bytes');

      // Determinar las dimensiones de la imagen basándose en el tamaño de los datos
      int width, height;

      // Intentar determinar las dimensiones más probables
      if (imageData.length == 92160) {
        // 256x360 (dimensiones estándar esperadas)
        width = 256;
        height = 360;
      } else if (imageData.length == 73728) {
        // 256x288 (dimensiones reales del SDK)
        width = 256;
        height = 288;
      } else if (imageData.length == 65536) {
        // 256x256 (cuadrada)
        width = 256;
        height = 256;
      } else {
        // Intentar calcular dimensiones asumiendo ancho de 256
        width = 256;
        height = imageData.length ~/ width;

        // Verificar si las dimensiones son razonables
        if (height < 100 || height > 500) {
          print(
            '⚠️ Dimensiones calculadas no son razonables: ${width}x$height',
          );
          return _buildErrorImage(
            'Tamaño de imagen no soportado: ${imageData.length} bytes',
          );
        }
      }

      print(
        '✅ Dimensiones de imagen determinadas: ${width}x$height = ${width * height} bytes',
      );

      // Verificar que tenemos exactamente los datos esperados
      final expectedSize = width * height;
      if (imageData.length != expectedSize) {
        print(
          '⚠️ Tamaño de datos no coincide: ${imageData.length} vs $expectedSize',
        );

        // Si tenemos más datos, truncar
        if (imageData.length > expectedSize) {
          final actualImageData = Uint8List.fromList(
            imageData.take(expectedSize).toList(),
          );
          print('📏 Truncando imagen a $expectedSize bytes');
          return CustomPaint(
            size: const Size(200, 280),
            painter: FingerprintPainter(actualImageData, width, height),
          );
        } else {
          // Si tenemos menos datos, es un error
          return _buildErrorImage(
            'Datos insuficientes: ${imageData.length}/$expectedSize bytes',
          );
        }
      }

      print('✅ Imagen de huella válida, creando visualización...');

      // Crear una representación visual de los datos de la huella
      return CustomPaint(
        size: const Size(200, 280),
        painter: FingerprintPainter(imageData, width, height),
      );
    } catch (e) {
      print('❌ Error procesando imagen de huella: $e');
      return _buildErrorImage('Error procesando imagen: $e');
    }
  }

  // Widget de error para cuando no se puede mostrar la imagen
  Widget _buildErrorImage(String errorMessage) {
    return Container(
      width: 200,
      height: 280,
      color: Colors.red[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSelectionDialog(
    BuildContext context,
    FingerprintReaderService fingerprintService,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar Lector de Huellas'),
          content: SizedBox(
            width: double.maxFinite,
            child:
                fingerprintService.availableDevices.isEmpty
                    ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron dispositivos',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Asegúrate de que el lector de huellas esté conectado',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: fingerprintService.availableDevices.length,
                      itemBuilder: (context, index) {
                        final device =
                            fingerprintService.availableDevices[index];
                        final isSelected =
                            fingerprintService.selectedDevice?.id == device.id;

                        return ListTile(
                          leading: Icon(
                            Icons.fingerprint,
                            color: isSelected ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            device.name,
                            style: TextStyle(
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('Tipo: ${device.type}'),
                          trailing:
                              isSelected
                                  ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : null,
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await fingerprintService.selectDevice(device);
                          },
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await fingerprintService.scanDevices();
              },
              child: const Text('Escanear Nuevamente'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter para dibujar la imagen de huella dactilar
class FingerprintPainter extends CustomPainter {
  final Uint8List imageData;
  final int imageWidth;
  final int imageHeight;

  FingerprintPainter(this.imageData, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Calcular el factor de escala para ajustar la imagen al widget
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    // Dibujar píxeles como pequeños rectángulos
    for (
      int y = 0;
      y < imageHeight && y < imageData.length ~/ imageWidth;
      y++
    ) {
      for (
        int x = 0;
        x < imageWidth && (y * imageWidth + x) < imageData.length;
        x++
      ) {
        final pixelIndex = y * imageWidth + x;
        if (pixelIndex < imageData.length) {
          final grayscaleValue = imageData[pixelIndex];

          // Convertir valor de escala de grises a color
          final color = Color.fromARGB(
            255,
            grayscaleValue,
            grayscaleValue,
            grayscaleValue,
          );

          paint.color = color;

          // Dibujar un pequeño rectángulo para cada píxel
          final rect = Rect.fromLTWH(x * scaleX, y * scaleY, scaleX, scaleY);

          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is! FingerprintPainter ||
        oldDelegate.imageData != imageData ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
