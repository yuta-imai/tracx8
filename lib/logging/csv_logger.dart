import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'log_row.dart';

/// Writes LogRow data to timestamped CSV files.
class CsvLogger extends ChangeNotifier {
  IOSink? _sink;
  File? _currentFile;
  int _rowCount = 0;

  bool get isLogging => _sink != null;
  String? get currentFilePath => _currentFile?.path;
  int get rowCount => _rowCount;

  /// Start a new logging session. Creates a new CSV file.
  Future<void> startSession() async {
    await stopSession();

    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/tracx8_$timestamp.csv');

    _currentFile = file;
    _sink = file.openWrite(mode: FileMode.append);
    _sink!.writeln(LogRow.csvHeader);
    _rowCount = 0;

    debugPrint('CsvLogger: started → ${file.path}');
    notifyListeners();
  }

  /// Write a log row.
  void log(LogRow row) {
    _sink?.writeln(row.toCsvLine());
    _rowCount++;
    // Notify periodically to avoid excessive UI updates
    if (_rowCount % 10 == 0) {
      notifyListeners();
    }
  }

  /// Stop the current session and close the file.
  Future<void> stopSession() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    debugPrint('CsvLogger: stopped → ${_currentFile?.path}');
    notifyListeners();
  }

  @override
  void dispose() {
    _sink?.flush();
    _sink?.close();
    super.dispose();
  }
}
