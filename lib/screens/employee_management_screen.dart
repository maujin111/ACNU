import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/employee_service.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart'; // NUEVO IMPORT
import 'package:anfibius_uwu/screens/fingerprint_registration_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce; // Controlador para el retardo de búsqueda

  List<Employee> _employees = [];
  bool _isLoading = false;
  bool _hasMore = true; // Saber si hay más páginas en BD
  int _offset = 0;
  final int _limit = 20; // Empleados por página

  String? _currentSearchTerm;
  String _currentFilter = 'CExA'; // Por defecto: Sin huella

  @override
  void initState() {
    super.initState();
    _loadEmployees(refresh: true);

    // Escuchar el scroll para cargar más cuando llegamos al final
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

  // Función de carga con Paginación
  Future<void> _loadEmployees({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _employees.clear();
    }

    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final employeeService = EmployeeService(authService);

      final newEmployees = await employeeService.getEmployees(
        searchTerm: _currentSearchTerm,
        searchType: _currentFilter,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _offset += _limit;
        _employees.addAll(newEmployees);
        // Si trajo menos del límite, ya no hay más en la BD
        if (newEmployees.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Función Debounce (Espera 500ms antes de buscar)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Empleados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadEmployees(refresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged:
                        _onSearchChanged, // Buscador en vivo con debounce
                    decoration: const InputDecoration(
                      labelText: 'Buscar Empleados',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currentFilter,
                  items: const [
                    DropdownMenuItem(value: 'CExA', child: Text('Sin Huella')),
                    DropdownMenuItem(value: 'CExNA', child: Text('Con Huella')),
                  ],
                  onChanged: (value) {
                    if (value != null && value != _currentFilter) {
                      setState(() {
                        _currentFilter = value;
                      });
                      _loadEmployees(refresh: true);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _employees.isEmpty && !_isLoading
                    ? const Center(child: Text('No se encontraron empleados.'))
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _employees.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Mostrar indicador de carga al final de la lista
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
                          leading: CircleAvatar(
                            backgroundColor:
                                _currentFilter == 'CExA'
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                            child: Icon(
                              Icons.fingerprint,
                              color:
                                  _currentFilter == 'CExA'
                                      ? Colors.green
                                      : Colors.orange,
                            ),
                          ),
                          title: Text(
                            '${employee.persNombres} ${employee.persApellidos}',
                          ),
                          subtitle: Text('ID: ${employee.persDocumento}'),
                          onTap: () async {
                            // ==========================================
                            // 🛡️ VALIDACIÓN DE HARDWARE ANTES DE ENTRAR
                            // ==========================================
                            final fpService =
                                Provider.of<FingerprintReaderService>(
                                  context,
                                  listen: false,
                                );

                            if (!fpService.isConnected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ Lector desconectado. Vaya a configuración para conectarlo.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return; // Bloquea el acceso
                            }

                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => FingerprintRegistrationScreen(
                                      employeeId: employee.emplId,
                                      employeeName:
                                          '${employee.persNombres} ${employee.persApellidos}',
                                    ),
                              ),
                            );

                            if (result == true) {
                              _loadEmployees(refresh: true);
                            }
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
