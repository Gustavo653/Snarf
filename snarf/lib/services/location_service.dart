import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationService {
  final bool usePrecise;

  LocationService({this.usePrecise = false});

  final _controller = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;

  Stream<Position> get onLocationChanged => _controller.stream;

  Future<bool> initialize() async {
    if (!usePrecise) return true;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position> getCurrentLocation() async {
    if (usePrecise) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _controller.add(pos);
      return pos;
    } else {
      final ipRes = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      final ipData = jsonDecode(ipRes.body) as Map<String, dynamic>;
      final ip = ipData['ip'] as String;

      final geoRes = await http.get(
        Uri.parse('http://ip-api.com/json/$ip'),
      );
      final data = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final lat = (data['lat'] as num).toDouble();
      final lon = (data['lon'] as num).toDouble();

      final fakePos = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 50,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      _controller.add(fakePos);
      return fakePos;
    }
  }

  void startUpdates({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int intervalMs = 20000,
  }) {
    if (usePrecise) {
      _subscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 10,
          timeLimit: Duration(milliseconds: intervalMs),
        ),
      ).listen(_controller.add);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
