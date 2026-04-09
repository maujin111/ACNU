import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SessionSettingsForm extends StatefulWidget {
  const SessionSettingsForm({super.key});

  @override
  State<SessionSettingsForm> createState() => SessionSettingsFormState();
}

class SessionSettingsFormState extends State<SessionSettingsForm> {
  final _companyIdController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? usuario;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  @override
  void dispose() {
    _companyIdController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final ruc = prefs.getString('auth_ruc') ?? await ConfigService.loadRuc();
    final username =
        prefs.getString('auth_user') ?? await ConfigService.loadUsername();

    usuario = username;
    if (ruc != null) _companyIdController.text = ruc;
    if (username != null) _userController.text = username;
    if (mounted) setState(() {});
  }

  Future<void> _login() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ruc = _companyIdController.text.trim();
    final username = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (ruc.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor llene todos los campos.';
        _isLoading = false;
      });
      return;
    }

    try {
      final success = await authService.login(ruc, username, password);
      if (mounted) {
        if (success) {
          // Guardamos también en ConfigService por retrocompatibilidad con otras pantallas
          await ConfigService.saveRuc(ruc);
          await ConfigService.saveUsername(username);
          usuario = username;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Inicio de sesión exitoso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(
            () =>
                _errorMessage = 'Credenciales inválidas o error del servidor.',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Ocurrió un error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    if (mounted) {
      _passwordController.clear(); // Limpiamos la clave visualmente
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cierre de sesión exitoso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isLoggedIn = authService.authToken != null;

    return Scaffold(
      body: Center(
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Sesión",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),

                if (authService.isAutoLoggingIn) ...[
                  const SizedBox(height: 50),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Iniciando sesión automáticamente...'),
                      ],
                    ),
                  ),
                ] else if (isLoggedIn) ...[
                  const SizedBox(height: 30),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Estado: Conectado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Usuario: ${usuario ?? _userController.text}'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar Sesión'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: TextFormField(
                      controller: _companyIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID de empresa (RUC)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.login),
                              label: const Text('Iniciar Sesión'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
}
