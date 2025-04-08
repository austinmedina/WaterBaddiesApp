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
  bool _isConnecting = false;

  BluetoothDevice? _device;
  Map<String, String> previouslyConnectedDevices = {}; // Initialize as empty
  bool _isLoading = true;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _statusMessageSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  String statusMessage = 'Checking Bluetooth...';
  String connectedMessage = "Not connected to any devices";

  ScrollController scrollCont = ScrollController();

  @override
  void initState() {
    super.initState();

    getConnectedDevice();
    
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

  void getConnectedDevice() {
    final device = Provider.of<WaterBaddiesState>(context, listen: false).device;
    if (device != null) {
      _device = device;
      _isConnected = true;
      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        setState(() {
          if (state == BluetoothConnectionState.disconnected) {
            _isConnected = false;
            Future<String> platformNameFuture = device.platformName == ""
              ? getPlatfromName(device.remoteId.str)
              : Future.value(device.platformName);

          platformNameFuture.then((platformName) {
            setState(() {
              connectedMessage = "Disconnected from $platformName";
            });
          });
          } else if (state == BluetoothConnectionState.connected) {
            setState(() {
              _isConnected = true;
              connectedMessage = "Connected to ${device.platformName}";
            });
          }
        });
      });
    }
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
    if (!_isScanning) {
      try {
          statusMessage = "Scanning";
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

  Future<String> getPlatfromName(String remoteId) async {
    Map<String, String> devices = await getDeviceInfo();

    if (devices.isNotEmpty && devices.containsKey(remoteId)) {
      String name = devices[remoteId] ?? "";
      return name;
    }
    
    return "";

  }

  void connectDevice(BluetoothDevice device) async {
    try {
      setState(() {
        _isConnecting = true;
      });
      await device.connect();
      if (mounted) {
        Provider.of<WaterBaddiesState>(context, listen: false).device = device;
      }

      saveDeviceInfo(device.remoteId.toString(), device.platformName);

      _connectionSubscription = device.connectionState.listen((BluetoothConnectionState state) {
        setState(() {
          if (state == BluetoothConnectionState.disconnected) {
            _isConnected = false;
            Future<String> platformNameFuture = device.platformName == ""
              ? getPlatfromName(device.remoteId.str)
              : Future.value(device.platformName);

          platformNameFuture.then((platformName) {
            setState(() {
              connectedMessage = "Disconnected from $platformName";
            });
          });
          } else if (state == BluetoothConnectionState.connected) {
            setState(() {
              _isConnected = true;
              connectedMessage = "Connected to ${device.platformName}";
            });
          }
        });
      });
      setState(() {
        _device = device;
        _isConnecting = false;
      });
    } catch (e) {
      print("Error connecting: $e");
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void disconnectDevice() async {
    try {
      final BluetoothDevice? localDevice = _device;
      if (localDevice != null) {
        await localDevice.disconnect();
      }

      setState(() {
        _device = null;
        _connectionSubscription?.cancel();
        _connectionSubscription = null;
        _isConnected = false;
        Provider.of<WaterBaddiesState>(context, listen: false).clearSubscriptions();
        Provider.of<WaterBaddiesState>(context, listen: false).device = null;
        checkBluetooth();
      });
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
        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        controller: scrollCont,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xff1E90FF),),
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
              title: FutureBuilder<String>(
                future: _device!.platformName == ""
                    ? getPlatfromName(_device!.remoteId.str)
                    : Future.value(_device!.platformName),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  } else {
                    return Text("Connected to ${snapshot.data}");
                  }
                },
              ),
              subtitle: Text(_device!.remoteId.str),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => disconnectDevice(),
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
                    String name = previouslyConnectedDevices[remoteId]!;

                    
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(remoteId),
                        trailing: _isConnecting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : null,
                        onTap: () {
                          _isConnecting ? null : connectDevice(BluetoothDevice.fromId(remoteId));
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
                            scrollCont.jumpTo(0.0);
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
