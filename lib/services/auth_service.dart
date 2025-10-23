import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:anfibius_uwu/services/api_constants.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  String? _authToken;
  String? _currentUserId;

  AuthService() {
    _loadToken();
  }

  String? get authToken => _authToken;
  String? get currentUserId => _currentUserId;

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    _currentUserId = prefs.getString(_userIdKey);
    notifyListeners();
  }

  Future<bool> login(String ruc, String username, String password) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/anfibiusBack/api/usuarios/login',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'empr_ruc': ruc,
          'usua_nombre': username,
          'usua_password': password,
          'sistema': '',
          'ubicacion': '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final token = responseData['data']['JWT'];
        final userId =
            json.decode(responseData['data']['usuario'])['usua_id'].toString();

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userIdKey, userId);
          _authToken = token;
          _currentUserId = userId;
          notifyListeners();
          return true;
        }
        return false;
      } else {
        print('Login failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    if (_currentUserId != null) return _currentUserId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    _authToken = null;
    _currentUserId = null;
    notifyListeners();
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }
}
