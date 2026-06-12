import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationUtils {
  static Future<String?> getCurrentLocation() async {
    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission =
          await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever)
        return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Try reverse geocoding to get a real address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];

          if (place.subThoroughfare != null &&
              place.subThoroughfare!.isNotEmpty)
            parts.add(place.subThoroughfare!);
          if (place.thoroughfare != null &&
              place.thoroughfare!.isNotEmpty)
            parts.add(place.thoroughfare!);
          if (place.locality != null &&
              place.locality!.isNotEmpty)
            parts.add(place.locality!);
          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty)
            parts.add(place.administrativeArea!);

          if (parts.isNotEmpty) return parts.join(', ');
        }
      } catch (_) {
        // Geocoding failed — fall back to coordinates
      }

      // Fallback to raw coordinates
      return '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';
    } catch (e) {
      return null;
    }
  }

  static String formatLocation(String? location) {
    return location ?? 'No location';
  }
}