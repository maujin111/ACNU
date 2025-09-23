import 'package:anfibius_uwu/services/config_service.dart';
import 'package:anfibius_uwu/services/startup_service.dart';
import 'package:anfibius_uwu/services/websocket_service.dart';
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
}
