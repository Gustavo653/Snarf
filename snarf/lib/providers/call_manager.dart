import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/config_provider.dart';

import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class CallManager extends ChangeNotifier {
  final JitsiMeet jitsiMeet = JitsiMeet();
  final ConfigProvider configProvider;

  bool _isInCall = false;
  bool _isCallOverlayVisible = false;
  bool _isCallRejectedOverlayVisible = false;

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

  bool get isCallRejectedOverlayVisible => _isCallRejectedOverlayVisible;
  String _callRejectionReason = "";

  String get callRejectionReason => _callRejectionReason;

  CallManager(this.configProvider) {
    _setupCallSignals();
  }

  void _setupCallSignals() {
    SignalRManager().listenToEvent("ReceiveMessage", _onReceiveMessage);
  }

  void _onReceiveMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;

    try {
      final Map<String, dynamic> message = jsonDecode(args[0] as String);

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
          case SignalREventType.PrivateChatReceiveMessage:
          _handleReceivedNewMessage(data);
          break;
        case SignalREventType.PrivateChatReceiveRecentChats:
          _handleRecentChats(data);
          break;
        default:
          break;
      }
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: "Erro ao processar mensagem SignalR",
      );
    }
  }

  void _handleReceivedNewMessage(dynamic data) {
    configProvider.SetNotificationMessage(true);
  }

  void _handleRecentChats(List<Object?>? data) {
    try {
      final parsedData = data as List<dynamic>;
      parsedData.map((item) {
        final mapItem = item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item);

        var count = mapItem['UnreadCount'];
        if(count > 0){
          configProvider.SetNotificationMessage(true);
        }
      }).toList();
    } catch (e, s) {
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: "Erro ao iniciar chamada");
    }
  }

  void _handleVideoCallIncoming(Map<String, dynamic> data) {
    if (!configProvider.isSubscriber) {
      _handleVideoCallReject(data);
      return;
    }

    final newRoomId = data['roomId'] as String?;
    final newCallerUserId = data['callerUserId'] as String?;
    final newCallerUserName = data['callerName'] as String?;

    _incomingRoomId = newRoomId;
    _incomingCallerUserId = newCallerUserId;
    _incomingCallerName = newCallerUserName;
    _isCallOverlayVisible = true;

    FirebaseAnalytics.instance.logEvent(
      name: 'video_call_incoming',
      parameters: {
        'roomId': newRoomId!,
        'callerUserId': newCallerUserId!,
        'callerName': newCallerUserName!,
      },
    );

    notifyListeners();
  }

  void _handleVideoCallAccept(Map<String, dynamic> data) {
    final acceptedRoomId = data['roomId'];

    FirebaseAnalytics.instance.logEvent(
      name: 'video_call_accepted',
      parameters: {
        'roomId': acceptedRoomId,
      },
    );

    _joinJitsiRoom(acceptedRoomId);
  }

  void _handleVideoCallReject(Map<String, dynamic> data) {
    final rejectedRoomId = data['roomId'];
    final reason = data['reason'] as String? ?? "Chamada rejeitada.";

    FirebaseAnalytics.instance.logEvent(
      name: 'video_call_rejected',
      parameters: {
        'roomId': rejectedRoomId ?? '',
        'reason': reason,
      },
    );

    if (rejectedRoomId == _activeRoomId) {
      _finishCall();
    }

    _callRejectionReason = reason;
    _isCallRejectedOverlayVisible = true;
    notifyListeners();
  }

  void closeRejectionOverlay() {
    _isCallRejectedOverlayVisible = false;
    _callRejectionReason = "";
    notifyListeners();
  }

  void _handleVideoCallEnd(Map<String, dynamic> data) {
    final endedRoomId = data['roomId'];

    FirebaseAnalytics.instance.logEvent(
      name: 'video_call_ended',
      parameters: {
        'roomId': endedRoomId,
      },
    );

    if (endedRoomId == _activeRoomId) {
      _finishCall();
    }
    notifyListeners();
  }

  Future<void> acceptCall() async {
    if (_isInCall && _incomingRoomId != null) {
      FirebaseAnalytics.instance.logEvent(
        name: 'accept_call_while_in_call',
        parameters: {
          'message': "Encerrando chamada ativa para aceitar a nova",
        },
      );
      await _endCurrentCall();
    }

    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager().sendSignalRMessage(
      SignalREventType.VideoCallAccept,
      {
        "CallerUserId": _incomingCallerUserId,
        "RoomId": _incomingRoomId,
      },
    );

    _activeRoomId = _incomingRoomId;
    _activeCallerUserId = _incomingCallerUserId;
    _activeCallerName = _incomingCallerName;

    _incomingRoomId = null;
    _incomingCallerUserId = null;
    _incomingCallerName = null;
    _isCallOverlayVisible = false;

    _joinJitsiRoom(_activeRoomId!);
    notifyListeners();
  }

  Future<void> rejectCall() async {
    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager().sendSignalRMessage(
      SignalREventType.VideoCallReject,
      {
        "CallerUserId": _incomingCallerUserId,
        "RoomId": _incomingRoomId,
      },
    );

    _incomingRoomId = null;
    _incomingCallerUserId = null;
    _incomingCallerName = null;
    _isCallOverlayVisible = false;

    notifyListeners();
  }

  Future<void> startCall(String targetUserId) async {
    try {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.VideoCallInitiate,
        {
          "TargetUserId": targetUserId,
        },
      );

      FirebaseAnalytics.instance.logEvent(
        name: 'video_call_start',
        parameters: {
          'targetUserId': targetUserId,
        },
      );
    } catch (e, s) {
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: "Erro ao iniciar chamada");
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
        participantLeft: (message) async {
          await _endCurrentCall();
        },
        conferenceTerminated: (message, error) async {
          await _endCurrentCall();
        },
      ),
    );
  }

  Future<void> _endCurrentCall() async {
    if (_activeRoomId != null) {
      await SignalRManager().sendSignalRMessage(
        SignalREventType.VideoCallEnd,
        {
          "RoomId": _activeRoomId,
        },
      );
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
