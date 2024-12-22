import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/utils/api_constants.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();

  static Future<String?> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/Login');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['object'] != null &&
            responseData['object']['token'] != null) {
          final token = responseData['object']['token'];

          await _secureStorage.write(key: 'token', value: token);

          return null;
        }
      }

      final responseData = jsonDecode(response.body);
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> register(
      String email, String name, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'name': name,
      'password': password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        return responseData['message'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> requestResetPassword(String email) async {
    final url =
        Uri.parse('${ApiConstants.baseUrl}/Account/RequestResetPassword');
    final headers = {
      'Content-Type': 'application/json',
    };

    try {
      final response =
          await http.post(url, headers: headers, body: jsonEncode(email));

      if (response.statusCode == 200) {
        return null;
      }

      final responseData = jsonDecode(response.body);
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> resetPassword(
      String email, String code, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/ResetPassword');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'code': code,
      'password': password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        return null;
      }

      final responseData = jsonDecode(response.body);
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'token');
  }

  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
  }
}
