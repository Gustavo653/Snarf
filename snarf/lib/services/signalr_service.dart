import 'dart:developer';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignalRService {
  late HubConnection _hubConnection;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<String> _getAccessToken() async {
    return await _storage.read(key: 'token') ?? '';
  }

  Future<void> setupConnection({
    required String hubUrl,
    required List<String> onMethods,
    required Map<String, Function(List<Object?>?)> eventHandlers,
  }) async {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _getAccessToken(),
          ),
        )
        .withAutomaticReconnect()
        .build();

    for (int i = 0; i < onMethods.length; i++) {
      _hubConnection.on(onMethods[i], eventHandlers[onMethods[i]]!);
    }

    try {
      await _hubConnection.start();
    } catch (err) {
      rethrow;
    }
  }

  Future<void> invokeMethod(String methodName, List<Object> args) async {
    try {
      await _hubConnection.invoke(methodName, args: args);
    } catch (err) {
      log("Erro ao invocar o método: $err");
      await _reconnect();

      try {
        await _hubConnection.invoke(methodName, args: args);
      } catch (retryErr) {
        log("Falha ao invocar o método novamente: $retryErr");
        rethrow;
      }
    }
  }

  Future<void> _reconnect() async {
    if (_hubConnection.state != HubConnectionState.Connected) {
      try {
        log("Tentando reconectar...");
        await _hubConnection.stop();
        await _hubConnection.start();
        log("Reconexão bem-sucedida.");
      } catch (err) {
        log("Erro ao reconectar: $err");
        rethrow;
      }
    }
  }

  Future<void> stopConnection() async {
    await _hubConnection.stop();
  }
}
