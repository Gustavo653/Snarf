import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final _controller = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;

  Stream<Position> get onLocationChanged => _controller.stream;

  Future<bool> initialize() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _controller.add(position);
    return position;
  }

  void startUpdates({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int intervalMs = 20000,
  }) {
    _subscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 10,
        timeLimit: Duration(milliseconds: intervalMs),
      ),
    ).listen(_controller.add);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}