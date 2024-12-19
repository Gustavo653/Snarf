import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/utils/api_constants.dart';

class ApiService {
  // Instância do FlutterSecureStorage
  static const _secureStorage = FlutterSecureStorage();

  // Método para fazer login
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
      // Fazer requisição POST para o endpoint de login
      final response = await http.post(url, headers: headers, body: body);

      // Verificar status da resposta
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Verificar se o token foi retornado
        if (responseData['object'] != null && responseData['object']['token'] != null) {
          final token = responseData['object']['token'];

          // Armazenar o token de forma segura
          await _secureStorage.write(key: 'token', value: token);

          return true; // Login bem-sucedido
        }
      }

      return false; // Falha no login (status != 200 ou sem token)
    } catch (e) {
      // Exibir erro no console (apenas para debugging)
      print('Erro na requisição de login: $e');
      return false; // Retornar falso em caso de erro
    }
  }

  // Método para recuperar o token armazenado
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'token');
  }

  // Método para remover o token (logout)
  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
  }
}