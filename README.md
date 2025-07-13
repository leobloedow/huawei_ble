# Huawei BLE Heart Rate Monitor

A Flutter application that connects to Huawei smartwatches and fitness devices via Bluetooth Low Energy (BLE) to monitor heart rate data in real-time with automatic data storage and analysis capabilities.

## Features

### 🔄 Automatic Updates
- **Auto-scanning**: Automatically scans for Huawei devices every 30 seconds
- **Background operation**: Continues monitoring even when the app is minimized
- **Persistent connection**: Maintains connection to devices for continuous data collection

### 📊 Heart Rate History
- **Comprehensive history screen**: View all recorded heart rate measurements
- **Date and time tracking**: Each measurement includes precise timestamp
- **Filtering options**: View data by time periods (Today, Last 7 Days, Last 30 Days, All Time)
- **Statistics dashboard**: Shows total records, average, min, max BPM, and date range

### 💾 Local Data Storage
- **SQLite database**: All heart rate data is stored locally on the device
- **Persistent storage**: Data survives app restarts and device reboots
- **Automatic saving**: Each heart rate reading is automatically saved with timestamp

### 📈 Data Export for Analysis
- **Multiple export formats**:
  - **CSV**: Compatible with Excel, Google Sheets, and data analysis software
  - **JSON**: For programming and API integration
  - **TXT**: Human-readable format for quick review
- **Complete data export**: Includes timestamps, dates, times, and BPM values
- **Statistics export**: Summary data for quick analysis

### 🎨 Enhanced User Interface
- **Real-time heart rate display**: Large, color-coded BPM display
- **Status indicators**: Shows connection status and auto-scanning state
- **Device management**: List of discovered Huawei devices with connection status
- **Modern design**: Clean, intuitive interface with material design

## Technical Details

### Dependencies
- `flutter_reactive_ble`: BLE communication
- `flutter_background`: Background execution on Android
- `sqflite`: Local database storage
- `intl`: Date/time formatting
- `path_provider`: File system access

### Database Schema
```sql
CREATE TABLE heart_rate_records(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bpm INTEGER NOT NULL,
  timestamp INTEGER NOT NULL
);
```

### BLE Services Used
- **Heart Rate Service**: `0000180D-0000-1000-8000-00805f9b34fb`
- **Heart Rate Measurement**: `00002A37-0000-1000-8000-00805f9b34fb`

### Export Data Format

#### CSV Format
```csv
timestamp,date,time,bpm
1705312225000,2024-01-15,14:30:25,75
1705312226000,2024-01-15,14:30:26,76
```

#### JSON Format
```json
[
  {
    "timestamp": 1705312225000,
    "date": "2024-01-15",
    "time": "14:30:25",
    "bpm": 75
  }
]
```

#### Text Format
```
Heart Rate Data Export
Generated: 2024-01-15 14:30:25
Total Records: 100

Format: Date Time BPM
-------------------
2024-01-15 14:30:25 75
2024-01-15 14:30:26 76
```

## Usage

### Getting Started
1. Launch the app
2. Grant necessary permissions for Bluetooth and background operation
3. Press "Start Auto" to begin automatic device scanning
4. The app will automatically connect to discovered Huawei devices

### Manual Operation
- **Manual Scan**: Use "Manual Scan" button for one-time device discovery
- **Stop Auto**: Disable automatic scanning
- **Disconnect**: Disconnect from all devices and stop background operation

### Viewing History
1. Tap the history icon in the app bar
2. View all recorded heart rate data with timestamps
3. Use filter options to view specific time periods
4. Export data in your preferred format for external analysis

### Data Analysis
The exported data can be used with:
- **Excel/Google Sheets**: For basic analysis and charts
- **Python (pandas, matplotlib)**: For advanced data analysis and visualization
- **R**: For statistical analysis
- **MATLAB**: For signal processing and analysis
- **Any data analysis software**: The CSV format is widely compatible

## Platform Support

- **Android**: Full support with background execution
- **iOS**: Basic BLE functionality (background execution may be limited)
- **Other platforms**: Basic BLE support through Flutter's cross-platform capabilities

## Privacy & Data

- All data is stored locally on your device
- No data is transmitted to external servers
- You have full control over your heart rate data
- Data can be exported and deleted at any time

## Troubleshooting

### Connection Issues
- Ensure your Huawei device is nearby and Bluetooth is enabled
- Check that the device name starts with "HUAWEI"
- Restart the app if connection problems persist

### Background Operation
- On Android, ensure the app has background permissions
- The app will show a persistent notification when running in background
- Battery optimization settings may affect background operation

### Data Export
- Export data regularly to prevent data loss
- Large datasets may take time to export
- Use the appropriate format for your analysis needs

## Development

### Building the App
```bash
flutter pub get
flutter run
```

### Database Location
- **Android**: `/data/data/com.example.ble_app/databases/heart_rate.db`
- **iOS**: App's Documents directory

### Adding New Features
The modular design makes it easy to add new features:
- Add new export formats in `data_export_helper.dart`
- Extend the database schema in `database_helper.dart`
- Add new UI screens following the existing pattern
