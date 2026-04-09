import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:anfibius_uwu/services/api_constants.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class AuthService extends ChangeNotifier {
  // Llaves de SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // credenciales
  static const String _rucKey = 'auth_ruc';
  static const String _userKey = 'auth_user';
  static const String _passEncryptedKey = 'auth_pass_enc';

  // Llave local de encriptación
  static const String _localSecureKeyStr = "AnfibiusLocalStorageKey2026_32b!";
  static const String _localIvStr = "LocalInitVec1234";

  String? _authToken;
  String? _currentUserId;
  bool _isAutoLoggingIn = false; // Bandera para la UI

  AuthService() {
    _loadTokenAndAutoLogin();
  }

  String? get authToken => _authToken;
  String? get currentUserId => _currentUserId;
  bool get isAutoLoggingIn => _isAutoLoggingIn;

  // ==========================================
  // 🔐 MÉTODOS DE ENCRIPTACIÓN LOCAL
  // ==========================================
  String _encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(_localSecureKeyStr);
    final iv = encrypt.IV.fromUtf8(_localIvStr);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  String _decryptData(String encryptedBase64) {
    final key = encrypt.Key.fromUtf8(_localSecureKeyStr);
    final iv = encrypt.IV.fromUtf8(_localIvStr);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    return encrypter.decrypt(
      encrypt.Encrypted.fromBase64(encryptedBase64),
      iv: iv,
    );
  }

  // 🔄 INICIO AL ABRIR LA APP
  Future<void> _loadTokenAndAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    _currentUserId = prefs.getString(_userIdKey);
    notifyListeners();

    // Si abrimos la app y no hay token (o ya venció y se borró), intentamos auto-login
    if (_authToken == null) {
      await autoReLogin();
    }
  }

  // 🔄 AUTO RE-LOGIN SILENCIOSO
  Future<bool> autoReLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final ruc = prefs.getString(_rucKey);
    final user = prefs.getString(_userKey);
    final passEncrypted = prefs.getString(_passEncryptedKey);

    // Si no hay credenciales guardadas, no podemos hacer magia
    if (ruc == null || user == null || passEncrypted == null) {
      return false;
    }

    _isAutoLoggingIn = true;
    notifyListeners();

    print('🔄 Iniciando Auto-Login en segundo plano...');

    try {
      // Desencriptamos la clave localmente para enviarla a la API
      final plainPass = _decryptData(passEncrypted);

      // Usamos el login normal pero sin volver a encriptar/guardar (ya están guardadas)
      final success = await _executeLoginApi(ruc, user, plainPass);

      if (success) {
        print('✅ Auto-Login exitoso. Sesión restaurada.');
      } else {
        print('❌ Auto-Login falló. Credenciales revocadas o sin internet.');
      }
      return success;
    } catch (e) {
      print('❌ Error en Auto-Login: $e');
      return false;
    } finally {
      _isAutoLoggingIn = false;
      notifyListeners();
    }
  }

  // 👤 LOGIN MANUAL DESDE LA UI
  Future<bool> login(String ruc, String username, String password) async {
    final success = await _executeLoginApi(ruc, username, password);

    if (success) {
      // 🔐 Si el login manual fue exitoso, encriptamos y guardamos para el futuro
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rucKey, ruc);
      await prefs.setString(_userKey, username);
      await prefs.setString(_passEncryptedKey, _encryptData(password));
    }

    return success;
  }

  // Lógica pura de la petición HTTP (Reutilizada por Login Manual y Auto-Login)
  Future<bool> _executeLoginApi(
    String ruc,
    String username,
    String password,
  ) async {
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
      }
      return false;
    } catch (e) {
      print('Error during login API call: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Borramos TODOS los datos, incluyendo credenciales encriptadas
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_rucKey);
    await prefs.remove(_userKey);
    await prefs.remove(_passEncryptedKey);

    _authToken = null;
    _currentUserId = null;
    notifyListeners();
  }
}
