import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logging/log_row.dart';

/// Response from POST /api/sessions.
class CreateSessionResponse {
  CreateSessionResponse({required this.sessionId});

  final String sessionId;

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) {
    return CreateSessionResponse(sessionId: json['sessionId'] as String);
  }
}

/// HTTP client for the Tracx8 backend API.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  final http.Client _client = http.Client();

  /// Create a new logging session on the backend.
  Future<CreateSessionResponse> createSession(String deviceId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId}),
    );

    if (response.statusCode != 201) {
      throw ApiException('Failed to create session: ${response.statusCode} ${response.body}');
    }

    return CreateSessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Send a batch of data rows to the backend.
  Future<void> sendRows(String sessionId, List<LogRow> rows) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rows': rows.map(_rowToJson).toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to send data: ${response.statusCode} ${response.body}');
    }
  }

  /// Check backend connectivity.
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _rowToJson(LogRow row) {
    return {
      'timestamp_ms': row.timestampMs,
      if (row.rpm != null) 'rpm': row.rpm,
      if (row.speedKmh != null) 'speed_kmh': row.speedKmh,
      if (row.throttlePct != null) 'throttle_pct': row.throttlePct,
      if (row.coolantTempC != null) 'coolant_c': row.coolantTempC,
      if (row.mafGs != null) 'maf_gs': row.mafGs,
      if (row.latitude != null) 'lat': row.latitude,
      if (row.longitude != null) 'lng': row.longitude,
      if (row.altitudeM != null) 'alt_m': row.altitudeM,
      if (row.gpsSpeedMs != null) 'gps_speed_ms': row.gpsSpeedMs,
      if (row.accelX != null) 'accel_x': row.accelX,
      if (row.accelY != null) 'accel_y': row.accelY,
      if (row.accelZ != null) 'accel_z': row.accelZ,
    };
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
