import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/api_constants.dart';
import 'package:anfibius_uwu/main.dart'; // Importante para el navigatorKey

class EmployeeService {
  final AuthService _authService;

  EmployeeService(this._authService);

  Future<List<Employee>> getEmployees({
    int? id,
    String? searchTerm,
    String? searchType,
    int? limit,
    int? offset,
  }) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Token de autenticación no encontrado.');
    }

    Uri uri;

    if (searchType == 'CExA' || searchType == 'CExNA') {
      // Recuerda: CExNA = Con Huella, CExA = Sin Huella
      final bool conHuella = (searchType == 'CExNA');

      final Map<String, String> queryParams = {
        'con_huella': conHuella.toString(),
        'busqueda': searchTerm ?? '',
        'limit': limit?.toString() ?? '10',
        'offset': offset?.toString() ?? '0',
      };

      uri = Uri.parse(
        '${ApiConstants.baseUrl}/empleados/filtro-biometria',
      ).replace(queryParameters: queryParams);
    } else {
      final Map<String, String> queryParams = {
        'id': id?.toString() ?? '',
        'limit': limit?.toString() ?? '10',
        'offset': offset?.toString() ?? '0',
        'busqueda': searchTerm ?? '',
        'tipoconsul': searchType ?? '',
      };

      uri = Uri.parse(
        '${ApiConstants.baseUrl}/empleados',
      ).replace(queryParameters: queryParams);
    }

    print('Fetching employees from: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok' && responseData['data'] is List) {
          return (responseData['data'] as List)
              .map((e) => Employee.fromJson(e))
              .toList();
        }
        throw Exception('Error cargando empleados: ${responseData['message']}');
      } else if (response.statusCode == 401) {
        print(
          '⚠️ El servidor rechazó el Token (401). Forzando cierre de sesión...',
        );

        await _authService.logout();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
        throw Exception('Credenciales inválidas o revocadas por el servidor.');
      } else {
        throw Exception(
          'Fallo de conexión: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching employees: $e');
      rethrow;
    }
  }
}
