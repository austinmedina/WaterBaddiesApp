import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import 'screens/bluetooth/bluetoothBar.dart';
// import 'screens/home/barChart.dart';

///The main method that instantiates an instance of the entire app
void main() {
  return runApp(const WaterBaddiesApp());
}

///The [WaterBaddiesApp] itself which is created once upon the [main] running
///The [build] function creates the entire view of the app, everything you see on the screen
///In the build function, a [ChangeNotifierProvider] is used to notify any listeners of the [WaterBaddiesState]
///The first thing you see is the [BaddiesHomePage]
class WaterBaddiesApp extends StatelessWidget {
  const WaterBaddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WaterBaddiesState(),
      child: MaterialApp(
        title: 'Water Baddies App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1E90FF)), 
        ),
        home: BaddiesHomePage(),
      ),
    );
  }
}

///The [WaterBaddiesState] is a general state for the entire app
///The state stores the currently connected [device] which should be the Raspberry Pi
///When the device is initially connected [fetchCharacteristics] is run to get all of the characteristics of the bluetooth service
///In the bluetoth characteristics are the values of each of the baddies (mercury, lead, cadmium, nitrate, phosphate, and microplastics), along with each of their descriptors
///The [subscriptions] map is created which stores listeners who listen for updates in the values on each of the characteristics
class WaterBaddiesState extends ChangeNotifier {
  BluetoothDevice? _device;

  BluetoothDevice? get device => _device;

  set device(BluetoothDevice? newDevice) {
    _device = newDevice;
    if (newDevice != null) { // Only fetch characteristics if newDevice is not null
      createConnectionSubscription();
      fetchCharacteristics(_device!);
      startFetchingCharacteristics();
    }
    notifyListeners();  // Notify listeners when the device is updated
  }

  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  StreamSubscription<BluetoothConnectionState>? get connectionSub => _connectionSub;

  set connectionSub( StreamSubscription<BluetoothConnectionState>? newSub) {
    _connectionSub = newSub;
  }

  String _connectionMessage = "Please Connect a Bluetooth Device";

  String get connectionMessage => _connectionMessage;

  set connectionMessage(String? newMessage) {
    // Check if the newMessage is null, if so, assign a default value.
    _connectionMessage = newMessage ?? "Please Connect a Bluetooth Device";
  }

  void createConnectionSubscription() {
    if (device != null) {
      connectionSub = device!.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectionMessage = "Please Connect a Bluetooth Device";
          device = null;
          notifyListeners();
        } else if (state == BluetoothConnectionState.connected) {
          connectionMessage = "Connected";
          notifyListeners();
        }
      });
    } else {
      connectionMessage = "Please Connect a Bluetooth Device";
    }
  }

  Map<String, double> _characteristicsData = {};

  Map<String, double> get characteristicsData => Map.from(_characteristicsData);

  set characteristicsData(Map<String, double> cd) {
    _characteristicsData = cd;
  }

  String changeKey = "";
  bool newDataAvailable = false;

  Map<BluetoothCharacteristic, StreamSubscription<List<int>>> subscriptions = {};
  List<BluetoothCharacteristic> characteristics = [];
  List<dynamic> readingSubs = [];

  void clearSubscriptions() {
    subscriptions.forEach((characteristic, subscription) {
      subscription.cancel();
    });
    subscriptions = {};
    notifyListeners();
    connectionSub?.cancel();
    connectionSub = null;
    connectionMessage = "Please Connect a Bluetooth Device";
    characteristicsData = {};
  }

  void fetchCharacteristics(BluetoothDevice device) async {
    if (_device == null) throw Exception("Bluetooth device not set.");

    final targetServiceUuid = "00000001-710e-4a5b-8d75-3e5b444bc3cf";

    final targetCharacteristics = [
      "00000002-110e-4a5b-8d75-3e5b444bc3cf", //Microplastic
      "00000002-210e-4a5b-8d75-3e5b444bc3cf", //Lead
      "00000002-310e-4a5b-8d75-3e5b444bc3cf", //Cadmium
      "00000002-410e-4a5b-8d75-3e5b444bc3cf", //Mercury
      "00000002-510e-4a5b-8d75-3e5b444bc3cf", //Phosphate
      "00000002-610e-4a5b-8d75-3e5b444bc3cf", //Nitrate
      "00000002-710e-4a5b-8d75-3e5b444bc3cf", //ChangeKey
    ];

    try {
      final services = await device.discoverServices();

      final service = services.where((s) => s.uuid.toString() == targetServiceUuid).firstOrNull;

      if (service != null) {
        for (final characteristic in service.characteristics) {
          if (targetCharacteristics.contains(characteristic.uuid.toString())) {
            characteristics.add(characteristic);
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
    }
  }

  void fetchNewData() async {
    for (final characteristic in characteristics) {
      try{
        final charValue = await characteristic.read();
        final charValueString = String.fromCharCodes(charValue);
        final charValueDouble = double.tryParse(charValueString) ?? 0.0;

        for (final descriptor in characteristic.descriptors) {
          if (descriptor.uuid.toString().toUpperCase() == "2901") {
            final descValue = await descriptor.read();
            if (descValue.isNotEmpty && !descValue.every((v) => v == 0)) {
              final descString = String.fromCharCodes(descValue);
              _characteristicsData[descString] = charValueDouble;
            }
          }
        }
      } catch(e){
        print("Error reading characteristic: $e");
      }
    }
  }

  void didKeyChange() async {
    for (final characteristic in characteristics) {
      if (characteristic.uuid.toString() == "00000002-710e-4a5b-8d75-3e5b444bc3cf") {
        try{
          final charValue = await characteristic.read();
          final charValueString = String.fromCharCodes(charValue);
          if (changeKey != charValueString) {
            newDataAvailable = true;
            changeKey = charValueString;
          }

        } catch(e){
          print("Error reading characteristic: $e");
        }
      }
    }
  }

  Timer? _fetchTimer;

  void startFetchingCharacteristics() {
    _fetchTimer?.cancel(); // Cancel any existing timer
    _fetchTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      didKeyChange();
      if (newDataAvailable) {
        fetchNewData();
      }
      notifyListeners();

    });
  }

  void stopFetchingCharacteristics() {
    _fetchTimer?.cancel();
  }

  @override
  void dispose() {
    connectionSub?.cancel();
    stopFetchingCharacteristics();
    super.dispose();
  }
}


///The [BaddiesHomePage] is the first thing the user sees upon loading the app. It is able to be reactive because of the [_BaddiesHomePageState]
class BaddiesHomePage extends StatefulWidget {
  @override
  State<BaddiesHomePage> createState() => _BaddiesHomePageState();
}

///The [build] function in the [_BaddiesHomePageState] is what finally creates the first visable entity in the app
///The current [page] is stored as a variable so we can change the page using a [NavigationBar]
///The [currentPageIndex] is set to the index of the currently selected NavigationDestination
///The page is consisted of an appBar which appears at the top of the screen
///On the top right of the screen is the drawer, instantiated as a [BluetoothBar]
///On the bottom of the screen is the [NavigationBar] which is used to change pages
///In the body is the current [page] that is being displayed
class _BaddiesHomePageState extends State<BaddiesHomePage> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (currentPageIndex) {
      case 0:
        page = WaterBaddiesInfo();
      case 1:
        page = History();
      case 2:
        page = About();
      default:
        throw UnimplementedError('no widget for $currentPageIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          drawer: BluetoothBar(),
          appBar: AppBar(
            title: Text('Water Baddies'),
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(  
                  icon: const Icon(Icons.bluetooth),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                );
              },
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          bottomNavigationBar: NavigationBar(
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: currentPageIndex,
            onDestinationSelected: (int index) {
              setState(() {
                currentPageIndex = index;
              });
            },
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.info_outline),
                label: 'About',
              ),
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

///[WaterBaddiesInfo] is one of the pages in the body of the [BaddiesHomePage]
///It creates the [_WaterBaddiesInfoState] which displays data on our baddies, and charts of the current data from the raspberry pi
class WaterBaddiesInfo extends StatefulWidget {
  const WaterBaddiesInfo({super.key});

  @override
  State<WaterBaddiesInfo> createState() => _WaterBaddiesInfoState();
}

class _WaterBaddiesInfoState extends State<WaterBaddiesInfo> {
  Map<String, double> _displayedData = {};
  WaterBaddiesState wbState = WaterBaddiesState();
  final FlutterTts flutterTts = FlutterTts();

  late final BooleanWrapper showMetalChart;
  late final BooleanWrapper showInorganicsChart;
  late final BooleanWrapper showPlasticChart;
  late final BooleanWrapper showMetalInfo;
  late final BooleanWrapper showInorganicsInfo;
  late final BooleanWrapper showPlasticInfo;

  @override
  void initState() {
    super.initState();
    wbState = context.read<WaterBaddiesState>();
    showMetalChart = BooleanWrapper(false);
    showInorganicsChart = BooleanWrapper(false);
    showPlasticChart = BooleanWrapper(false);
    showMetalInfo = BooleanWrapper(false);
    showInorganicsInfo = BooleanWrapper(false);
    showPlasticInfo = BooleanWrapper(false);
    _initTts();
  }

  _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.5);
  }

  Future _speak(String text) async {
    await flutterTts.speak(text);
  }

  Future<Map<String, double>> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition();
    return {
      "Latitude": position.latitude,
      "Longitude": position.longitude,
    };
  }

  List<String> _getHealthy(Map<String, double> newData) {
    //This function provides warning messages for which materials were above their EPA approved threasholds
    //todo: Update the newData to fetch more specific than 'Inorganics' and 'Metals'
    List<String> warningMessages = [];

    if (newData.containsKey('Microplastic') && newData['Microplastic']! > maxQuantities['Microplastic']!) {
      warningMessages.add("Microplastic");
    }
    if (newData.containsKey('Lead') && newData['Lead']! > maxQuantities['Lead']!) {
      warningMessages.add("Lead");
    }
    if (newData.containsKey('Cadmium') && newData['Cadmium']! > maxQuantities['Cadmium']!) {
      warningMessages.add("Cadmium");
    }
    if (newData.containsKey('Mercury') && newData['Mercury']! > maxQuantities['Mercury']!) {
      warningMessages.add("Mercury");
    }
    if (newData.containsKey('Phosphate') && newData['Phosphate']! > maxQuantities['Phosphate']!) {
      warningMessages.add("Phosphate");
    }
    if (newData.containsKey('Nitrate') && newData['Nitrate']! > maxQuantities['Nitrate']!) {
      warningMessages.add("Nitrate");
    }
    if (newData.containsKey('Phosphate') && newData['Phosphate']! > maxQuantities['Phosphate']!) {
      warningMessages.add("High Phosphate Levels");
    }
    return warningMessages;
  }

  Future<void> addHistory(Map<String, double?> newData) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> historyInfo = [];

    // Retrieve any previously saved data
    if (prefs.containsKey('history')) {
      String? savedData = prefs.getString('history');
      if (savedData != null) {
        historyInfo = List<Map<String, dynamic>>.from(jsonDecode(savedData));
      }
    }

    Map<String, dynamic> newEntry = {
      "Date": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()).toString(),
    };

    if (newData.containsKey("Lead") && newData["Lead"] != null) {
      newEntry["Lead"] = newData["Lead"];
    }
    if (newData.containsKey("Cadmium") && newData["Cadmium"] != null) {
      newEntry["Cadmium"] = newData["Cadmium"];
    }
    if (newData.containsKey("Mercury") && newData["Mercury"] != null) {
      newEntry["Mercury"] = newData["Mercury"];
    }
    if (newData.containsKey("Phosphate") && newData["Phosphate"] != null) {
      newEntry["Phosphate"] = newData["Phosphate"];
    }
    if (newData.containsKey("Nitrate") && newData["Nitrate"] != null) {
      newEntry["Nitrate"] = newData["Nitrate"];
    }
    if (newData.containsKey("Microplastic") && newData["Microplastic"] != null) {
      newEntry["Microplastic"] = newData["Microplastic"];
    }

    newEntry["Location"] = await _getLocation();
    newEntry["Healthy"] = _getHealthy(newData.cast<String, double>()); //cast back to double for _getHealthy()

    historyInfo.add(newEntry);

    await prefs.setString('history', jsonEncode(historyInfo));
  }

  List<String> _checkData(Map<String, double> newData) {
    List<String> warningMessages = [];
    newData.forEach((key, value) {
      double? max = maxQuantities[key];

      if (max != null && value > max) {
        warningMessages.add("High Levels of $key");
      }
    });

    return warningMessages;
  }

  // Map<String, double> generateRandomData() {
  //   final Random random = Random(); // Create a Random object

  //   // Generate random numbers between 120.00 and 150.00
  //   double generateRandomValue() {
  //     return 120.00 + random.nextDouble() * (150.00 - 120.00);
  //   }

  //   Map<String, double> _characteristicsData = {};

  //   _characteristicsData['Lead'] = generateRandomValue();
  //   _characteristicsData['Cadmium'] = generateRandomValue();
  //   _characteristicsData['Mercury'] = generateRandomValue();
  //   _characteristicsData['Phosphate'] = generateRandomValue();
  //   _characteristicsData['Nitrate'] = generateRandomValue();
  //   _characteristicsData['Microplastic'] = generateRandomValue();

  //   return _characteristicsData;
  // }
  
  void _updateDisplayedData(BuildContext context) {
    final newData = wbState.characteristicsData;
    //Map<String, double> newData = generateRandomData();
    wbState.newDataAvailable = true;
    addHistory(newData);
    setState(() {
      List<String> warningMessages = _checkData(newData);
      if (warningMessages.isNotEmpty) {
        _showWarningDialog(context, warningMessages);
        Vibration.vibrate(pattern: [500, 1000, 500, 2000]);
        String fullMessage = warningMessages.join(". ");
        _speak(fullMessage);
      }
      _displayedData = Map.from(newData);
      wbState.newDataAvailable = false;
    });
  }

  void _showWarningDialog(BuildContext context, List<String> messages) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('WARNING!'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages.map((message) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(message),
              )).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!,
      textAlign: TextAlign.left,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Selector<WaterBaddiesState, String?>(
              selector: (context, state) => state.connectionMessage,
              builder: (context, connectionMessage, child) {
                return Padding(padding: const EdgeInsets.all(8.0),
                  child: Text(connectionMessage ?? "",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30.0),
                    )
                );
              },
            ),

            Selector<WaterBaddiesState, bool>(
              selector: (context, state) => state.newDataAvailable && state.characteristicsData.isNotEmpty,
              builder: (context, hasNewData, child) {
                if (hasNewData) {
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "New data is available!",
                        style: TextStyle(
                          fontSize: 20, 
                          color: const Color.fromARGB(255, 23, 28, 127),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _updateDisplayedData(context);
                      },
                      child: Text("Fetch New Data"),
                    ),
                  ]);
                } else {
                  return const SizedBox.shrink();
                }
              }
            ),

            Column(
              children: [
              InfoCard(
                key: ValueKey("Metals${_displayedData["Lead"]}${_displayedData["Cadmium"]}${_displayedData["Mercury"]}"),
                showChart: showMetalChart,
                showInfo: showMetalInfo,
                cardTitle: "Metals",
                barChartData: _displayedData.isEmpty
                    ? []
                    : [
                      if (_displayedData.containsKey("Cadmium"))
                        {
                          'name': 'Cadmium',
                          'maxQuantity': maxQuantities['Cadmium'],
                          'quantity': _displayedData["Cadmium"],
                        },
                      if (_displayedData.containsKey("Mercury"))
                        {
                          'name': 'Mercury',
                          'maxQuantity': maxQuantities['Mercury'],
                          'quantity': _displayedData["Mercury"],
                        },
                      if (_displayedData.containsKey("Lead"))
                        {
                          'name': 'Lead',
                          'maxQuantity': maxQuantities['Lead'],
                          'quantity': _displayedData["Lead"],
                        },
                    ].where((element) => element.isNotEmpty).toList(), content: [], imagePath: '',
              ),
              InfoCard(
                key: ValueKey("Inorganics${_displayedData["Phosphate"]}${_displayedData["Nitrate"]}"), 
                showChart: showInorganicsChart,
                showInfo: showInorganicsInfo,
                cardTitle: "Inorganics",
                barChartData: _displayedData.isEmpty
                    ? []
                    : [
                        if (_displayedData.containsKey("Phosphate"))
                          {
                            'name': 'Phosphate',
                            'maxQuantity': maxQuantities['Phosphate'],
                            'quantity': _displayedData["Phosphate"],
                          },
                        if (_displayedData.containsKey("Nitrate"))
                          {
                            'name': 'Nitrates',
                            'maxQuantity': maxQuantities['Nitrate'],
                            'quantity': _displayedData["Nitrate"],
                          },
                          if (_displayedData.containsKey("Phosphate"))
                          {
                            'name': 'Phosphates',
                            'maxQuantity': maxQuantities['Phosphate'],
                            'quantity': _displayedData["Phosphate"],
                          },
                      ].where((element) => element.isNotEmpty).toList(), content: [], imagePath: '',
              ),
              InfoCard(
                key: ValueKey("Microplastics${_displayedData["Microplastic"]}"),
                showChart: showPlasticChart,
                showInfo: showPlasticInfo,
                cardTitle: "Microplastics",
                barChartData: _displayedData.isEmpty
                    ? []
                    : _displayedData.containsKey("Microplastic")
                        ? [
                            {
                              'name': 'Microplastics',
                              'maxQuantity': maxQuantities['Microplastic'],
                              'quantity': _displayedData["Microplastic"]
                            }
                          ]
                        : [], content: [], imagePath: '', // Return empty list if key is missing
              ),
            ]
          )
          ]
        )
      )
    );
  }
}

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {

  @override
  void initState() {
    super.initState();
    history = fetchHistory();
  }

  late Future<List<Map<String, dynamic>>> history;

  Future<void> createPDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final concentrations = {
      'Mercury': data['Mercury'] ?? 0.0,
      'Lead': data['Lead'] ?? 0.0,
      'Cadmium': data['Cadmium'] ?? 0.0,
      'Nitrate': data['Nitrate'] ?? 0.0,
      'Phosphate': data['Phosphate'] ?? 0.0,
      'Microplastics': data['Microplastic'] ?? 0.0,
    };

    const epaLimits = {
      'Mercury': 0.002,
      'Lead': 0.015,
      'Cadmium': 0.005,
      'Nitrate': 10.0,
      'Phosphate': 1.0,
      'Microplastics': 0.0,
    };

    final date = data['Date'] ?? 'Unknown Date';
    final longitude = data['Location']['Longitude'] ?? 'Unknown';
    final latitude = data['Location']['Latitude'] ?? 'Unknown';

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Water Baddies Concentration',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$date : $longitude, $latitude',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Contaminant',
                'Concentration (mg/L)',
                'Max Allowed (mg/L)',
                'Status'
              ],
              data: concentrations.entries.map((entry) {
                final epaLimit = epaLimits[entry.key] ?? 0.0;
                final bool hasValue = entry.value != null && entry.value != 0.0;
                final concentration =
                    hasValue ? entry.value.toStringAsFixed(3) : 'No Value';
                final status = hasValue
                    ? (entry.value > epaLimit ? 'Exceeded' : 'Safe')
                    : 'Safe';

                return [
                  entry.key,
                  concentration,
                  epaLimit.toStringAsFixed(3),
                  status
                ];
              }).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      ),
    );

    
    final bytes = await pdf.save();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/WaterBaddiesConcentration.pdf');

    File savedFile = await file.writeAsBytes(bytes);

    await OpenFile.open(savedFile.path);

  }

  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('history');
    
    if (savedData != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(savedData));
    }
    return [];
  }

  Widget _buildKeyValueRow(String key, Map<String, dynamic> data) {
    dynamic value = data[key]; // Try to get the value
    String displayValue = "No Value";

    if (value != null) {
      if(key == "Location"){
        displayValue = "${value['Latitude']}, ${value['Longitude']}";
      } else {
        displayValue = value.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(displayValue),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center (
      child: FutureBuilder(
      future: history, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(); // Show loading indicator
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}'); // Handle errors
        } else if (snapshot.hasData) {
          final data = snapshot.data;
          if (data == null) {
            return Text('Error: History is null');
          } else if (data.isEmpty) {
            return Text('No history found.');
          } else {
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ExpansionTile(
                    title: (data[index].containsKey('Date') 
                    ? Text(data[index]['Date']) 
                    : const Text("No Date")),
                    subtitle: Text("High levels of: ${data[index]['Healthy'].join(', ')}"),
                    children: [
                      _buildKeyValueRow('Lead', data[index]),
                      _buildKeyValueRow('Cadmium', data[index]),
                      _buildKeyValueRow('Mercury', data[index]),
                      _buildKeyValueRow('Nitrate', data[index]),
                      _buildKeyValueRow('Phosphate', data[index]),
                      _buildKeyValueRow('Microplastic', data[index]),
                      _buildKeyValueRow('Location', data[index]),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await createPDF(data[index]);
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(content: Text('PDF generated successfully'))
                          // );
                        },
                        child: Text('Generate PDF'),
                      ),
                    ],
                    ),
                );
              },
            );
          }
        }
        return Container();
      }
      )
    );
  }
}

class InfoCard extends StatefulWidget {
  const InfoCard({
    super.key,
    required this.showChart,
    required this.showInfo,
    required this.cardTitle,
    required this.barChartData,
    this.content = const [],
    this.imagePath = '',
  });

  final BooleanWrapper showChart;
  final BooleanWrapper showInfo;
  final String cardTitle;
  final List<Map<String, dynamic>> barChartData;
  final List<Map<String, dynamic>> content;
  final String imagePath;

  @override
  State<InfoCard> createState() => InfoCardState();
}

class InfoCardState extends State<InfoCard> {
  bool _showMoreInfo = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.info),
            title: Text(widget.cardTitle),
            //subtitle: Text("More Information"),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              widget.barChartData.isEmpty
                  ? TextButton(
                      child: Text("No Data"),
                      onPressed: () {},
                    )
                  : TextButton(
                      child: Text("View Chart"),
                      onPressed: () {
                        setState(() {
                          widget.showChart.value = !widget.showChart.value;
                        });
                      },
                    ),
              SizedBox(width: 8),
              TextButton(
                child: Text("More Information"),
                onPressed: () {
                  setState(() {
                    _showMoreInfo = !_showMoreInfo;
                  });
                },
              )
            ],
          ),
          if (widget.showInfo.value) _buildInfoContent(),
          if (_showMoreInfo) _buildMoreInfoContent(),
        ],
      ),
    );
  }

  Widget _buildInfoContent() {
    final List<Map<String, dynamic>> contentData = widget.content;
    return Column(
      children: [
        Image.asset(widget.imagePath, fit: BoxFit.contain),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            widget.cardTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentData.map((item) {
            switch (item["type"]) {
              case "section":
                return _buildSectionTitle(item["text"]);
              case "subsection":
                return _buildSubSectionTitle(item["text"]);
              case "text":
                return _buildText(item["text"]);
              default:
                return SizedBox.shrink();
            }
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoreInfoContent() {
    if (widget.cardTitle == "Metals") {
      return HeavyMetalsInfo();
    } else if (widget.cardTitle == "Inorganics") {
      return InorganicsInfo();
    } else if (widget.cardTitle == "Microplastics") {
      return MicroplasticsInfo();
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        softWrap: true,
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, left: 16),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        softWrap: true,
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 16),
      child: Text(
        text,
        softWrap: true,
      ),
    );
  }
}

class HeavyMetalsInfo extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _HeavyMetalsInfoState createState() => _HeavyMetalsInfoState();
}

class _HeavyMetalsInfoState extends State<HeavyMetalsInfo> {
  String? selectedMetal;

  final Map<String, String> metalInfo = {
    'Lead': "EPA Standard: 5.0 mg/L \nLead exposure can cause neurological damage, especially in children. Sources include old lead-based paint, industrial emissions, and contaminated water pipes.",
    'Cadmium': "EPA Standard: 1.0 mg/L\nCadmium exposure is linked to kidney damage and lung disease. It is commonly deposited in water systems through in groundwater contamination, pesticides, industrial waste.",
    'Mercury': "EPA Standard: 0.2 mg/L\nMercury exposure can affect the nervous system, especially in unborn babies and young children. It is commonly found in certain fish and industrial emissions.",
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          ClipOval(
            child: Image.asset(
              "images/HeavyMetals.jpg",
              width: 300,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 10),

          // Always Visible Buttons
          Wrap(
            spacing: 10.0, // Space between buttons
            children: metalInfo.keys.map((metal) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedMetal = (selectedMetal == metal) ? null : metal;
                  });
                },
                child: Text(
                  metal,
                  style: TextStyle(fontSize: 16), // Set font size here
                ),
              );
             }).toList(),
            ),
          SizedBox(height: 10),

          // Selected metal information in card
          if (selectedMetal != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xffAFDBF5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
    
              Text(
                    selectedMetal!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    metalInfo[selectedMetal!]!,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
             ),
SizedBox(height: 10),

          // Background Information Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff6CB4EE),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
            ),
            
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Heavy Metals", Colors.black),
                _buildText(
                    "Heavy metals are naturally ocurring and generally toxic to humans, they can deposit into water systems through household plumbing through runoff from mining operations, petroleum refineries, cement or electronics manufacturures, and waste disposal operations.\nHumans can be detrimentally affected by increased exposure to heavy metals. Heavy metals bioaccumulate in the body over time, meaning they are not easily excreted and can cause long-term health damage. Chronic exposure can lead to organ failure, neurological disorders, and increased cancer risk. Heavy metal contamination is a serious global issue, and staying informed can help minimize health risks",
                    Colors.black),
                            ],
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom:6.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildText(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 16, height: 1.5),
      ),
    );
  }
}



class InorganicsInfo extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _InorganicssInfoState createState() => _InorganicssInfoState();
}

class _InorganicssInfoState extends State<InorganicsInfo> {
  String? selectedInorganic;


  final Map<String, String> inorganicsInfo = {
    'Nitrates': "EPA Standards: 10g/ml.\nNitrates are relatively less toxic than nitrites. They origincate from fertilizers, natural soil decomposition, and wastewater.",
    'Nitrites': "EPA Standards: 1g/ml.\nNitrites are more reactive and can interfere with oxygen transport in the blood. Nitrite exposure may contribute to high blood pressure and vascular damage, increasing the risk of heart disease and stroke They originate from industrial waster, bacterial breakdown, and food preservatives.",
    'Phosphates': "Phosphorus is commonly found in agricultural fertilizers, manure, and organic waste from sewage and industrial effluent. While it is essential for plant growth, excessive phosphorus in water can accelerate eutrophication which is a process where increased mineral and organic nutrients reduce dissolved oxygen levels in rivers and lakes."
  };
  @override
  Widget build(BuildContext context) {
     return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: SizedBox.fromSize(
              size: const Size.fromRadius(150),
              child: Image.asset(
                "images/Inorganics2.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 10),

          // Always Visible Buttons
          Wrap(
            spacing: 10.0, // Space between buttons
            children: inorganicsInfo.keys.map((inorganic) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedInorganic = (selectedInorganic == inorganic) ? null : inorganic;
                  });
                },
                child: Text(inorganic,
                  style: TextStyle(fontSize: 16), // Set font size here
                ),
              );
             }).toList(),
            ),
             
  
          SizedBox(height: 10),
//details in boxes
if (selectedInorganic != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xffAFDBF5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedInorganic!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    inorganicsInfo[selectedInorganic!]!,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),

          SizedBox(height: 10),

          // Background information (Always Visible)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff6CB4EE),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
            ),
            
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          _buildSectionTitle("Inorganics"),
          _buildText("Nitrite and nitrate ions are a part of the earth’s nitrogen cycle, they naturally occur in the soil and water environments. These inorganics are also released through human made products like fertilizers, waste water treatment facilities’ runoff."),
          _buildText("Excessive nitrate consumption can interfere with the blood’s ability to carry oxygen, leading to methemoglobinemia, also known as blue baby syndrome. Bottle-fed infants under six months old are most vulnerable to this condition, which can cause serious illness or even death. Recent scientific studies suggest that long-term exposure to nitrate in drinking water, even at levels below the current regulatory standard, may be linked to thyroid disorders, adverse pregnancy outcomes, and certain cancers, particularly colorectal cancer. Further research is needed to confirm these findings."),
          
         ], ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        softWrap: true,
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16),
        softWrap: true,
      ),
    );
  }
}

 class MicroplasticsInfo extends StatelessWidget {
   get imagePath => "images/Water Baddies.jpg";


  @override
  
  Widget build(BuildContext context) {
 return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        ClipOval(
  child: SizedBox.fromSize(
    size: const Size.fromRadius(144),
    child: Image.network(
      imagePath,
      fit: BoxFit.cover,
    ),
  ),
),
    SizedBox(height: 20),

    // Background information (Always Visible)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff6CB4EE),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
            ),
            
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          _buildSectionTitle("Microplastics"),
         _buildText("Microplastics are tiny plastic particles (less than 5mm in size) that contaminate drinking water through industrial waste, plastic pollution, and the breakdown of larger plastics. These particles have been found in tap water, bottled water, and even the air we breathe, raising concerns about their long-term health effects."),
          _buildText("Since microplastics can degrade to microscopic sizes, they  can penetrate human cells, causing inflammation, oxidative stress, and DNA damage. Microplastics can act as carriers rather than catalysts and they can contain endocrine-disrupting chemicals (EDCs), which can interfere with hormone regulation."),
          _buildText("Microplastics absorb and transport harmful pollutants, such as pesticides, heavy metals, and industrial chemicals, into the human body. These contaminants may increase the risk of neurotoxicity, liver damage, and immune system dysfunction."),
          _buildText("Since microplastics are invisible to the naked eye and cannot be easily filtered out by standard water treatment processes, reducing plastic waste and using advanced filtration methods may help minimize exposure."),
         ]
          ),
            ),
        ]
        
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        softWrap: true,
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 16),
        softWrap: true,
      ),
    );
  }
}

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}


