import 'dart:convert';
import 'dart:developer';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class SignalRManager {
  static final SignalRManager _instance = SignalRManager._internal();

  factory SignalRManager() => _instance;

  SignalRManager._internal();

  late HubConnection _hubConnection;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool _isConnected = false;

  Future<String> _getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> initializeConnection() async {
    if (_isConnected) return;

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          '${ApiConstants.baseUrl.replaceAll('/api', '')}/SnarfHub',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _getAccessToken(),
            requestTimeout: 10000,
            logMessageContent: true,
          ),
        )
        .withAutomaticReconnect()
        .build();

    try {
      await _hubConnection.start();
      _isConnected = true;
      log('Conexão SignalR estabelecida com sucesso!');
    } catch (e) {
      log('Erro ao conectar ao SignalR: $e');
    }
  }

  Future<void> stopConnection() async {
    if (_isConnected) {
      await _hubConnection.stop();
      _isConnected = false;
    }
  }

  Future<void> sendSignalRMessage(
      SignalREventType type, Map<String, dynamic> data) async {
    final message = jsonEncode({
      "Type": type.toString().split('.').last,
      "Data": data,
    });

    try {
      await invokeMethod("SendMessage", [message]);
      log('Mensagem enviada: $message');
    } catch (e) {
      log('Erro ao enviar mensagem: $e');
    }
  }

  Future<void> invokeMethod(String methodName, List<Object> args) async {
    if (!_isConnected) await initializeConnection();
    try {
      await _hubConnection.invoke(methodName, args: args);
    } catch (e) {
      log("Erro ao invocar método SignalR: $e");
    }
  }

  void listenToEvent(String eventName, Function(List<Object?>?) callback) {
    if (!_isConnected) return;
    _hubConnection.on(eventName, callback);
  }
}
