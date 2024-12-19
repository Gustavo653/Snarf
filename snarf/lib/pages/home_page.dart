import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:snarf/providers/theme_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
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
  }

  void _recentralizeMap() {
    if (_isLocationLoaded) {
      _mapController.move(
        LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
        15.0,
      );
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
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          _userLocationMarker,
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
