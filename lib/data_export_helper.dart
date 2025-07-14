import 'package:intl/intl.dart';
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
} 