import 'package:anfibius_uwu/screens/employee_management_screen.dart';
import 'package:flutter/material.dart';

class Nomina extends StatefulWidget {
  const Nomina({super.key});

  @override
  State<Nomina> createState() => _NominaState();
}

class _NominaState extends State<Nomina> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          height: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Gestión de Empleados",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Buscar Empleado',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => const EmployeeManagementScreen(),
                        ),
                      );
                    },
                    child: const Text('Administrar Empleados'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
