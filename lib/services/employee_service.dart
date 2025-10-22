import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:anfibius_uwu/models/employee.dart';
import 'package:anfibius_uwu/services/auth_service.dart';

class EmployeeService {
  static const String _baseUrl =
      'http://localhost:8080'; // Replace with your actual API base URL
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

    final Map<String, String> queryParams = {};
    if (id != null) queryParams['id'] = id.toString();
    if (searchTerm != null) queryParams['busqueda'] = searchTerm;
    if (searchType != null) queryParams['tipoconsul'] = searchType;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri = Uri.parse(
      '$_baseUrl/anfibiusback/api/empleados',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
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
