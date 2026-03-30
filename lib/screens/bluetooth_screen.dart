import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../services/bluetooth_receipt_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  List<BluetoothDevice> _scanResults = [];
  List<BluetoothDevice> _connectedDevices = [];
  BluetoothDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    // Check permissions first
    await _requestPermissions();
    
    // Get initial adapter state
    _adapterState = await FlutterBluePlus.adapterState.first;
    
    // Listen to adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _adapterState = state;
      });
    });

    // Get already connected devices
    _connectedDevices = FlutterBluePlus.connectedDevices;
    setState(() {});
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request permissions for Android 12+ (API 31+)
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse, // Still needed for some devices
      ].request();
      
      print('Bluetooth permissions: $permissions');
      
      // Check if critical permissions are granted
      if (!permissions[Permission.bluetoothScan]!.isGranted) {
        _showError('Bluetooth scan permission is required to find devices');
      }
      if (!permissions[Permission.bluetoothConnect]!.isGranted) {
        _showError('Bluetooth connect permission is required to connect to devices');
      }
    }
  }

  Future<void> _startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      _showError('Please turn on Bluetooth first');
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      // Start scanning for devices
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results.map((r) => r.device).toList();
        });
      });

      // Stop scanning after timeout
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showError('Scan failed: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showLoadingDialog('Connecting to ${device.platformName.isEmpty ? "Device" : device.platformName}...');
      
      await device.connect(timeout: const Duration(seconds: 15));
      
      setState(() {
        _selectedDevice = device;
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
      });

      // Set device for receipt service
      BluetoothReceiptService.setConnectedDevice(device);

      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.platformName.isEmpty ? "Device" : device.platformName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Failed to connect: $e');
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      
      setState(() {
        _connectedDevices.remove(device);
        if (_selectedDevice == device) {
          _selectedDevice = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${device.platformName.isEmpty ? "Device" : device.platformName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError('Failed to disconnect: $e');
    }
  }

  Future<void> _testPrint() async {
    if (_selectedDevice == null) {
      _showError('Please connect to a printer first');
      return;
    }

    try {
      _showLoadingDialog('Sending test print...');
      
      // Use the new BluetoothReceiptService for test printing
      final success = await BluetoothReceiptService.printTestReceipt();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test receipt printed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _showError('❌ Test print failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Print failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bluetooth Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // Connected Devices Section
            if (_connectedDevices.isNotEmpty) _buildConnectedDevicesSection(),
            
            const SizedBox(height: 16),
            
            // Available Devices Section
            _buildAvailableDevicesSection(),
            
            const SizedBox(height: 20),
            
            // Test Print Section
            if (_selectedDevice != null) _buildTestPrintSection(),
          ],
        ),
      ),
      floatingActionButton: _adapterState == BluetoothAdapterState.on
          ? FloatingActionButton(
              onPressed: _isScanning ? null : _startScan,
              backgroundColor: Colors.blue.shade600,
              child: _isScanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.white),
              tooltip: 'Scan for devices',
            )
          : null,
    );
  }

  Widget _buildStatusCard() {
    bool isOn = _adapterState == BluetoothAdapterState.on;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOn ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: isOn ? Colors.blue : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _adapterState.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    color: isOn ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_adapterState == BluetoothAdapterState.off) ...[
              const SizedBox(height: 12),
              Text(
                'Please turn on Bluetooth in your device settings to scan for and connect to printers.',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Devices',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        ..._connectedDevices.map((device) => _buildDeviceCard(device, isConnected: true)),
      ],
    );
  }

  Widget _buildAvailableDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            if (_isScanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_scanResults.isEmpty && !_isScanning)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No devices found. Tap the search button to scan for Bluetooth devices.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ..._scanResults.where((device) => !_connectedDevices.contains(device))
              .map((device) => _buildDeviceCard(device, isConnected: false)),
      ],
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device, {required bool isConnected}) {
    String deviceName = device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';
    return Card(
      color: isConnected ? Colors.green.shade50 : null,
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: isConnected ? Colors.green : Colors.grey.shade600,
        ),
        title: Text(deviceName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.remoteId}'),
            if (isConnected)
              Text(
                'Connected',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: isConnected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDevice == device)
                    Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () => _disconnectDevice(device),
                    color: Colors.red,
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                child: const Text('Connect'),
              ),
      ),
    );
  }

  Widget _buildTestPrintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Printer Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected Printer: ${_selectedDevice!.platformName.isNotEmpty ? _selectedDevice!.platformName : "Unknown Device"}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testPrint,
                    icon: const Icon(Icons.print, size: 24),
                    label: const Text(
                      'Send Test Print',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will send ESC/POS commands to print a test receipt.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}