import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/utils/api_constants.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();

  static Future<bool> login(String email, String password) async {
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

          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> register(String email, String name, String password) async {
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
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'token');
  }

  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
  }
}
