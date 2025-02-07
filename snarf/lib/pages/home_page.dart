import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import 'package:snarf/pages/account/edit_user_page.dart';
import 'package:snarf/pages/account/initial_page.dart';
import 'package:snarf/pages/account/view_user_page.dart';
import 'package:snarf/pages/privateChat/private_chat_navigation_page.dart';
import 'package:snarf/pages/privateChat/private_chat_page.dart';
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
  final Map<String, Marker> _userMarkers = {};
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  late String userImage = '';
  double _opacity = 0.0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeApp();
    _startOpacityAnimation();
  }

  void _startOpacityAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _opacity = _opacity == 0.0 ? 1.0 : 0.0;
      });
    });
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
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green,
                width: 4.0,
              ),
            ),
            child: CircleAvatar(
              backgroundImage: NetworkImage(userImage),
              radius: 25,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setupSignalRConnection() async {
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

        default:
          log("Evento não reconhecido: ${message['Type']}");
      }
    } catch (e) {
      log("Erro ao processar mensagem SignalR: $e");
    }
  }

  void _handleReceiveLocation(Map<String, dynamic> data) {
    final userId = data['userId'];
    final latitude = data['Latitude'];
    final longitude = data['Longitude'];
    final userImage = data['userImage'];

    setState(() {
      _userMarkers[userId] = Marker(
        point: LatLng(latitude, longitude),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _openProfile(userId),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green,
                    width: 4.0,
                  ),
                ),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(userImage),
                  radius: 25,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
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

  void _openPrivateChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: 50),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                border: const Border.symmetric(
                  horizontal: BorderSide(
                    color: Color(0xFF392ea3),
                    width: 5,
                  ),
                ),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.9,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                      bottom: Radius.circular(30),
                    ),
                    child: Scaffold(
                      body: PrivateChatNavigationPage(
                          scrollController: scrollController),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPublicChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(left: 50),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                border: const Border.symmetric(
                  horizontal: BorderSide(
                    color: Color(0xFF392ea3),
                    width: 5,
                  ),
                ),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.9,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                      bottom: Radius.circular(30),
                    ),
                    child: Scaffold(
                      body: PublicChatPage(scrollController: scrollController),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RawMaterialButton(
        onPressed: onPressed,
        shape: const CircleBorder(),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: const EdgeInsets.all(8),
        fillColor: Colors.transparent,
        splashColor: Colors.transparent,
        elevation: 0,
        child: Icon(icon,
            color: Provider.of<ThemeProvider>(context).isDarkMode
                ? Colors.white
                : Colors.black,
            size: 24),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Provider.of<ThemeProvider>(context).isDarkMode
                  ? Image.asset(
                      'assets/images/logo-black.png',
                      height: 20,
                    )
                  : Image.asset(
                      'assets/images/logo-white.png',
                      height: 20,
                    ),
            ],
          ),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              log("Botão de menu pressionado");
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditUserPage(),
                  ),
                );
                _loadUserInfo();
              },
            ),
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
                        Future.delayed(Duration(milliseconds: 500), () {
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
                        });
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
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on),
                        Text('Carregando Conteúdo')
                      ],
                    ),
                    AnimatedOpacity(
                      duration: Duration(seconds: 2),
                      opacity: _opacity,
                      child: Image.asset(
                        'assets/images/small-logo-black.png',
                        width: 30,
                      ),
                    )
                  ],
                ),
              ),
        floatingActionButton: Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingButton(Icons.flight, () {
                log("Botão avião pressionado");
              }),
              _buildFloatingButton(Icons.remove_red_eye, () {
                log("Botão olho pressionado");
              }),
              _buildFloatingButton(Icons.crop_free, () {
                log("Botão moldura pressionada");
              }),
              _buildFloatingButton(Icons.my_location, _recenterMap),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (index) async {
            if (index == 0) {
              _openPrivateChat(context);
            } else if (index == 1) {
              _openPublicChat(context);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
