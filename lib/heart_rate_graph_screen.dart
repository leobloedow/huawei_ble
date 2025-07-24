import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'database_helper.dart';
import 'data_export_helper.dart';

class HeartRateGraphScreen extends StatefulWidget {
  const HeartRateGraphScreen({Key? key}) : super(key: key);

  @override
  State<HeartRateGraphScreen> createState() => _HeartRateGraphScreenState();
}

class _HeartRateGraphScreenState extends State<HeartRateGraphScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<HeartRateRecord> _records = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  int? _currentBpm;
  bool _isUserInteracting = false;

  // Remove time span options, hardcode to 30 minutes
  static const Duration _fixedTimeSpan = Duration(minutes: 30);

  // Statistics
  double _averageBpm = 0;
  int _minBpm = 0;
  int _maxBpm = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
    _getCurrentBpm();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final startTime = now.subtract(_fixedTimeSpan);
    final records = await _databaseHelper.getHeartRateRecordsForPeriod(startTime, now);
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate statistics
    if (records.isNotEmpty) {
      final bpmValues = records.map((r) => r.bpm).toList();
      _averageBpm = bpmValues.reduce((a, b) => a + b) / bpmValues.length;
      _minBpm = bpmValues.reduce((a, b) => a < b ? a : b);
      _maxBpm = bpmValues.reduce((a, b) => a > b ? a : b);
      _totalPoints = records.length;
    }

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  void _getCurrentBpm() async {
    final records = await _databaseHelper.getAllHeartRateRecords();
    if (records.isNotEmpty) {
      final newBpm = records.first.bpm;
      if (_currentBpm != newBpm) {
        setState(() {
          _currentBpm = newBpm;
        });
      }
    }
  }

  void _updateCurrentBpmOnly() async {
    final records = await _databaseHelper.getAllHeartRateRecords();
    if (records.isNotEmpty) {
      final newBpm = records.first.bpm;
      if (_currentBpm != newBpm) {
        print('Updating current BPM from $_currentBpm to $newBpm');
        setState(() {
          _currentBpm = newBpm;
        });
      }
    }
  }

  void _updateDataSilently() async {
    // Don't update graph data if user is interacting with the chart
    if (_isUserInteracting) return;
    
    // Update data without showing loading state
    final now = DateTime.now();
    final startTime = now.subtract(_fixedTimeSpan);

    final records = await _databaseHelper.getHeartRateRecordsForPeriod(startTime, now);
    
    // Sort by timestamp
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Only update if data has changed
    if (_hasDataChanged(records)) {
      _updateStatistics(records);
    }
  }

  void _updateStatistics(List<HeartRateRecord> records) {
    print('Updating statistics with ${records.length} records');
    if (records.isNotEmpty) {
      final bpmValues = records.map((r) => r.bpm).toList();
      final newAverageBpm = bpmValues.reduce((a, b) => a + b) / bpmValues.length;
      final newMinBpm = bpmValues.reduce((a, b) => a < b ? a : b);
      final newMaxBpm = bpmValues.reduce((a, b) => a > b ? a : b);
      final newTotalPoints = records.length;
      
      setState(() {
        _records = records;
        _averageBpm = newAverageBpm;
        _minBpm = newMinBpm;
        _maxBpm = newMaxBpm;
        _totalPoints = newTotalPoints;
        // Don't update _currentBpm here - it's handled separately
      });
    } else {
      setState(() {
        _records = records;
        _averageBpm = 0;
        _minBpm = 0;
        _maxBpm = 0;
        _totalPoints = 0;
        // Don't update _currentBpm here - it's handled separately
      });
    }
  }

  bool _hasDataChanged(List<HeartRateRecord> newRecords) {
    if (_records.length != newRecords.length) return true;
    
    // Check if any records have changed
    for (int i = 0; i < _records.length && i < newRecords.length; i++) {
      if (_records[i].id != newRecords[i].id || 
          _records[i].bpm != newRecords[i].bpm ||
          _records[i].timestamp != newRecords[i].timestamp) {
        return true;
      }
    }
    
    return false;
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _autoRefresh) {
          // Always update current BPM
          _updateCurrentBpmOnly();
          
          // Only update graph data if not interacting
          if (!_isUserInteracting) {
            _updateDataSilently();
          }
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    
    if (_autoRefresh) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  void _resumeUpdates() {
    if (_autoRefresh && !_isUserInteracting) {
      _updateDataSilently();
    }
  }

  List<FlSpot> _getChartData() {
    if (_records.isEmpty) return [];
    
    final spots = <FlSpot>[];
    final startTime = _records.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxPoints = 200;
    final step = (_records.length / maxPoints).ceil();
    for (int i = 0; i < _records.length; i += step) {
      final record = _records[i];
      final x = (record.timestamp.millisecondsSinceEpoch - startTime) / (1000 * 60); // Minutes from start
      final y = record.bpm.toDouble();
      spots.add(FlSpot(x, y));
    }
    // Always include the last point for accuracy
    if (_records.length > 0 && (spots.isEmpty || spots.last.x != (_records.last.timestamp.millisecondsSinceEpoch - startTime) / (1000 * 60))) {
      final record = _records.last;
      final x = (record.timestamp.millisecondsSinceEpoch - startTime) / (1000 * 60);
      final y = record.bpm.toDouble();
      spots.add(FlSpot(x, y));
    }
    return spots;
  }

  String _formatXAxis(double value) {
    if (_records.isEmpty) return '';
    
    final startTime = _records.first.timestamp;
    final time = startTime.add(Duration(minutes: value.round()));
    
    return DateFormat('HH:mm').format(time);
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Graph'),
        actions: [
          IconButton(
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoRefresh,
            tooltip: _autoRefresh ? 'Pause Auto-refresh' : 'Start Auto-refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _updateCurrentBpmOnly();
              _updateDataSilently();
            },
            tooltip: 'Manual Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Current heart rate display
                if (_currentBpm != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getBpmColor(_currentBpm!),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Current Heart Rate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_currentBpm BPM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Remove time span selector, just show stats
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('Avg', '${_averageBpm.round()}'),
                          _buildStatItem('Min', '$_minBpm'),
                          _buildStatItem('Max', '$_maxBpm'),
                          _buildStatItem('Points', '$_totalPoints'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _autoRefresh 
                              ? (_isUserInteracting ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1))
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _autoRefresh 
                                ? (_isUserInteracting ? Colors.orange : Colors.green)
                                : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _autoRefresh 
                                  ? (_isUserInteracting ? Icons.pause : Icons.sync)
                                  : Icons.sync_disabled,
                              size: 16,
                              color: _autoRefresh 
                                  ? (_isUserInteracting ? Colors.orange : Colors.green)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _autoRefresh 
                                  ? (_isUserInteracting ? 'Auto-refresh: PAUSED' : 'Auto-refresh: ON')
                                  : 'Auto-refresh: OFF',
                              style: TextStyle(
                                fontSize: 12,
                                color: _autoRefresh 
                                    ? (_isUserInteracting ? Colors.orange : Colors.green)
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Chart
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _records.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.show_chart, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No heart rate data available',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Start monitoring to see your heart rate graph',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : LineChart(
                            key: ValueKey('chart_30min_${_records.length}'),
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                horizontalInterval: 20,
                                verticalInterval: 2,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.withOpacity(0.3),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 2,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 8,
                                        child: Transform.rotate(
                                          angle: -0.5,
                                          child: Text(
                                            _formatXAxis(value),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 20,
                                    reservedSize: 40,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              minX: 0,
                              maxX: _getChartData().isEmpty ? 0 : _getChartData().last.x,
                              minY: 40,
                              maxY: 220,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _getChartData(),
                                  isCurved: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.withOpacity(0.8),
                                      Colors.orange.withOpacity(0.8),
                                      Colors.green.withOpacity(0.8),
                                    ],
                                  ),
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: _records.length < 50, // Only show dots for smaller datasets
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: _getBpmColor(spot.y.toInt()),
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.red.withOpacity(0.15),
                                        Colors.orange.withOpacity(0.12),
                                        Colors.green.withOpacity(0.10),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                enabled: true,
                                touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                                  if (event is FlPanDownEvent || event is FlTapDownEvent) {
                                    setState(() {
                                      _isUserInteracting = true;
                                    });
                                  } else if (event is FlPanEndEvent || event is FlTapUpEvent) {
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (mounted) {
                                        setState(() {
                                          _isUserInteracting = false;
                                        });
                                      }
                                    });
                                  }
                                },
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipBgColor: Colors.blueGrey.withOpacity(0.9),
                                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                    return touchedBarSpots.map((barSpot) {
                                      final data = _getChartData();
                                      if (data.isNotEmpty) {
                                        int closestIndex = 0;
                                        double minDistance = double.infinity;
                                        for (int i = 0; i < data.length; i++) {
                                          final distance = (data[i].x - barSpot.x).abs();
                                          if (distance < minDistance) {
                                            minDistance = distance;
                                            closestIndex = i;
                                          }
                                        }
                                        if (closestIndex >= 0 && closestIndex < _records.length) {
                                          final record = _records[closestIndex];
                                          return LineTooltipItem(
                                            '${record.bpm} BPM\n${DateFormat('MMM dd, HH:mm').format(record.timestamp)}',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }
                                      }
                                      return null;
                                    }).where((item) => item != null).toList();
                                  },
                                ),
                                handleBuiltInTouches: true,
                              ),
                            ),
                          ),
                  ),
                ),
                
                // Export button
                if (_records.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportChartData,
                        icon: const Icon(Icons.download),
                        label: const Text('Export Data'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }



  void _exportChartData() async {
    try {
      final filePath = await DataExportHelper.exportToCSVFile(_records);
      if (filePath != null) {
        final filename = filePath.split('/').last;
        final directory = filePath.substring(0, filePath.lastIndexOf('/'));
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text('Chart data exported successfully!'),
                const SizedBox(height: 8),
                Text('Time span: ${_fixedTimeSpan.inMinutes} minutes'),
                Text('Data points: $_totalPoints'),
                Text('Filename: $filename'),
                const SizedBox(height: 8),
                Text('Saved to app documents folder'),
                const SizedBox(height: 8),
                Text(
                  'You can access this file through your device\'s file manager in the app\'s documents folder.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed: Permission denied or storage error')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Color _getBpmColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 120) return Colors.orange;
    return Colors.red;
  }
} 