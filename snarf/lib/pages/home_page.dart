import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
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

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _setupSignalRConnection();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _currentLocation = await location.getLocation();
    setState(() {
      _isLocationLoaded = true;
      _userLocationMarker = Marker(
        point: LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
      );
    });

    _sendLocationUpdate();
  }

  void _sendLocationUpdate() async {
    if (_hubConnection.state == HubConnectionState.Connected) {
      await _hubConnection.invoke(
        "UpdateLocation",
        args: [
          _currentLocation.latitude!,
          _currentLocation.longitude!,
        ],
      );
    }
  }

  void _setupSignalRConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl('${ApiConstants.baseUrl.replaceAll('/api', '')}/locationHub')
        .build();

    _hubConnection.on("ReceiveLocation", (args) {
      log('Evento ReceiveLocation recebido');
      final connectionId = args?[0] as String;
      final latitude = args?[1] as double;
      final longitude = args?[2] as double;
      setState(() {
        _userMarkers[connectionId] = Marker(
          point: LatLng(latitude, longitude),
          width: 30,
          height: 30,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 30,
          ),
        );
      });
    });

    _hubConnection.on("UserDisconnected", (args) {
      log('Evento UserDisconnected recebido');
      final connectionId = args?[0] as String;
      setState(() {
        _userMarkers.remove(connectionId);
      });
    });

    _hubConnection.start()?.catchError((err) {
      log("Erro ao iniciar a conexão SignalR: $err");
    });
  }

  void _recentralizeMap() {
    if (_isLocationLoaded) {
      _getCurrentLocation();
      _mapController.move(
        LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
        15.0,
      );
    }
  }

  String _getMapUrl(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    if (isDarkMode) {
      return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    } else {
      return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    }
  }

  void _navigateToPrivateChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abrindo bate-papo privado...')),
    );
  }

  void _navigateToPublicChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abrindo bate-papo público...')),
    );
  }

  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  @override
  void dispose() {
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
            onPressed: () => _toggleTheme(context),
          ),
        ],
      ),
      body: Center(
        child: _isLocationLoaded
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
                      TileLayer(
                        urlTemplate: _getMapUrl(context),
                      ),
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
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recentralizeMap,
        child: const Icon(Icons.my_location),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (int index) {
          if (index == 0) {
            _navigateToPrivateChat(context);
          } else if (index == 1) {
            _navigateToPublicChat(context);
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
        ],
      ),
    );
  }
}
