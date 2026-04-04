/// Accelerometer reading at a point in time.
class AccelData {
  AccelData({
    required this.timestampMs,
    required this.x,
    required this.y,
    required this.z,
  });

  final int timestampMs;
  final double x;
  final double y;
  final double z;
}
