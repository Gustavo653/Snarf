import 'dart:async';
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  final _controller = StreamController<LocationData>.broadcast();
  StreamSubscription<LocationData>? _subscription;

  Stream<LocationData> get onLocationChanged => _controller.stream;

  Future<bool> initialize() async {
    if (!await _location.serviceEnabled()) {
      if (!await _location.requestService()) {
        return false;
      }
    }
    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  Future<LocationData> getCurrentLocation() async {
    final loc = await _location.getLocation();
    _controller.add(loc);
    return loc;
  }

  void startUpdates({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int interval = 20000,
  }) {
    _location.changeSettings(accuracy: accuracy, interval: interval);
    _subscription = _location.onLocationChanged.listen(_controller.add);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
