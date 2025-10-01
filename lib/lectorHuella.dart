import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:anfibius_uwu/services/objetivos_service.dart';

class LectorHuella extends StatefulWidget {
  const LectorHuella({super.key});

  @override
  State<LectorHuella> createState() => _LectorHuellaState();
}

class _LectorHuellaState extends State<LectorHuella> {
  @override
  Widget build(BuildContext context) {
    final fingerprintService = Provider.of<FingerprintReaderService>(context);
    final objetivosService = Provider.of<ObjetivosService>(context);

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
                      if (fingerprintService.isConnected)
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
                      if (fingerprintService.selectedDevice != null &&
                          !fingerprintService.isConnected)
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
                  ),
                ),
                const Divider(),
              ],
            ),
          ),
        ),
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
