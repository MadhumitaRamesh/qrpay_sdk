class LocationFix {
  final double lat;
  final double lon;
  final double accuracy;
  final double altitude;
  final DateTime timestamp;

  LocationFix({
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.altitude,
    required this.timestamp,
  });
}
