import 'package:anfibius_uwu/services/config_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:anfibius_uwu/services/objetivos_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/main.dart';
import 'package:window_manager/window_manager.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
  }

  @override
  Widget build(BuildContext context) {
    final startupService = Provider.of<StartupService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final webSocketService = Provider.of<WebSocketService>(context);
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Conexión",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'Token',

                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          webSocketService.isConnected
                              ? Icons.link_off
                              : Icons.link,
                          color:
                              webSocketService.isConnected
                                  ? Colors.green
                                  : Colors.blue,
                        ),
                        onPressed: () {
                          if (webSocketService.isConnected) {
                            webSocketService.disconnect();
                          } else if (_tokenController.text.isNotEmpty) {
                            // Limpiar el token al conectar
                            final cleanToken =
                                _tokenController.text
                                    .replaceAll("%0D", "")
                                    .trim();
                            _tokenController.text = cleanToken;

                            webSocketService.connect(cleanToken);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Sistema",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Iniciar con Windows'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La aplicación se iniciará automáticamente al arrancar el sistema',
                      ),
                      if (startupService.lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Error: ${startupService.lastError}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (startupService.isInitialized)
                        Switch(
                          value: startupService.isEnabled,
                          onChanged: (value) async {
                            await startupService.toggleStartupSetting();
                          },
                        )
                      else
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () async {
                          await startupService.checkCurrentState();
                        },
                        tooltip: 'Verificar estado actual',
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Apariencia",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<ThemeMode>(
                    initialValue: themeService.themeMode,
                    decoration: const InputDecoration(
                      labelText: 'Tema',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (ThemeMode? newValue) {
                      if (newValue != null) {
                        themeService.setThemeMode(newValue);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Sistema'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Claro'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Oscuro'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Sección del Lector de Huellas
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Lector de Huellas",
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
                      child: ListTile(
                        leading: Icon(
                          Icons.device_hub,
                          color:
                              fingerprintService.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                        title: Text(fingerprintService.selectedDevice!.name),
                        subtitle: Text(
                          'Tipo: ${fingerprintService.selectedDevice!.type}' +
                              (fingerprintService.isScanning
                                  ? ' - Escuchando...'
                                  : ''),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'connect':
                                await fingerprintService.connectToDevice();
                                break;
                              case 'disconnect':
                                await fingerprintService.disconnect();
                                break;
                              case 'test':
                                final success =
                                    await fingerprintService.testConnection();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Prueba de conexión exitosa'
                                            : 'Error en la prueba de conexión',
                                      ),
                                      backgroundColor:
                                          success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                                break;
                              case 'manual_read':
                                await fingerprintService
                                    .triggerManualFingerprintRead();
                                break;
                              case 'forget':
                                await fingerprintService.forgetCurrentDevice();
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => [
                                if (!fingerprintService.isConnected)
                                  const PopupMenuItem(
                                    value: 'connect',
                                    child: ListTile(
                                      leading: Icon(Icons.link),
                                      title: Text('Conectar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (fingerprintService.isConnected)
                                  const PopupMenuItem(
                                    value: 'disconnect',
                                    child: ListTile(
                                      leading: Icon(Icons.link_off),
                                      title: Text('Desconectar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (fingerprintService.isConnected)
                                  const PopupMenuItem(
                                    value: 'test',
                                    child: ListTile(
                                      leading: Icon(Icons.bug_report),
                                      title: Text('Probar conexión'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (fingerprintService.isConnected &&
                                    fingerprintService.selectedDevice?.id !=
                                        'simulated_reader')
                                  const PopupMenuItem(
                                    value: 'manual_read',
                                    child: ListTile(
                                      leading: Icon(Icons.touch_app),
                                      title: Text('Simular lectura'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'forget',
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    title: Text('Olvidar dispositivo'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
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
                          if (context.mounted) {
                            _showDeviceSelectionDialog(
                              context,
                              fingerprintService,
                            );
                          }
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Escanear'),
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
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (fingerprintService.isConnected)
                        ElevatedButton.icon(
                          onPressed: () async {
                            await fingerprintService.disconnect();
                          },
                          icon: const Icon(Icons.link_off),
                          label: const Text('Desconectar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                // Sección de Objetivos
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Objetivos del Sistema",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                // Progreso general
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            objetivosService.getResumenProgreso(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            objetivosService.progreso == 1.0
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color:
                                objetivosService.progreso == 1.0
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: objetivosService.progreso,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          objetivosService.progreso == 1.0
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de objetivos
                ...objetivosService.objetivosList.map((objetivo) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 2.0,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          objetivo.completado
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color:
                              objetivo.completado ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          objetivo.descripcion,
                          style: TextStyle(
                            decoration:
                                objetivo.completado
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                        subtitle: Text(
                          'Última actualización: ${objetivo.ultimaActualizacion.day}/${objetivo.ultimaActualizacion.month}/${objetivo.ultimaActualizacion.year} ${objetivo.ultimaActualizacion.hour}:${objetivo.ultimaActualizacion.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing:
                            objetivo.completado
                                ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'reset') {
                                      await objetivosService.marcarPendiente(
                                        objetivo.id,
                                      );
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(
                                          value: 'reset',
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.undo,
                                              color: Colors.orange,
                                            ),
                                            title: Text(
                                              'Marcar como pendiente',
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                )
                                : null,
                      ),
                    ),
                  );
                }).toList(),
                // Botón para resetear objetivos
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final shouldReset = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Resetear objetivos'),
                              content: const Text(
                                '¿Estás seguro de que quieres marcar todos los objetivos como pendientes?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text('Resetear'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldReset == true) {
                          await objetivosService.resetearObjetivos();
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Resetear objetivos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Aplicación",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final shouldClose = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Cerrar aplicación'),
                              content: const Text(
                                '¿Estás seguro de que quieres cerrar la aplicación?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldClose == true) {
                          // Guardar el token antes de cerrar
                          await ConfigService.saveWebSocketToken(
                            _tokenController.text.trim(),
                          );
                          // Cerrar la aplicación
                          windowManager.destroy();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Cerrar aplicación'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // child: ListView(
          //   children: [
          //     ListTile(
          //       title: const Text('Iniciar con Windows'),
          //       subtitle: const Text(
          //         'La aplicación se iniciará automáticamente al arrancar el sistema',
          //       ),
          //       trailing: Switch(
          //         value: startupService.isEnabled,
          //         onChanged: (value) async {
          //           await startupService.toggleStartupSetting();
          //         },
          //       ),
          //     ),
          //     const Divider(),
          //     ListTile(
          //       title: const Text('Tema'),
          //       subtitle: Text(
          //         themeService.isSystemTheme
          //             ? 'Usar configuración del sistema'
          //             : themeService.isDarkMode
          //             ? 'Modo oscuro'
          //             : 'Modo claro',
          //       ),
          //       trailing: DropdownButton<ThemeMode>(
          //         value: themeService.themeMode,
          //         underline: Container(),
          //         onChanged: (ThemeMode? newValue) {
          //           if (newValue != null) {
          //             themeService.setThemeMode(newValue);
          //           }
          //         },
          //         items: const [
          //           DropdownMenuItem(
          //             value: ThemeMode.system,
          //             child: Text('Sistema'),
          //           ),
          //           DropdownMenuItem(
          //             value: ThemeMode.light,
          //             child: Text('Claro'),
          //           ),
          //           DropdownMenuItem(
          //             value: ThemeMode.dark,
          //             child: Text('Oscuro'),
          //           ),
          //         ],
          //       ),
          //     ),
          //     const Divider(),
          //     // Aquí puedes agregar más opciones de configuración
          //   ],
          // ),
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
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron dispositivos',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Asegúrese de que el lector de huellas esté conectado y try escaneando nuevamente.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              device.id == 'simulated_reader'
                                  ? Icons.developer_mode
                                  : Icons.fingerprint,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                            title: Text(device.name),
                            subtitle: Text('Tipo: ${device.type}'),
                            trailing:
                                isSelected
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : const Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.grey,
                                    ),
                            onTap: () async {
                              await fingerprintService.selectDevice(device);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                          ),
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
