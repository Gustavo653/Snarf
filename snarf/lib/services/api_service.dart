import 'dart:convert';
import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:snarf/utils/api_constants.dart';

class ApiService {
  static const _secureStorage = FlutterSecureStorage();
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<String?> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/Login');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'email': email, 'password': password});
    try {
      await _analytics.logEvent(name: 'api_login_attempt');
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['object'] != null &&
            responseData['object']['token'] != null) {
          final token = responseData['object']['token'];
          await _secureStorage.write(key: 'token', value: token);
          await _analytics.logEvent(name: 'api_login_success');
          return null;
        }
      }
      final responseData = jsonDecode(response.body);
      await _analytics.logEvent(
        name: 'api_login_failure',
        parameters: {'error': responseData['message'] ?? 'Erro desconhecido'},
      );
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_login_exception', parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> register(
      String email, String name, String password, String image) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(
        {'email': email, 'name': name, 'password': password, 'image': image});
    try {
      await _analytics.logEvent(name: 'api_register_attempt');
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        await _analytics.logEvent(name: 'api_register_success');
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await _analytics.logEvent(
          name: 'api_register_failure',
          parameters: {'error': responseData['message'] ?? 'Erro desconhecido'},
        );
        return responseData['message'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_register_exception', parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> requestResetPassword(String email) async {
    final url =
        Uri.parse('${ApiConstants.baseUrl}/Account/RequestResetPassword');
    final headers = {'Content-Type': 'application/json'};
    try {
      await _analytics.logEvent(name: 'api_request_reset_password_attempt');
      final response =
          await http.post(url, headers: headers, body: jsonEncode(email));
      if (response.statusCode == 200) {
        await _analytics.logEvent(name: 'api_request_reset_password_success');
        return null;
      }
      final responseData = jsonDecode(response.body);
      await _analytics.logEvent(
        name: 'api_request_reset_password_failure',
        parameters: {'error': responseData['message'] ?? 'Erro desconhecido'},
      );
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_request_reset_password_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> resetPassword(
      String email, String code, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/ResetPassword');
    final headers = {'Content-Type': 'application/json'};
    final body =
        jsonEncode({'email': email, 'code': code, 'password': password});
    try {
      await _analytics.logEvent(name: 'api_reset_password_attempt');
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        await _analytics.logEvent(name: 'api_reset_password_success');
        return null;
      }
      final responseData = jsonDecode(response.body);
      await _analytics.logEvent(
        name: 'api_reset_password_failure',
        parameters: {'error': responseData['message'] ?? 'Erro desconhecido'},
      );
      return responseData['message'] ?? 'Erro desconhecido';
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_reset_password_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> getUserIdFromToken() async {
    final token = await ApiService.getToken();
    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      return payload['nameid'];
    }
    return null;
  }

  static Future<String?> blockUser(String blockedUserId) async {
    final token = await ApiService.getToken();
    if (token == null) return 'Token não encontrado';
    final url = Uri.parse(
        '${ApiConstants.baseUrl}/Account/BlockUser?blockedUserId=$blockedUserId');
    try {
      await _analytics.logEvent(
          name: 'api_block_user_attempt',
          parameters: {'blockedUserId': blockedUserId});
      final response = await http.post(url,
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        await _analytics.logEvent(
            name: 'api_block_user_success',
            parameters: {'blockedUserId': blockedUserId});
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await _analytics.logEvent(
          name: 'api_block_user_failure',
          parameters: {
            'error': responseData['message'] ?? 'Erro ao bloquear usuário'
          },
        );
        return responseData['message'] ?? 'Erro ao bloquear usuário';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_block_user_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> unblockUser(String blockedUserId) async {
    final token = await ApiService.getToken();
    if (token == null) return 'Token não encontrado';
    final url = Uri.parse(
        '${ApiConstants.baseUrl}/Account/UnblockUser?blockedUserId=$blockedUserId');
    try {
      await _analytics.logEvent(
          name: 'api_unblock_user_attempt',
          parameters: {'blockedUserId': blockedUserId});
      final response = await http.post(url,
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        await _analytics.logEvent(
            name: 'api_unblock_user_success',
            parameters: {'blockedUserId': blockedUserId});
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await _analytics.logEvent(
          name: 'api_unblock_user_failure',
          parameters: {
            'error': responseData['message'] ?? 'Erro ao desbloquear usuário'
          },
        );
        return responseData['message'] ?? 'Erro ao desbloquear usuário';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_unblock_user_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<Map<String, dynamic>?> getUserInfoById(String userId) async {
    final token = await ApiService.getToken();
    if (token == null) return null;
    try {
      await _analytics.logEvent(
          name: 'api_get_user_info_attempt', parameters: {'userId': userId});
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/Account/GetUser/$userId'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        await _analytics.logEvent(
            name: 'api_get_user_info_success', parameters: {'userId': userId});
        return responseData['object'];
      } else {
        log('Erro ao obter informações do usuário: ${response.body}');
        await _analytics.logEvent(
          name: 'api_get_user_info_failure',
          parameters: {'error': response.body},
        );
        return null;
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_get_user_info_exception',
          parameters: {'error': e.toString()});
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getFirstMessageOfDay() async {
    final token = await ApiService.getToken();
    if (token == null) return null;
    try {
      await _analytics.logEvent(name: 'api_get_first_message_today_attempt');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/Account/GetFirstMessageToday'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        await _analytics.logEvent(name: 'api_get_first_message_today_success');
        return responseData['object'];
      } else {
        log('Erro ao obter informações do usuário: ${response.body}');
        await _analytics.logEvent(
          name: 'api_get_first_message_today_failure',
          parameters: {'error': response.body},
        );
        return null;
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_get_first_message_today_exception',
          parameters: {'error': e.toString()});
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
    try {
      await _analytics.logEvent(
          name: 'api_edit_user_attempt', parameters: {'userId': userId});
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
        await _analytics.logEvent(
            name: 'api_edit_user_success', parameters: {'userId': userId});
        return null;
      } else {
        await _analytics.logEvent(
          name: 'api_edit_user_failure',
          parameters: {'error': response.body},
        );
        return 'Erro ao editar usuário: ${response.body}';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_edit_user_exception', parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> deleteUser(String userId) async {
    final token = await ApiService.getToken();
    if (token == null) return 'Token não encontrado';
    try {
      await _analytics.logEvent(
          name: 'api_delete_user_attempt', parameters: {'userId': userId});
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/Account/$userId'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        await _analytics.logEvent(
            name: 'api_delete_user_success', parameters: {'userId': userId});
        return null;
      } else {
        await _analytics.logEvent(
          name: 'api_delete_user_failure',
          parameters: {'error': response.body},
        );
        return 'Erro ao deletar usuário: ${response.body}';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_delete_user_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> reportMessage(String messageId) async {
    final token = await getToken();
    if (token == null) return 'Token não encontrado';
    final url = Uri.parse(
        '${ApiConstants.baseUrl}/Account/ReportUserPublicMessage?messageId=$messageId');
    try {
      await _analytics.logEvent(
          name: 'api_report_message_attempt',
          parameters: {'messageId': messageId});
      final response = await http.post(url,
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        await _analytics.logEvent(
            name: 'api_report_message_success',
            parameters: {'messageId': messageId});
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await _analytics.logEvent(
          name: 'api_report_message_failure',
          parameters: {
            'error': responseData['message'] ?? 'Erro ao denunciar mensagem'
          },
        );
        return responseData['message'] ?? 'Erro ao denunciar mensagem';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_report_message_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> reportUser(String userId) async {
    final token = await getToken();
    if (token == null) return 'Token não encontrado';
    final url =
        Uri.parse('${ApiConstants.baseUrl}/Account/ReportUser?userId=$userId');
    try {
      await _analytics.logEvent(
          name: 'api_report_user_attempt', parameters: {'userId': userId});
      final response = await http.post(url,
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        await _analytics.logEvent(
            name: 'api_report_user_success', parameters: {'userId': userId});
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await _analytics.logEvent(
          name: 'api_report_user_failure',
          parameters: {
            'error': responseData['message'] ?? 'Erro ao denunciar mensagem'
          },
        );
        return responseData['message'] ?? 'Erro ao denunciar mensagem';
      }
    } catch (e) {
      await _analytics.logEvent(
          name: 'api_report_user_exception',
          parameters: {'error': e.toString()});
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> addExtraMinutes({
    required int minutes,
    String? subscriptionId,
    String? tokenFromPurchase,
  }) async {
    final userJwtToken = await getToken();
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/AddExtraMinutes');
    final headers = {
      'accept': '*/*',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $userJwtToken',
    };

    final body = jsonEncode({
      "subscriptionId": subscriptionId ?? "string",
      "token": tokenFromPurchase ?? "string",
      "minutes": minutes,
    });

    try {
      await _analytics.logEvent(
        name: 'api_add_extra_minutes_attempt',
        parameters: {
          'minutes': minutes,
        },
      );

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        await _analytics.logEvent(
          name: 'api_add_extra_minutes_success',
          parameters: {
            'minutes': minutes,
          },
        );
        return null;
      } else {
        await _analytics.logEvent(
          name: 'api_add_extra_minutes_failure',
          parameters: {
            'minutes': minutes,
            'statusCode': response.statusCode,
            'error': response.body,
          },
        );
        return 'Erro: ${response.body}';
      }
    } catch (e) {
      await _analytics.logEvent(
        name: 'api_add_extra_minutes_exception',
        parameters: {
          'minutes': minutes,
          'error': e.toString(),
        },
      );
      return 'Exceção: $e';
    }
  }

  static Future<String?> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/ChangeEmail');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'newEmail': newEmail,
      'currentPassword': currentPassword,
    });
    try {
      await FirebaseAnalytics.instance
          .logEvent(name: 'api_change_email_attempt');
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        await FirebaseAnalytics.instance
            .logEvent(name: 'api_change_email_success');
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await FirebaseAnalytics.instance.logEvent(
          name: 'api_change_email_failure',
          parameters: {'error': responseData.toString()},
        );
        return responseData['message'];
      }
    } catch (e) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'api_change_email_exception',
        parameters: {'error': e.toString()},
      );
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConstants.baseUrl}/Account/ChangePassword');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    try {
      await FirebaseAnalytics.instance
          .logEvent(name: 'api_change_password_attempt');
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        await FirebaseAnalytics.instance
            .logEvent(name: 'api_change_password_success');
        return null;
      } else {
        final responseData = jsonDecode(response.body);
        await FirebaseAnalytics.instance.logEvent(
          name: 'api_change_password_failure',
          parameters: {'error': responseData.toString()},
        );
        return responseData['message'];
      }
    } catch (e) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'api_change_password_exception',
        parameters: {'error': e.toString()},
      );
      return 'Erro ao conectar à API: $e';
    }
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'token');
  }

  static Future<void> logout() async {
    await _secureStorage.delete(key: 'token');
    await _analytics.logEvent(name: 'api_logout');
  }

  static Future<Map<String, dynamic>?> createParty({
    required String email,
    required String title,
    required String description,
    required DateTime startDate,
    required int duration,
    required int type,
    required String location,
    required String instructions,
    required double latitude,
    required double longitude,
    required String coverImageBase64,
  }) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('${ApiConstants.baseUrl}/Party');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      "email": email,
      "title": title,
      "description": description,
      "startDate": startDate.toUtc().toIso8601String(),
      "duration": duration,
      "type": type,
      "location": location,
      "instructions": instructions,
      "lastLatitude": latitude,
      "lastLongitude": longitude,
      "coverImage": coverImageBase64
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['object'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateParty({
    required String partyId,
    required String title,
    required String description,
    required String location,
    required String instructions,
    required DateTime startDate,
    required int duration,
  }) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('${ApiConstants.baseUrl}/Party/$partyId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      "title": title,
      "description": description,
      "location": location,
      "instructions": instructions,
      "startDate": startDate.toUtc().toIso8601String(),
      "duration": duration
    });
    try {
      final response = await http.put(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['object'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAllParties(String userId) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('${ApiConstants.baseUrl}/Party/all$userId');
    try {
      final response = await http.get(url, headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['object'] is List
            ? {"data": responseData['object']}
            : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPartyDetails({
    required String partyId,
    required String userId,
  }) async {
    final token = await getToken();
    if (token == null) return null;
    final url =
        Uri.parse('${ApiConstants.baseUrl}/Party/$partyId/details/$userId');
    try {
      final response = await http.get(url, headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['object'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}