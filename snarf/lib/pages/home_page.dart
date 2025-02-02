import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import 'package:snarf/pages/account/edit_user_page.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/privateChat/private_chat_navigation_page.dart';
import 'package:snarf/pages/public_chat_page.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/services/api_service.dart';
import 'package:snarf/services/signalr_manager.dart';
import 'package:snarf/utils/show_snackbar.dart';
import 'package:snarf/utils/signalr_event_type.dart';

class HomePage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const HomePage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late LocationData _currentLocation;
  bool _isLocationLoaded = false;
  late MapController _mapController;
  late Marker _userLocationMarker;
  Map<String, Marker> _userMarkers = {};
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  late String userImage = '';

  var jitsiMeet = JitsiMeet();
  bool _isCallOverlayVisible = false;
  String? _incomingRoomId;
  String? _incomingCallerUserId;
  String? _incomingCallerUserName;
  bool _isInCall = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadUserInfo();
    await _initializeLocation();
    await _setupSignalRConnection();
  }

  Future<void> _loadUserInfo() async {
    final userId = await ApiService.getUserIdFromToken();
    if (userId == null) {
      showSnackbar(context, 'Não foi possível obter ID do token');
      return;
    }

    final userInfo = await ApiService.getUserInfoById(userId);
    if (userInfo != null) {
      userImage = userInfo['imageUrl'];
    } else {
      showSnackbar(context, 'Erro ao carregar informações do usuário');
    }
  }

  Future<void> _initializeLocation() async {
    if (await _checkLocationPermissions()) {
      _getCurrentLocation();
      _startLocationUpdates();
    }
  }

  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await _location.getLocation();
      setState(() {
        _isLocationLoaded = true;
        _updateUserMarker(
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        );
      });
      log('Localização atual recuperada: $_currentLocation');
    } catch (err) {
      log('Erro ao recuperar localização: $err');
      showSnackbar(context, "Erro ao recuperar localização: $err");
    }
  }

  void _startLocationUpdates() {
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 5000);

    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        _currentLocation = newLocation;
        _updateUserMarker(newLocation.latitude!, newLocation.longitude!);
      });
      if (_currentLocation.longitude != null &&
          _currentLocation.latitude != null) {
        _sendLocationUpdate();
      }
    });
  }

  void _updateUserMarker(double latitude, double longitude) {
    _userLocationMarker = Marker(
      point: LatLng(latitude, longitude),
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red,
            width: 3.0,
          ),
        ),
        child: CircleAvatar(
          backgroundImage: NetworkImage(userImage),
          radius: 25,
        ),
      ),
    );
  }

  Future<void> _setupSignalRConnection() async {
    await SignalRManager().initializeConnection();
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
        case SignalREventType.MapReceiveLocation:
          _handleReceiveLocation(data);
          break;
        case SignalREventType.UserDisconnected:
          _handleUserDisconnected(data);
          break;
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
          log("Evento não reconhecido: ${message['Type']}");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleVideoCallIncoming(Map<String, dynamic> data) {
    setState(() {
      _incomingRoomId = data['roomId'] as String?;
      _incomingCallerUserId = data['callerUserId'] as String?;
      _incomingCallerUserName = data['callerName'] as String?;
      _isCallOverlayVisible = true;
    });
    log("Recebemos uma chamada de $_incomingCallerUserId, sala $_incomingRoomId");
  }

  void _handleVideoCallAccept(Map<String, dynamic> data) {
    final acceptedRoomId = data['roomId'];
    final targetUserId = data['targetUserId'];
    if (acceptedRoomId == _incomingRoomId) {
      log("O outro usuário aceitou a call! Abrir Jitsi...");
    }
    _joinJitsiRoom(acceptedRoomId);
  }

  void _handleVideoCallReject(Map<String, dynamic> data) {
    final rejectedRoomId = data['roomId'];
    final targetUserId = data['targetUserId'];
    log("Usuário $targetUserId rejeitou chamada de sala $rejectedRoomId");

    showSnackbar(context, "Sua chamada foi rejeitada");
    setState(() {
      _isCallOverlayVisible = false;
      _incomingRoomId = null;
      _incomingCallerUserId = null;
      _incomingCallerUserName = null;
    });
  }

  void _handleVideoCallEnd(Map<String, dynamic> data) {
    log("Chamada finalizada. Data: $data");
    jitsiMeet.hangUp();
    setState(() {
      _isInCall = false;
      _isCallOverlayVisible = false;
      _incomingRoomId = null;
      _incomingCallerUserId = null;
      _incomingCallerUserName = null;
    });
  }

  Future<void> _acceptCall() async {
    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager()
        .sendSignalRMessage(SignalREventType.VideoCallAccept, {
      "CallerUserId": _incomingCallerUserId,
      "RoomId": _incomingRoomId,
    });

    setState(() {
      _isCallOverlayVisible = false;
    });

    _joinJitsiRoom(_incomingRoomId!);
  }

  Future<void> _rejectCall() async {
    if (_incomingRoomId == null || _incomingCallerUserId == null) return;

    await SignalRManager()
        .sendSignalRMessage(SignalREventType.VideoCallReject, {
      "CallerUserId": _incomingCallerUserId,
      "RoomId": _incomingRoomId,
    });

    setState(() {
      _isCallOverlayVisible = false;
      _incomingRoomId = null;
      _incomingCallerUserId = null;
      _incomingCallerUserName = null;
    });
  }

  Future<void> _joinJitsiRoom(String roomId) async {
    setState(() {
      _isInCall = true;
    });
    final options = JitsiMeetConferenceOptions(
      room: roomId,
      userInfo: JitsiMeetUserInfo(displayName: _incomingCallerUserName),
      serverURL: 'https://snarf-meet.inovitech.inf.br',
    );

    jitsiMeet.join(
      options,
      JitsiMeetEventListener(
        conferenceTerminated: (a, a2) {
          setState(() {
            _isInCall = false;
          });
          SignalRManager().sendSignalRMessage(SignalREventType.VideoCallEnd, {
            "RoomId": roomId,
          });
        },
      ),
    );
  }

  void _handleReceiveLocation(Map<String, dynamic> data) {
    final userId = data['userId'];
    final latitude = data['Latitude'];
    final longitude = data['Longitude'];
    final userImage = data['userImage'];

    setState(() {
      _userMarkers[userId] = Marker(
        point: LatLng(latitude, longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _openProfile(userId),
          child: CircleAvatar(
            backgroundImage: NetworkImage(userImage),
          ),
        ),
      );
    });

    log("Localização recebida: $userId - ($latitude, $longitude)");
  }

  void _handleUserDisconnected(Map<String, dynamic> data) {
    final userId = data['userId'];
    setState(() {
      _userMarkers.remove(userId);
    });
    log("Usuário desconectado: $userId");
  }

  Future<void> _sendLocationUpdate() async {
    try {
      await SignalRManager()
          .sendSignalRMessage(SignalREventType.MapUpdateLocation, {
        "Latitude": _currentLocation.latitude,
        "Longitude": _currentLocation.longitude,
      });
    } catch (e) {
      log('Erro ao enviar localização: $e');
    }
  }

  void _recenterMap() {
    if (_isLocationLoaded) {
      _mapController.move(
        LatLng(
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        ),
        15.0,
      );
      log('Mapa recentralizado para localização atual');
    }
  }

  String _getMapUrl(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewUserPage(userId: userId),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const InitialPage(),
              ),
            ),
          ),
        ],
      ),
      body: _isLocationLoaded
          ? Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    onMapReady: () {
                      if (widget.initialLatitude != null &&
                          widget.initialLongitude != null) {
                        _mapController.move(
                          LatLng(
                            widget.initialLatitude!,
                            widget.initialLongitude!,
                          ),
                          15.0,
                        );
                      }
                    },
                    initialCenter: LatLng(
                      _currentLocation.latitude!,
                      _currentLocation.longitude!,
                    ),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(urlTemplate: _getMapUrl(context)),
                    MarkerLayer(
                      markers: [
                        _userLocationMarker,
                        ..._userMarkers.values,
                      ],
                    ),
                  ],
                ),
                if (_isCallOverlayVisible && !_isInCall)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.blueGrey.withOpacity(0.95),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Chamada recebida de $_incomingCallerUserName",
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: _acceptCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text("Aceitar"),
                              ),
                              ElevatedButton(
                                onPressed: _rejectCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text("Recusar"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenterMap,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) async {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivateChatNavigationPage(),
              ),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PublicChatPage(),
              ),
            );
          } else if (index == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditUserPage(),
              ),
            );
            _loadUserInfo();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Privado',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Público',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Meu Perfil',
          ),
        ],
      ),
    );
  }
}
