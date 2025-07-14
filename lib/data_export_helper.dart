import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';

class DataExportHelper {
  static Future<String> exportToCSV(List<HeartRateRecord> records) async {
    final StringBuffer csv = StringBuffer();
    
    // Add header
    csv.writeln('timestamp,date,time,bpm');
    
    // Add data rows
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    
    for (final record in records) {
      csv.writeln('${record.timestamp.millisecondsSinceEpoch},'
          '${dateFormat.format(record.timestamp)},'
          '${timeFormat.format(record.timestamp)},'
          '${record.bpm}');
    }
    
    return csv.toString();
  }

  static Future<String> exportToJSON(List<HeartRateRecord> records) async {
    final List<Map<String, dynamic>> jsonData = records.map((record) => {
      'timestamp': record.timestamp.millisecondsSinceEpoch,
      'date': DateFormat('yyyy-MM-dd').format(record.timestamp),
      'time': DateFormat('HH:mm:ss').format(record.timestamp),
      'bpm': record.bpm,
    }).toList();
    
    return jsonData.toString();
  }

  static Future<String> exportToTXT(List<HeartRateRecord> records) async {
    final StringBuffer txt = StringBuffer();
    
    txt.writeln('Heart Rate Data Export');
    txt.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    txt.writeln('Total Records: ${records.length}');
    txt.writeln('');
    txt.writeln('Format: Date Time BPM');
    txt.writeln('-------------------');
    
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    
    for (final record in records) {
      txt.writeln('${dateFormat.format(record.timestamp)} '
          '${timeFormat.format(record.timestamp)} '
          '${record.bpm}');
    }
    
    return txt.toString();
  }

  static Future<Map<String, dynamic>> getStatistics(List<HeartRateRecord> records) async {
    if (records.isEmpty) {
      return {
        'total_records': 0,
        'average_bpm': 0,
        'min_bpm': 0,
        'max_bpm': 0,
        'date_range': 'No data',
      };
    }

    final bpmValues = records.map((r) => r.bpm).toList();
    final timestamps = records.map((r) => r.timestamp).toList();
    
    return {
      'total_records': records.length,
      'average_bpm': (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round(),
      'min_bpm': bpmValues.reduce((a, b) => a < b ? a : b),
      'max_bpm': bpmValues.reduce((a, b) => a > b ? a : b),
      'date_range': '${DateFormat('yyyy-MM-dd').format(timestamps.last)} to ${DateFormat('yyyy-MM-dd').format(timestamps.first)}',
    };
  }

  // New methods to actually save files
  static Future<String?> saveToFile(String data, String filename) async {
    try {
      Directory directory;
      
      // Use app documents directory (no special permissions needed)
      directory = await getApplicationDocumentsDirectory();
      
      // Create exports subdirectory
      final exportsDir = Directory('${directory.path}/exports');
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      final file = File('${exportsDir.path}/$filename');
      await file.writeAsString(data);
      
      return file.path;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  static Future<String?> exportToCSVFile(List<HeartRateRecord> records) async {
    final csvData = await exportToCSV(records);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'heart_rate_data_$timestamp.csv';
    return await saveToFile(csvData, filename);
  }

  static Future<String?> exportToJSONFile(List<HeartRateRecord> records) async {
    final jsonData = await exportToJSON(records);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'heart_rate_data_$timestamp.json';
    return await saveToFile(jsonData, filename);
  }

  static Future<String?> exportToTXTFile(List<HeartRateRecord> records) async {
    final txtData = await exportToTXT(records);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'heart_rate_data_$timestamp.txt';
    return await saveToFile(txtData, filename);
  }

  static Future<List<String>> getExportedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${directory.path}/exports');
      
      if (!await exportsDir.exists()) {
        return [];
      }

      final files = exportsDir.listSync()
          .where((entity) => entity is File && 
              entity.path.contains('heart_rate_data_'))
          .map((file) => file.path)
          .toList();
      
      return files;
    } catch (e) {
      return [];
    }
  }
} 