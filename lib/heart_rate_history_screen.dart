import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'data_export_helper.dart';

class HeartRateHistoryScreen extends StatefulWidget {
  const HeartRateHistoryScreen({Key? key}) : super(key: key);

  @override
  State<HeartRateHistoryScreen> createState() => _HeartRateHistoryScreenState();
}

class _HeartRateHistoryScreenState extends State<HeartRateHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<HeartRateRecord> _records = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _filterType = 'all'; // 'all', 'today', 'week', 'month'
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    List<HeartRateRecord> records;
    switch (_filterType) {
      case 'today':
        records = await _databaseHelper.getHeartRateRecordsForDate(_selectedDate);
        break;
      case 'week':
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        records = await _databaseHelper.getHeartRateRecordsForPeriod(weekAgo, DateTime.now());
        break;
      case 'month':
        final monthAgo = DateTime.now().subtract(const Duration(days: 30));
        records = await _databaseHelper.getHeartRateRecordsForPeriod(monthAgo, DateTime.now());
        break;
      default:
        records = await _databaseHelper.getAllHeartRateRecords();
    }

    final statistics = await DataExportHelper.getStatistics(records);
    
    setState(() {
      _records = records;
      _statistics = statistics;
      _isLoading = false;
    });
  }

  Future<void> _exportData() async {
    try {
      final records = await _databaseHelper.exportData();
      _showExportOptionsDialog(records);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showExportOptionsDialog(List<HeartRateRecord> records) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total records: ${records.length}'),
            const SizedBox(height: 16),
            const Text('Choose export format:'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV Format'),
              subtitle: const Text('Compatible with Excel, Google Sheets'),
              onTap: () {
                Navigator.of(context).pop();
                _exportToCSV(records);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON Format'),
              subtitle: const Text('For programming analysis'),
              onTap: () {
                Navigator.of(context).pop();
                _exportToJSON(records);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text Format'),
              subtitle: const Text('Human readable format'),
              onTap: () {
                Navigator.of(context).pop();
                _exportToTXT(records);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportToCSV(List<HeartRateRecord> records) async {
    try {
      final csvData = await DataExportHelper.exportToCSV(records);
      _showExportResult('CSV Export', csvData, 'heart_rate_data.csv');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    }
  }

  void _exportToJSON(List<HeartRateRecord> records) async {
    try {
      final jsonData = await DataExportHelper.exportToJSON(records);
      _showExportResult('JSON Export', jsonData, 'heart_rate_data.json');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON export failed: $e')),
      );
    }
  }

  void _exportToTXT(List<HeartRateRecord> records) async {
    try {
      final txtData = await DataExportHelper.exportToTXT(records);
      _showExportResult('Text Export', txtData, 'heart_rate_data.txt');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text export failed: $e')),
      );
    }
  }

  void _showExportResult(String title, String data, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filename: $filename'),
            const SizedBox(height: 8),
            const Text('Data preview (first 200 characters):'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data.length > 200 ? '${data.substring(0, 200)}...' : data,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('Total characters: ${data.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all heart rate records? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseHelper.deleteAllRecords();
      _loadRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate History'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filterType = value;
              });
              _loadRecords();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Time'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Text('Last 7 Days'),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Text('Last 30 Days'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.filter_list),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportData();
              } else if (value == 'clear') {
                _clearAllData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Text('Export Data'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear All Data'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No heart rate data available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Statistics cards
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Total Records',
                                  '${_statistics['total_records'] ?? 0}',
                                  Icons.favorite,
                                  Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Average BPM',
                                  '${_statistics['average_bpm'] ?? 0}',
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Min BPM',
                                  '${_statistics['min_bpm'] ?? 0}',
                                  Icons.keyboard_arrow_down,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Max BPM',
                                  '${_statistics['max_bpm'] ?? 0}',
                                  Icons.keyboard_arrow_up,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          if (_statistics['date_range'] != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Date Range: ${_statistics['date_range']}',
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          final dateFormat = DateFormat('MMM dd, yyyy');
                          final timeFormat = DateFormat('HH:mm:ss');
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getBpmColor(record.bpm),
                                child: Text(
                                  record.bpm.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${record.bpm} BPM',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dateFormat.format(record.timestamp)),
                                  Text(timeFormat.format(record.timestamp)),
                                ],
                              ),
                              trailing: Icon(
                                _getBpmIcon(record.bpm),
                                color: _getBpmColor(record.bpm),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Color _getBpmColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 120) return Colors.orange;
    return Colors.red;
  }

  IconData _getBpmIcon(int bpm) {
    if (bpm < 60) return Icons.favorite_border;
    if (bpm < 100) return Icons.favorite;
    if (bpm < 120) return Icons.favorite;
    return Icons.favorite;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 