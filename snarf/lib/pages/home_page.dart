import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:location/location.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:snarf/pages/initial_page.dart';
import 'package:snarf/providers/theme_provider.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

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
        child: Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
      );
    });
  }

  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  void _recentralizeMap() {
    if (_isLocationLoaded) {
      _mapController.move(
        LatLng(_currentLocation.latitude!, _currentLocation.longitude!),
        15.0,
      );
    }
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
    );
  }
}

class ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;

  const ActionButton({super.key, this.onPressed, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: Colors.blue,
      elevation: 4,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        color: Colors.white,
      ),
    );
  }
}
