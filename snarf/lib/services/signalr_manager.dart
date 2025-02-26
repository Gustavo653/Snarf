import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class SignalRManager {
  static final SignalRManager _instance = SignalRManager._internal();

  factory SignalRManager() => _instance;

  SignalRManager._internal();

  late HubConnection _hubConnection;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
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
      await _analytics.logEvent(name: 'signalr_connection_success');
    } catch (e) {
      await _analytics.logEvent(
          name: 'signalr_connection_error',
          parameters: {'error': e.toString()});
    }
  }

  Future<void> stopConnection() async {
    if (_isConnected) {
      await _hubConnection.stop();
      _isConnected = false;
      await _analytics.logEvent(name: 'signalr_connection_stopped');
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
      await _analytics.logEvent(
          name: 'signalr_send_message', parameters: {'message': message});
    } catch (e) {
      await _analytics.logEvent(
          name: 'signalr_send_message_error',
          parameters: {'error': e.toString()});
    }
  }

  Future<void> invokeMethod(String methodName, List<Object> args) async {
    if (!_isConnected) await initializeConnection();
    try {
      await _hubConnection.invoke(methodName, args: args);
    } catch (e) {
      await _analytics.logEvent(
          name: 'signalr_invoke_method_error',
          parameters: {'method': methodName, 'error': e.toString()});
    }
  }

  void listenToEvent(String eventName, Function(List<Object?>?) callback) {
    if (!_isConnected) return;
    _hubConnection.on(eventName, callback);
  }
}
