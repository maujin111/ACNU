import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/config_service.dart';

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
    final ruc = await ConfigService.loadRuc();
    final username = await ConfigService.loadUsername();
    if (ruc != null) {
      _companyIdController.text = ruc;
    }
    if (username != null) {
      _userController.text = username;
    }
  }

  Future<void> _login() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ruc = _companyIdController.text;
    final username = _userController.text;
    final password = _passwordController.text;

    if (ruc.isEmpty || username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please fill in all fields.';
        _isLoading = false;
      });
      return;
    }

    try {
      final success = await authService.login(ruc, username, password);
      if (mounted) {
        if (success) {
          await ConfigService.saveRuc(ruc);
          await ConfigService.saveUsername(username);
          usuario= username;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login successful!')));
        } else {
          setState(() {
            _errorMessage = 'Invalid credentials or server error.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully!')));
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

                if (isLoggedIn) ...[
                  SizedBox(height: 30),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const SizedBox(height: 16),
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

                        Text('Usuario: ${usuario}'),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: TextFormField(
                      controller: _companyIdController,
                      decoration: const InputDecoration(
                        labelText: 'ID de empresa',
                        border: OutlineInputBorder(),
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
                      ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : authService.authToken == null
                          ? ElevatedButton(
                            onPressed: _login,
                            child: const Text('Iniciar Sesión'),
                          )
                          : ElevatedButton(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Color(0xFFFFEBEE),
                            ),
                            child: const Text('Cerrar Sesión'),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
