import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../model/location_fix.dart';

class LocationState {
  static final StreamController<void> _permanentlyDeniedController = StreamController<void>.broadcast();
  static Stream<void> get permanentlyDeniedStream => _permanentlyDeniedController.stream;

  static LocationFix? _cachedFix;

  static Future<LocationFix?> getCurrentOrCached(Duration maxAge) async {
    if (_cachedFix != null) {
      final age = DateTime.now().difference(_cachedFix!.timestamp);
      if (age <= maxAge) {
        return _cachedFix;
      }
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _permanentlyDeniedController.add(null);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)
      );
      
      _cachedFix = LocationFix(
        lat: position.latitude,
        lon: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        timestamp: position.timestamp,
      );
      
      return _cachedFix;
    } catch (e) {
      return null;
    }
  }

  static void stopUpdates() {
    // Geolocator getCurrentPosition resolves a single future, but if we had a stream we'd cancel it here.
    // For now, this just updates the flag for the platform channel hook.
  }
}
