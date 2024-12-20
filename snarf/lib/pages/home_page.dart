import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/pages/public_chat_page.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/utils/api_constants.dart';
import 'dart:developer';

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
  late HubConnection _hubConnection;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _connectionId;
  Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeApp();
  }

  /// Inicializa os serviços principais
  Future<void> _initializeApp() async {
    await _initializeLocation();
    _setupSignalRConnection();
  }

  /// Mostra uma SnackBar com uma mensagem
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Centraliza o controle de permissões e localização
  Future<void> _initializeLocation() async {
    if (await _checkLocationPermissions()) {
      _getCurrentLocation();
      _startLocationUpdates();
    }
  }

  /// Verifica e solicita permissões de localização
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

  /// Obtém a localização atual do usuário
  Future<void> _getCurrentLocation() async {
    _currentLocation = await _location.getLocation();
    setState(() {
      _isLocationLoaded = true;
      _updateUserMarker(_currentLocation.latitude!, _currentLocation.longitude!);
    });
  }

  /// Atualiza o marcador do usuário no mapa
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

  /// Inicia o acompanhamento de localização em tempo real
  void _startLocationUpdates() {
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 10000);

    _locationSubscription = _location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        _currentLocation = newLocation;
        _updateUserMarker(newLocation.latitude!, newLocation.longitude!);
      });
      _sendLocationUpdate();
    });
  }

  /// Configura a conexão com o SignalR
  Future<void> _setupSignalRConnection() async {
    _connectionId = await _secureStorage.read(key: 'connectionId');

    _hubConnection = HubConnectionBuilder()
        .withUrl('${ApiConstants.baseUrl.replaceAll('/api', '')}/LocationHub')
        .build();

    _hubConnection.on("ReceiveLocation", _onReceiveLocation);
    _hubConnection.on("UserDisconnected", _onUserDisconnected);

    try {
      await _hubConnection.start();
      if (_connectionId != null) {
        await _hubConnection.invoke("RegisterConnectionId", args: [_connectionId!]);
      }
      _connectionId = _hubConnection.connectionId;
      await _secureStorage.write(key: 'connectionId', value: _connectionId);

      _showSnackBar("Conectado com connectionId: $_connectionId");
    } catch (err) {
      _showSnackBar("Erro ao iniciar conexão SignalR: $err");
    }
  }

  /// Callback para o evento ReceiveLocation
  void _onReceiveLocation(List<Object?>? args) {
    final connectionId = args?[0] as String;
    final latitude = args?[1] as double;
    final longitude = args?[2] as double;
    _showSnackBar("Localização recebida: $connectionId $latitude $longitude");
    setState(() {
      _userMarkers[connectionId] = Marker(
        point: LatLng(latitude, longitude),
        width: 30,
        height: 30,
        child: const Icon(
          Icons.person_pin_circle_outlined,
          color: Colors.blue,
          size: 30,
        ),
      );
    });
  }

  /// Callback para o evento UserDisconnected
  void _onUserDisconnected(List<Object?>? args) {
    final connectionId = args?[0] as String;
    log('Usuário desconectado: $connectionId');
    setState(() {
      _userMarkers.remove(connectionId);
    });
  }

  /// Envia a localização atualizada para o servidor
  Future<void> _sendLocationUpdate() async {
    if (_hubConnection.state == HubConnectionState.Connected) {
      await _hubConnection.invoke(
        "UpdateLocation",
        args: [_currentLocation.latitude!, _currentLocation.longitude!],
      );
    }
  }

  /// Recentraliza o mapa na localização atual
  void _recenterMap() {
    if (_isLocationLoaded) {
      _mapController.move(
        LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
        15.0,
      );
    }
  }

  /// Retorna a URL do mapa baseada no tema
  String _getMapUrl(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _hubConnection.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
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
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenterMap,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          if (index == 0) {
            _showSnackBar('Abrindo bate-papo privado...');
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PublicChatPage()),
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