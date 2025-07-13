import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HeartRateRecord {
  final int? id;
  final int bpm;
  final DateTime timestamp;

  HeartRateRecord({
    this.id,
    required this.bpm,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bpm': bpm,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory HeartRateRecord.fromMap(Map<String, dynamic> map) {
    return HeartRateRecord(
      id: map['id'],
      bpm: map['bpm'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'heart_rate.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE heart_rate_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bpm INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertHeartRate(HeartRateRecord record) async {
    final db = await database;
    return await db.insert('heart_rate_records', record.toMap());
  }

  Future<List<HeartRateRecord>> getAllHeartRateRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'heart_rate_records',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HeartRateRecord.fromMap(maps[i]));
  }

  Future<List<HeartRateRecord>> getHeartRateRecordsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final List<Map<String, dynamic>> maps = await db.query(
      'heart_rate_records',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HeartRateRecord.fromMap(maps[i]));
  }

  Future<List<HeartRateRecord>> getHeartRateRecordsForPeriod(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'heart_rate_records',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HeartRateRecord.fromMap(maps[i]));
  }

  Future<void> deleteAllRecords() async {
    final db = await database;
    await db.delete('heart_rate_records');
  }

  Future<List<HeartRateRecord>> exportData() async {
    final records = await getAllHeartRateRecords();
    // This could be extended to export to CSV or other formats
    // For now, we'll just return the data for external processing
    return records;
  }
} 