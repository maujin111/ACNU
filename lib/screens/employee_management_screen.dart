import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/employee_service.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/screens/fingerprint_registration_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late Future<List<Employee>> _employeesFuture;
  final TextEditingController _searchController = TextEditingController();
  String? _currentSearchTerm;
  String _currentFilter = 'CExNA'; // Por defecto: Sin huella registrada

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  void _loadEmployees({String? searchTerm}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeService = EmployeeService(authService);
    setState(() {
      _employeesFuture = employeeService.getEmployees(
        searchTerm: searchTerm,
        searchType: _currentFilter,
      );
    });
  }

  void _onSearch() {
    setState(() {
      _currentSearchTerm = _searchController.text;
    });
    _loadEmployees(searchTerm: _currentSearchTerm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Empleados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadEmployees(searchTerm: _currentSearchTerm),
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
                    decoration: InputDecoration(
                      labelText: 'Buscar Empleados',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _onSearch,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currentFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'CExNA',
                      child: Text('Sin Huella'),
                    ),
                    DropdownMenuItem(
                      value: 'CExA', // Suponiendo que este es el código para 'Con Asignación'
                      child: Text('Con Huella'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currentFilter = value;
                      });
                      _loadEmployees(searchTerm: _currentSearchTerm);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Employee>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final employee = snapshot.data![index];
                      return ListTile(
                        title: Text(
                          '${employee.persNombres} ${employee.persApellidos}',
                        ),
                        subtitle: Text(employee.persDocumento),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (context) => FingerprintRegistrationScreen(
                                    employeeId: employee.emplId,
                                    employeeName:
                                        '${employee.persNombres} ${employee.persApellidos}',
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
