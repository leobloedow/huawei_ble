import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
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
  late Stream<DiscoveredDevice> _scanStream;
  final List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;

  late StreamSubscription<ConnectionStateUpdate> _connectionSubscription;
  late StreamSubscription<List<int>> _heartRateSubscription;

  int? _bpm;

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _scanStream = _ble.scanForDevices(withServices: []);
    _scanStream.listen(
      (device) {
        if (device.name.startsWith("HUAWEI") &&
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan error: $error')));
      },
      onDone: () {
        setState(() {
          _isScanning = false;
        });
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      _stopScan();
    });
  }

  void _stopScan() {
    _scanStream.drain();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectAndListenToHeartRate(DiscoveredDevice device) async {
    _connectionSubscription = _ble
        .connectToDevice(id: device.id)
        .listen(
          (connectionState) async {
            if (connectionState.connectionState ==
                DeviceConnectionState.connected) {
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
                  .listen((data) {
                    final bpm = data[1];
                    setState(() {
                      _bpm = bpm;
                    });
                  });
            }
          },
          onError: (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
          },
        );
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    _heartRateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Freq. Huawei')),
      body: Column(
        children: [
          if (_bpm != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _bpm != null ? 'FC: $_bpm bpm' : 'Disp. desconectado',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ElevatedButton(
            onPressed: _isScanning ? _stopScan : _startScan,
            child: Text("Atualizar"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(
                    device.name.isNotEmpty ? "Disp: ${device.name}" : 'Unknown',
                  ),
                  subtitle: Text(device.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
