import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/employee_service.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';
import 'package:anfibius_uwu/screens/employee_management_screen.dart';
import 'package:flutter/foundation.dart'; // Nos permite usar kDebugMode

class Nomina extends StatefulWidget {
  const Nomina({super.key});

  @override
  State<Nomina> createState() => _NominaState();
}

class _NominaState extends State<Nomina> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<Employee> _employees = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  String? _currentSearchTerm;

  @override
  void initState() {
    super.initState();
    _loadEmployees(refresh: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _loadEmployees();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadEmployees({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _employees.clear();
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final employeeService = EmployeeService(authService);

      final newEmployees = await employeeService.getEmployees(
        searchTerm: _currentSearchTerm,
        searchType: 'CExNA',
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _offset += _limit;
        _employees.addAll(newEmployees);
        if (newEmployees.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      print('Error cargando nomina: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentSearchTerm = query.trim();
      });
      _loadEmployees(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el estado del hardware y de la sesión
    final fpService = Provider.of<FingerprintReaderService>(context);
    final authService = Provider.of<AuthService>(context);

    // Variable para saber si hay sesión iniciada
    final bool isLoggedIn = authService.authToken != null;

    return Scaffold(
      floatingActionButton:
          kDebugMode
              ? FloatingActionButton.extended(
                onPressed: () async {
                  // Cambia este número por el ID de un empleado real en tu BD
                  final int empleadoIdDePrueba = 4;

                  print(
                    "🧪 MODO PRUEBA: Simulando huella del empleado ID: $empleadoIdDePrueba",
                  );

                  // Disparamos la misma función que usaría el lector real
                  final response = await fpService.markAttendanceSeguro(
                    empleadoIdDePrueba,
                  );

                  if (response != null) {
                    print("🧪 PRUEBA EXITOSA: $response");
                  }
                },
                backgroundColor: Colors.purple,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text(
                  "Simular Huella",
                  style: TextStyle(color: Colors.white),
                ),
              )
              : null,

      body: Center(
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Nómina y Huellas",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),

              // Tarjeta de estado del Hardware
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        fpService.isConnected
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                    border: Border.all(
                      color:
                          fpService.isConnected
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        fpService.isConnected
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                            fpService.isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fpService.isConnected
                              ? 'Lector conectado y listo para timbrar.'
                              : 'Lector desconectado. Vaya a configuración.',
                          style: TextStyle(
                            color:
                                fpService.isConnected
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Buscador y Botón Administrar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        enabled: isLoggedIn, // Solo habilitado si hay sesión
                        decoration: InputDecoration(
                          labelText: 'Buscar Empleado con Huella',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          filled: !isLoggedIn,
                          fillColor: !isLoggedIn ? Colors.grey.shade200 : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                      // Deshabilitar botón si no hay sesión pasando 'null' al onPressed
                      onPressed:
                          isLoggedIn
                              ? () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const EmployeeManagementScreen(),
                                      ),
                                    )
                                    .then(
                                      (_) => _loadEmployees(refresh: true),
                                    ); // Recargar al volver
                              }
                              : null,
                      child: const Icon(Icons.manage_accounts),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista de Paginación / Mensajes de Estado
              Expanded(
                child:
                    !isLoggedIn
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Debe iniciar sesión para ver la nómina.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _employees.isEmpty && !_isLoading
                        ? const Center(
                          child: Text(
                            'No hay empleados con huellas registradas.',
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          itemCount: _employees.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _employees.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final employee = _employees[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                '${employee.persNombres} ${employee.persApellidos}',
                              ),
                              subtitle: Text('Doc: ${employee.persDocumento}'),
                              trailing: const Icon(
                                Icons.fingerprint,
                                color: Colors.green,
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
