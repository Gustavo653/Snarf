import 'dart:convert';
import 'dart:developer';
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
      String email, String name, String password, String image) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account');
    final headers = {
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'name': name,
      'password': password,
      'image': image
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

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final token = await ApiService.getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/Account/Current'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['object'];
    } else {
      log('Erro ao obter informações do usuário: ${response.body}');
      return null;
    }
  }

  static Future<String?> editUser(
    String userId,
    String name,
    String email,
    String? password,
    String? base64Image,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) return 'Token não encontrado';

    final body = jsonEncode({
      'email': email,
      'name': name,
      'password': password,
      'Image': base64Image,
    });

    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/Account/$userId'),
      headers: {
        'accept': '*/*',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return null;
    } else {
      return 'Erro ao editar usuário: ${response.body}';
    }
  }

  static Future<String?> deleteUser(String userId) async {
    final token = await ApiService.getToken();
    if (token == null) return 'Token não encontrado';

    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/Account/$userId'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return null;
    } else {
      return 'Erro ao deletar usuário: ${response.body}';
    }
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'token');
  }

  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
  }
}
