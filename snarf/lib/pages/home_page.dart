import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:snarf/providers/theme_provider.dart';
import 'package:snarf/utils/api_constants.dart';

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
  List<Marker> _otherUserMarkers = [];
  late HubConnection _hubConnection;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _setupSignalR();
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

  void _setupSignalR() {
    // Criação da conexão SignalR com o Hub
    _hubConnection = HubConnectionBuilder()
        .withUrl(
            '${ApiConstants.baseUrl.replaceAll('/api', '')}/locationHub') // URL do seu SignalR Hub
        .build();

    // Ouve por atualizações de localização de outros usuários
    _hubConnection.on("ReceiveLocation", (args) {
      final latitude = args?[0] as double;
      final longitude = args?[1] as double;
      setState(() {
        // Adiciona a localização recebida à lista de marcadores de outros usuários
        _otherUserMarkers.add(Marker(
          point: LatLng(latitude, longitude),
          width: 30,
          height: 30,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 30,
          ),
        ));
      });
    });

    _hubConnection.start()?.catchError((err) {
      print("Erro ao iniciar a conexão SignalR: $err");
    });
  }

  void _sendLocationUpdate() async {
    // Envia a localização atualizada para o Hub SignalR
    if (_hubConnection.state == HubConnectionState.Connected) {
      await _hubConnection.invoke("UpdateLocation",
          args: [_currentLocation.latitude!, _currentLocation.longitude!]);
    }
  }

  void _recentralizeMap() {
    if (_isLocationLoaded) {
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
                          ..._otherUserMarkers,
                          // Adiciona os marcadores dos outros usuários
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
