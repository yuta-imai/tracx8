import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../logging/log_row.dart';
import 'api_client.dart';

/// Upload state visible to the UI.
enum UploadState { idle, uploading, error }

/// Buffers LogRows and sends them in batches to the backend.
/// Handles retry on transient failures.
class DataUploader extends ChangeNotifier {
  static const int _batchSize = 30;
  static const Duration _flushInterval = Duration(seconds: 5);
  static const int _maxRetries = 3;

  ApiClient? _apiClient;

  String? _sessionId;
  String? get sessionId => _sessionId;

  UploadState _state = UploadState.idle;
  UploadState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  int _uploadedCount = 0;
  int get uploadedCount => _uploadedCount;

  int get pendingCount => _buffer.length;

  final Queue<LogRow> _buffer = Queue<LogRow>();
  Timer? _flushTimer;
  bool _active = false;

  /// Create a remote session and start the upload loop.
  /// [backendUrl] is the base URL of the Tracx8 backend.
  /// [deviceId] identifies this device.
  Future<void> startSession({
    required String backendUrl,
    required String deviceId,
  }) async {
    _apiClient?.dispose();
    _apiClient = ApiClient(baseUrl: backendUrl);

    try {
      final response = await _apiClient!.createSession(deviceId);
      _sessionId = response.sessionId;
      _active = true;
      _uploadedCount = 0;
      _lastError = null;
      _state = UploadState.idle;

      // Periodic flush for partial batches
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());

      debugPrint('DataUploader: session started → $_sessionId');
      notifyListeners();
    } catch (e) {
      _state = UploadState.error;
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Enqueue a row for upload. Triggers flush if batch size reached.
  void enqueue(LogRow row) {
    if (!_active || _sessionId == null) return;
    _buffer.add(row);

    if (_buffer.length >= _batchSize) {
      _flush();
    }
  }

  /// Stop uploading and flush remaining data.
  Future<void> stopSession() async {
    _active = false;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Final flush
    if (_buffer.isNotEmpty && _sessionId != null) {
      await _flush();
    }

    _sessionId = null;
    debugPrint('DataUploader: session stopped. Uploaded $_uploadedCount rows.');
    notifyListeners();
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty || _sessionId == null || _apiClient == null) return;

    // Drain the buffer
    final batch = <LogRow>[];
    while (_buffer.isNotEmpty && batch.length < _batchSize) {
      batch.add(_buffer.removeFirst());
    }

    _state = UploadState.uploading;
    notifyListeners();

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _apiClient!.sendRows(_sessionId!, batch);
        _uploadedCount += batch.length;
        _state = UploadState.idle;
        _lastError = null;
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('DataUploader: send failed (attempt $attempt/$_maxRetries): $e');
        if (attempt == _maxRetries) {
          // Put rows back for next attempt
          for (final row in batch.reversed) {
            _buffer.addFirst(row);
          }
          _state = UploadState.error;
          _lastError = e.toString();
          notifyListeners();
        } else {
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _apiClient?.dispose();
    super.dispose();
  }
}
