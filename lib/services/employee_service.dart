import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/auth_service.dart';
import 'package:anfibius_uwu/services/api_constants.dart';

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
      throw Exception('Authentication token not found. Please log in.');
    }

    final Map<String, String> queryParams = {
      'id': id?.toString() ?? '',
      'limit': limit?.toString() ?? '10',
      'offset': offset?.toString() ?? '0',
      'busqueda': searchTerm ?? '',
      'tipoconsul': searchType ?? 'CExNA',
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/anfibiusBack/api/empleados',
    ).replace(queryParameters: queryParams);

    print('Fetching employees from: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print(response.body);
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok' && responseData['data'] is List) {
          return (responseData['data'] as List)
              .map((e) => Employee.fromJson(e))
              .toList();
        }
        throw Exception('Failed to load employees: ${responseData['message']}');
      } else {
        throw Exception(
          'Failed to load employees: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching employees: $e');
      rethrow;
    }
  }
}
