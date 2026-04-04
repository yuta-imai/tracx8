/// GPS location data point.
class GpsData {
  GpsData({
    required this.timestampMs,
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.speedMs,
    this.bearing,
    this.accuracy,
  });

  final int timestampMs;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? speedMs;
  final double? bearing;
  final double? accuracy;
}
