import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'heart_rate_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  String? _savedDeviceId;
  String? _savedDeviceName;
  int _totalRecords = 0;
  final TextEditingController _deviceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTotalRecords();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceId = prefs.getString('saved_device_id');
      _savedDeviceName = prefs.getString('saved_device_name');
      _deviceIdController.text = prefs.getString('device_id') ?? '';
    });
  }

  Future<void> _loadTotalRecords() async {
    final records = await _databaseHelper.getAllHeartRateRecords();
    setState(() {
      _totalRecords = records.length;
    });
  }

  Future<void> _saveDevice(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_device_id', deviceId);
    await prefs.setString('saved_device_name', deviceName);
    setState(() {
      _savedDeviceId = deviceId;
      _savedDeviceName = deviceName;
    });
  }

  Future<void> _saveDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', id);
    setState(() {
      _savedDeviceId = id;
    });
  }

  Future<void> _removeSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_device_id');
    await prefs.remove('saved_device_name');
    setState(() {
      _savedDeviceId = null;
      _savedDeviceName = null;
    });
  }

  Future<void> _showResetDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will permanently delete all heart rate data, history, and settings. '
          'This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetAllData();
    }
  }

  Future<void> _resetAllData() async {
    try {
      // Clear database
      await _databaseHelper.clearAllData();
      
      // Remove saved device
      await _removeSavedDevice();
      
      // Update UI
      await _loadTotalRecords();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Device Management Section
          _buildSectionHeader('Device Management'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'Enter a unique ID for this device',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _saveDeviceId(value),
            ),
          ),
          _buildListTile(
            icon: Icons.bluetooth,
            title: 'Saved Device',
            subtitle: _savedDeviceName ?? 'No device saved',
            trailing: _savedDeviceId != null
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _removeSavedDevice,
                    tooltip: 'Remove saved device',
                  )
                : null,
          ),
          
          const Divider(),
          
          // Data Management Section
          _buildSectionHeader('Data Management'),
          _buildListTile(
            icon: Icons.history,
            title: 'Heart Rate History',
            subtitle: '$_totalRecords records',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HeartRateHistoryScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.delete_forever,
            title: 'Reset All Data',
            subtitle: 'Delete all heart rate data and settings',
            onTap: _showResetDataDialog,
            textColor: Colors.red,
          ),
          
          const Divider(),
          
          // App Information Section
          _buildSectionHeader('App Information'),
          _buildListTile(
            icon: Icons.info,
            title: 'Version',
            subtitle: '1.0.0',
          ),
          _buildListTile(
            icon: Icons.description,
            title: 'About',
            subtitle: 'Huawei BLE Heart Rate Monitor',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.blue),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: textColor?.withOpacity(0.7) ?? Colors.grey[600],
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
} 