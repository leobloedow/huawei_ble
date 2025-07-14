import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import 'package:flutter_background/flutter_background.dart';
import 'database_helper.dart';
import 'heart_rate_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundService();
  runApp(const MyApp());
}

Future<void> initBackgroundService() async {
  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Huawei BLE",
    notificationText: "Receiving heart rate data in the background.",
    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huawei BLE',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BleScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BleScannerScreen extends StatefulWidget {
  const BleScannerScreen({Key? key}) : super(key: key);

  @override
  State<BleScannerScreen> createState() => _BleScannerScreenState();
}

class _BleScannerScreenState extends State<BleScannerScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  StreamSubscription<DiscoveredDevice>? _scanStream;
  final List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  bool _isAutoScanning = false;
  Timer? _autoScanTimer;

  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _heartRateSubscription;

  int? _bpm;
  int _totalRecords = 0;

  void _startScan() async {
    final hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background permissions required')),
        );
      }
      return;
    }

    await FlutterBackground.enableBackgroundExecution();

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _scanStream = _ble
        .scanForDevices(withServices: [])
        .listen(
          (device) {
            // Debug: Print all discovered devices
            print('Discovered device: ${device.name} (${device.id})');
            
            // Check for Huawei Band 10 broadcasting
            if ((device.name.toUpperCase().contains("HUAWEI") || 
                 device.name.toUpperCase().contains("BAND") ||
                 device.name.toUpperCase().contains("HR-27E")) &&
                !_devices.any((d) => d.id == device.id)) {
              
              setState(() {
                _devices.add(device);
                _connectAndListenToHeartRate(device);
              });
            }
          },
          onError: (error) {
            setState(() {
              _isScanning = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scan error: $error')),
              );
            }
          },
          onDone: () {
            setState(() {
              _isScanning = false;
            });
          },
        );

    // For broadcasting, we need continuous scanning
    // Don't stop after 2 seconds
  }

  void _startAutoScan() {
    setState(() {
      _isAutoScanning = true;
    });
    
    // Start immediate scan
    _startScan();
    
    // Set up periodic scanning every 30 seconds
    _autoScanTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isAutoScanning && !_isScanning) {
        _startScan();
      }
    });
  }

  void _stopAutoScan() {
    setState(() {
      _isAutoScanning = false;
    });
    _autoScanTimer?.cancel();
    _stopScan();
  }

  void _stopScan() {
    _scanStream?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  void _disconnect() async {
    await _connectionSubscription?.cancel();
    await _heartRateSubscription?.cancel();
    await FlutterBackground.disableBackgroundExecution();
    _stopAutoScan();
    setState(() {
      _bpm = null;
      _devices.clear();
    });
  }

  Future<void> _loadTotalRecords() async {
    final records = await _databaseHelper.getAllHeartRateRecords();
    setState(() {
      _totalRecords = records.length;
    });
  }

  Future<void> _connectAndListenToHeartRate(DiscoveredDevice device) async {
    print('Connecting to device: ${device.name}');
    
    _connectionSubscription = _ble
        .connectToDevice(id: device.id)
        .listen(
          (connectionState) async {
            print('Connection state: ${connectionState.connectionState}');
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
              print('Connected! Discovering services...');
              
              await _ble.discoverAllServices(device.id);
              final services = await _ble.getDiscoveredServices(device.id);

              final heartRateService = services.firstWhere(
                (service) =>
                    service.id ==
                    Uuid.parse("0000180D-0000-1000-8000-00805f9b34fb"),
                orElse: () => throw Exception('Heart Rate Service not found'),
              );

              final heartRateChar = heartRateService.characteristics.firstWhere(
                (c) =>
                    c.id == Uuid.parse("00002A37-0000-1000-8000-00805f9b34fb"),
                orElse:
                    () =>
                        throw Exception('Heart Rate characteristic not found'),
              );

              final qualifiedChar = QualifiedCharacteristic(
                characteristicId: heartRateChar.id,
                serviceId: heartRateService.id,
                deviceId: device.id,
              );

              _heartRateSubscription = _ble
                  .subscribeToCharacteristic(qualifiedChar)
                  .listen((data) async {
                    print('Heart rate data received: $data');
                    if (data.isNotEmpty && data.length > 1) {
                      final bpm = data[1];
                      print('Extracted BPM: $bpm');
                      
                      setState(() {
                        _bpm = bpm;
                      });
                      
                      // Save heart rate data to database
                      final record = HeartRateRecord(
                        bpm: bpm,
                        timestamp: DateTime.now(),
                      );
                      await _databaseHelper.insertHeartRate(record);
                      await _loadTotalRecords();
                    }
                  });
            } else if (connectionState.connectionState ==
                DeviceConnectionState.disconnected) {
              print('Device disconnected');
              _disconnect();
            }
          },
          onError: (e) {
            print('Connection error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connection error: $e')),
              );
            }
          },
        );
  }

  @override
  void initState() {
    super.initState();
    _loadTotalRecords();
  }

  @override
  void dispose() {
    _scanStream?.cancel();
    _connectionSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _autoScanTimer?.cancel();
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Huawei BLE Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HeartRateHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status and heart rate display
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_bpm != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getBpmColor(_bpm!),
                      borderRadius: BorderRadius.circular(15),
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
                          '$_bpm BPM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusCard(
                      'Records',
                      '$_totalRecords',
                      Icons.favorite,
                      Colors.red,
                    ),
                    _buildStatusCard(
                      'Status',
                      _isAutoScanning ? 'Auto' : 'Manual',
                      _isAutoScanning ? Icons.play_circle : Icons.pause_circle,
                      _isAutoScanning ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAutoScanning ? _stopAutoScan : _startAutoScan,
                    icon: Icon(_isAutoScanning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isAutoScanning ? 'Stop Auto' : 'Start Auto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAutoScanning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    icon: Icon(_isScanning ? Icons.stop : Icons.search),
                    label: Text(_isScanning ? 'Stop Scan' : 'Manual Scan'),
                  ),
                ),
              ],
            ),
          ),
          

          
          const SizedBox(height: 8),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Device list
          Expanded(
            child: _devices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Huawei devices found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start scanning to discover devices',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.watch, color: Colors.blue),
                          title: Text(
                            device.name.isNotEmpty ? device.name : 'Unknown Device',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(device.id),
                          trailing: const Icon(Icons.bluetooth_connected, color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBpmColor(int bpm) {
    if (bpm < 60) return Colors.blue;
    if (bpm < 100) return Colors.green;
    if (bpm < 120) return Colors.orange;
    return Colors.red;
  }
}
