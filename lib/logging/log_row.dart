import '../gps/gps_data.dart';
import '../obd/obd_collector.dart';
import '../sensor/accel_data.dart';

/// A unified row of data combining OBD, GPS, and accelerometer readings.
class LogRow {
  LogRow({
    required this.timestampMs,
    this.rpm,
    this.speedKmh,
    this.throttlePct,
    this.coolantTempC,
    this.mafGs,
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.gpsSpeedMs,
    this.accelX,
    this.accelY,
    this.accelZ,
  });

  final int timestampMs;
  // OBD
  final double? rpm;
  final double? speedKmh;
  final double? throttlePct;
  final double? coolantTempC;
  final double? mafGs;
  // GPS
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
  final double? gpsSpeedMs;
  // Accelerometer
  final double? accelX;
  final double? accelY;
  final double? accelZ;

  static const csvHeader =
      'timestamp_ms,rpm,speed_kmh,throttle_pct,coolant_c,maf_gs,'
      'lat,lng,alt_m,gps_speed_ms,accel_x,accel_y,accel_z';

  /// Create a LogRow by merging the latest data from each source.
  factory LogRow.merge({
    ObdSnapshot? obd,
    GpsData? gps,
    AccelData? accel,
  }) {
    return LogRow(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      rpm: obd?.rpm,
      speedKmh: obd?.speedKmh,
      throttlePct: obd?.throttlePct,
      coolantTempC: obd?.coolantTempC,
      mafGs: obd?.mafGs,
      latitude: gps?.latitude,
      longitude: gps?.longitude,
      altitudeM: gps?.altitudeM,
      gpsSpeedMs: gps?.speedMs,
      accelX: accel?.x,
      accelY: accel?.y,
      accelZ: accel?.z,
    );
  }

  String toCsvLine() {
    String fmt(double? v) => v != null ? v.toStringAsFixed(4) : '';

    return [
      timestampMs.toString(),
      fmt(rpm),
      fmt(speedKmh),
      fmt(throttlePct),
      fmt(coolantTempC),
      fmt(mafGs),
      fmt(latitude),
      fmt(longitude),
      fmt(altitudeM),
      fmt(gpsSpeedMs),
      fmt(accelX),
      fmt(accelY),
      fmt(accelZ),
    ].join(',');
  }
}
