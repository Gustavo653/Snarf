import 'dart:developer';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class CallManager extends ChangeNotifier {
  final JitsiMeet jitsiMeet = JitsiMeet();

  bool _isInCall = false;
  bool _isCallOverlayVisible = false;

  String? _activeRoomId;
  String? _activeCallerUserId;
  String? _activeCallerName;

  String? _incomingRoomId;
  String? _incomingCallerUserId;
  String? _incomingCallerName;

  bool get isInCall => _isInCall;

  bool get isCallOverlayVisible => _isCallOverlayVisible;

  String? get incomingRoomId => _incomingRoomId;

  String? get incomingCallerUserId => _incomingCallerUserId;

  String? get incomingCallerName => _incomingCallerName;

  String? get activeRoomId => _activeRoomId;

  String? get activeCallerUserId => _activeCallerUserId;

  String? get activeCallerName => _activeCallerName;

  CallManager() {
    _setupCallSignals();
  }

  void _setupCallSignals() {
    SignalRManager().listenToEvent("ReceiveMessage", _onReceiveMessage);
  }

  void _onReceiveMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);
      log(args[0] as String);

      final SignalREventType type = SignalREventType.values.firstWhere(
        (e) => e.toString().split('.').last == message['Type'],
        orElse: () => SignalREventType.MapReceiveLocation,
      );

      final dynamic data = message['Data'];

      switch (type) {
        case SignalREventType.VideoCallIncoming:
          _handleVideoCallIncoming(data);
          break;
        case SignalREventType.VideoCallAccept:
          _handleVideoCallAccept(data);
          break;
        case SignalREventType.VideoCallReject:
          _handleVideoCallReject(data);
          break;
        case SignalREventType.VideoCallEnd:
          _handleVideoCallEnd(data);
          break;
        default:
          break;
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleVideoCallIncoming(Map<String, dynamic> data) {
    final newRoomId = data['roomId'] as String?;
    final newCallerUserId = data['callerUserId'] as String?;
    final newCallerUserName = data['callerName'] as String?;

    log("Recebemos uma chamada de $newCallerUserId, sala $newRoomId");
    if (_isInCall) {
      _incomingRoomId = newRoomId;
      _incomingCallerUserId = newCallerUserId;
      _incomingCallerName = newCallerUserName;
      _isCallOverlayVisible = true;
    } else {
      _incomingRoomId = newRoomId;
      _incomingCallerUserId = newCallerUserId;
      _incomingCallerName = newCallerUserName;
      _isCallOverlayVisible = true;
    }

    notifyListeners();
  }

  void _handleVideoCallAccept(Map<String, dynamic> data) {
    final acceptedRoomId = data['roomId'];
    log("O outro usuário aceitou a chamada da sala $acceptedRoomId");
    _joinJitsiRoom(acceptedRoomId);
  }

  void _handleVideoCallReject(Map<String, dynamic> data) {
    final rejectedRoomId = data['roomId'];
    log("Chamada da sala $rejectedRoomId foi rejeitada pelo outro usuário");

    if (rejectedRoomId == _activeRoomId) {
      _finishCall();
    }

    notifyListeners();
  }

  void _handleVideoCallEnd(Map<String, dynamic> data) {
    final endedRoomId = data['roomId'];
    log("Chamada $endedRoomId foi finalizada.");

    if (endedRoomId == _activeRoomId) {
      _finishCall();
    }
    notifyListeners();
  }

  Future<void> acceptCall() async {
    if (_isInCall && _incomingRoomId != null) {
      log("Encerrando chamada ativa para aceitar a nova...");
      await _endCurrentCall();
    }

    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager()
        .sendSignalRMessage(SignalREventType.VideoCallAccept, {
      "CallerUserId": _incomingCallerUserId,
      "RoomId": _incomingRoomId,
    });

    _joinJitsiRoom(_incomingRoomId!);

    _activeRoomId = _incomingRoomId;
    _activeCallerUserId = _incomingCallerUserId;
    _activeCallerName = _incomingCallerName;

    _incomingRoomId = null;
    _incomingCallerUserId = null;
    _incomingCallerName = null;

    _isCallOverlayVisible = false;
    notifyListeners();
  }

  Future<void> rejectCall() async {
    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager()
        .sendSignalRMessage(SignalREventType.VideoCallReject, {
      "CallerUserId": _incomingCallerUserId,
      "RoomId": _incomingRoomId,
    });

    _incomingRoomId = null;
    _incomingCallerUserId = null;
    _incomingCallerName = null;
    _isCallOverlayVisible = false;

    notifyListeners();
  }

  Future<void> startCall(String targetUserId) async {
    try {
      await SignalRManager()
          .sendSignalRMessage(SignalREventType.VideoCallInitiate, {
        "TargetUserId": targetUserId,
      });
    } catch (e) {
      log("Erro ao iniciar chamada: $e");
    }
  }

  Future<void> _joinJitsiRoom(String roomId) async {
    _isInCall = true;
    notifyListeners();

    final options = JitsiMeetConferenceOptions(
      room: roomId,
      userInfo: JitsiMeetUserInfo(
        displayName: _activeCallerName,
      ),
      serverURL: 'https://snarf-meet.inovitech.inf.br',
    );

    jitsiMeet.join(
      options,
      JitsiMeetEventListener(
        conferenceTerminated: (message, error) async {
          await _endCurrentCall();
        },
      ),
    );
  }

  Future<void> _endCurrentCall() async {
    if (_activeRoomId != null) {
      await SignalRManager().sendSignalRMessage(SignalREventType.VideoCallEnd, {
        "RoomId": _activeRoomId,
      });
    }
    _finishCall();
  }

  void _finishCall() {
    jitsiMeet.hangUp();
    _isInCall = false;
    _activeRoomId = null;
    _activeCallerUserId = null;
    _activeCallerName = null;
    _isCallOverlayVisible = false;
    notifyListeners();
  }
}
