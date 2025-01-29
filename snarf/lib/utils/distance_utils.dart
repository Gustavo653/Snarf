import 'dart:math';

class DistanceUtils {
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    double deg2rad(double deg) => deg * (pi / 180);

    const R = 6371.0;
    double dLat = deg2rad(lat2 - lat1);
    double dLon = deg2rad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(deg2rad(lat1)) *
            cos(deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = R * c;
    return distance;
  }
}
