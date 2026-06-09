import 'package:geolocator/geolocator.dart';

class LocationUtils {
  static Future<String?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}';
    } catch (e) {
      return null;
    }
  }

  /// Convert "lat,lng" string to a readable label
  static String formatLocation(String? location) {
    if (location == null) return 'No location';
    final parts = location.split(',');
    if (parts.length != 2) return location;
    return '${parts[0]}°N, ${parts[1]}°E';
  }
}