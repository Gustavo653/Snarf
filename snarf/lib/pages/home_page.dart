import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:snarf/components/toggle_theme_component.dart';
import 'package:snarf/pages/initial_page.dart';
import 'package:snarf/pages/private_chat_list_page.dart';
import 'package:snarf/pages/private_chat_page.dart';
import 'package:snarf/pages/public_chat_page.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/services/signalr_service.dart';
import 'dart:developer';

import 'package:snarf/utils/api_constants.dart';
import 'package:snarf/utils/show_snackbar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late LocationData _currentLocation;
  bool _isLocationLoaded = false;
  late MapController _mapController;
  late Marker _userLocationMarker;
  Map<String, Marker> _userMarkers = {};
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  late SignalRService _signalRService;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _signalRService = SignalRService();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initializeLocation();
    await _setupSignalRConnection();
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
            _currentLocation.latitude!, _currentLocation.longitude!);
      });
      log('Localização atual recuperada: $_currentLocation');
    } catch (err) {
      log('Erro ao recuperar localização: $err');
      showSnackbar(context, "Erro ao recuperar localização: $err");
    }
  }

  void _updateUserMarker(double latitude, double longitude) {
    _userLocationMarker = Marker(
      point: LatLng(latitude, longitude),
      child: const Icon(
        Icons.person_pin_circle_outlined,
        color: Colors.red,
        size: 40,
      ),
    );
  }

  void _startLocationUpdates() {
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 10000);

    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        _currentLocation = newLocation;
        _updateUserMarker(newLocation.latitude!, newLocation.longitude!);
      });
      _sendLocationUpdate();
    });
  }

  Future<void> _setupSignalRConnection() async {
    try {
      log('Iniciando conexão SignalR...');
      await _signalRService.setupConnection(
        hubUrl: '${ApiConstants.baseUrl.replaceAll('/api', '')}/LocationHub',
        onMethods: ['ReceiveLocation', 'UserDisconnected'],
        eventHandlers: {
          'ReceiveLocation': _onReceiveLocation,
          'UserDisconnected': _onUserDisconnected,
        },
      );
      log('Conexão SignalR estabelecida');
    } catch (err) {
      log('Erro ao iniciar conexão SignalR: $err');
      showSnackbar(context, "Erro ao iniciar conexão SignalR: $err");
    }
  }

  void _openPrivateChat(String userId, String userName) {
    log('Abrindo chat privado com usuário $userId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatPage(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  void _onReceiveLocation(List<Object?>? args) {
    try {
      final userId = args?[0] as String;
      final latitude = args?[1] as double;
      final longitude = args?[2] as double;
      final userName = args?[3] as String;

      setState(() {
        _userMarkers[userId] = Marker(
          point: LatLng(latitude, longitude),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () {
              _openPrivateChat(userId, userName);
            },
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: Colors.blue,
              size: 30,
            ),
          ),
        );
      });
      log('Localização de usuário $userId atualizada para [$latitude, $longitude]');
    } catch (e) {
      log('Erro ao receber localização do usuário: $e');
    }
  }

  void _onUserDisconnected(List<Object?>? args) {
    final userId = args?[0] as String;
    log('Usuário desconectado: $userId');
    setState(() {
      _userMarkers.remove(userId);
    });
  }

  Future<void> _sendLocationUpdate() async {
    try {
      await _signalRService.invokeMethod(
        "UpdateLocation",
        [
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        ],
      );
      log('Localização enviada para o servidor');
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

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _signalRService.stopConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          ThemeToggle(),
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
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenterMap,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivateChatListPage(),
              ),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PublicChatPage(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Privado'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Público'),
        ],
      ),
    );
  }
}
