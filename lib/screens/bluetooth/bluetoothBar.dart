import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import '../../main.dart' show WaterBaddiesState;

class BluetoothBar extends StatefulWidget {

  @override
  State<BluetoothBar> createState() => _BluetoothBarState();
}

class _BluetoothBarState extends State<BluetoothBar> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isConnected = false;

  BluetoothDevice? _device;
  Map<String, String> previouslyConnectedDevices = {}; // Initialize as empty
  bool _isLoading = true;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _statusMessageSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  String statusMessage = 'Checking Bluetooth...';
  String connectedMessage = "Not connected to any devices";

  @override
  void initState() {
    super.initState();
    
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });

    _statusMessageSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on || state == BluetoothAdapterState.off) {
        checkBluetooth();
      }
    });

    loadPreviouslyConnectedDevices();

    scanDevices();
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _statusMessageSubscription.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadPreviouslyConnectedDevices() async {
    try {
      previouslyConnectedDevices = await getDeviceInfo();
    } catch (e) {
      print("Error loading saved devices: $e");
      // Handle error, e.g., show a snackbar
    } finally {
      setState(() {
        _isLoading = false; // Set loading to false after completion
      });
    }
  }

  Future<void> checkBluetooth() async {
    try {
      if (!_isConnected) {
        bool supported = await FlutterBluePlus.isSupported;
        setState(() {
          if (supported) {
            BluetoothAdapterState state = FlutterBluePlus.adapterStateNow;
            if (state == BluetoothAdapterState.on) {
              statusMessage = 'Ready to Connect';
            } else {
              statusMessage = 'Bluetooth is off, please turn it on';
            }
          } else {
            statusMessage = 'This device does not support Bluetooth';
          }
        });
      } else {
        setState(() {
          statusMessage = 'Connected';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error checking Bluetooth: ${e.toString()}';
      });
    }
  }

  Future<void> scanDevices() async {
    setState (() {
      _isConnected = false;
    });
    if (!_isScanning) {
      try {
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), androidScanMode: AndroidScanMode(1));
      } catch (e) {
          print('Error starting scan: $e');
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> saveDeviceInfo(String remoteId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> deviceInfo = {};
    
    // Retrieve any previously saved data
    if (prefs.containsKey('devices')) {
      String? savedData = prefs.getString('devices');
      if (savedData != null) {
        deviceInfo = Map<String, String>.from(jsonDecode(savedData));
      }
    }
    
    // Add or update the remoteId and name pair
    if (name != '') {
      deviceInfo[remoteId] = name;
    }

    // Save updated map back as a JSON string
    await prefs.setString('devices', jsonEncode(deviceInfo));
  }

  // Retrieve all saved devices' remoteId and name
  Future<Map<String, String>> getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('devices');
    
    if (savedData != null) {
      return Map<String, String>.from(jsonDecode(savedData));
    }
    return {};
  }

  void connectDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      if (mounted) {
        Provider.of<WaterBaddiesState>(context, listen: false).device = device;
      }

      saveDeviceInfo(device.remoteId.toString(), device.platformName);

      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        setState(() {
          if (state == BluetoothConnectionState.disconnected) {
            _isConnected = false;
            connectedMessage = "Disconnected from ${device.platformName}";
          } else if (state == BluetoothConnectionState.connected) {
            _isConnected = true;
            connectedMessage = "Connected to ${device.platformName}";
          }
        });
      });
      setState(() {
        _device = device;
      });
    } catch (e) {
      print("Error connecting: $e");
    }
  }

  void disconnectDevice(BluetoothDevice? device) async {
  try {
    await device?.disconnect();
    _device = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null; 
  } catch (e) {
    print("Error disconnecting: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _isLoading // Show a loading indicator while data is loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              children: [
                Text(
                  'Bluetooth Connection',
                  style: TextStyle(color: Colors.white, fontSize: 25),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isScanning ? Icons.stop : Icons.start, 
                      color: _isScanning ? Colors.red : Colors.white),
                      onPressed: _isScanning ? stopScan : scanDevices,
                    ),
                  ],
                ),
              ],
            ),
          ),
          (_isConnected && (_device != null))
            ? ListTile(
                title: Text("Connected to ${_device!.platformName}"),
                subtitle: Text(_device!.remoteId.str),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => disconnectDevice(_device),
                  ),
              )
            : ListTile(
                title: Text(statusMessage),
                subtitle: Text(connectedMessage),
              ),
              if (previouslyConnectedDevices.isNotEmpty)
                ListView.builder(
                  itemCount: previouslyConnectedDevices.length,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    // Convert the map into a list of key-value pairs (remoteId, name)
                    String remoteId = previouslyConnectedDevices.keys.elementAt(index);
                    String name = previouslyConnectedDevices[remoteId]!; // Safe access to the value

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(name), // Display the name
                        subtitle: Text(remoteId), // Display the remoteId
                        onTap: () {
                          // You can add your connectDevice logic here if needed
                          connectDevice(BluetoothDevice.fromId(remoteId));
                        },
                      ),
                    );
                  },
                ),
              _scanResults.isEmpty
                ? Center(child: ListTile(title: Text('No devices found')))
                : ListView.builder(
                    itemCount: _scanResults.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final data = _scanResults[index];
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          title: Text(data.device.platformName),
                          subtitle: Text(data.device.remoteId.str),
                          trailing: Text(data.rssi.toString()),
                          onTap: () {
                            connectDevice(data.device);
                          },
                        ),
                      );
                    },
                  ),
            ],
      ),
    );
  }
}
