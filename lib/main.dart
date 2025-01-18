import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'screens/bluetooth/bluetoothBar.dart';
import 'screens/home/barChart.dart';

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 16, 122, 6)),
        ),
        home: BaddiesHomePage(),
      ),
    );
  }
}

///The [WaterBaddiesState] is a general state for the entire app
///The state stores the currently connected [device] which should be the Raspberry Pi
///When the device is initially connected [fetchCharacteristics] is run to get all of the characteristics of the bluetooth service
///In the bluetoth characteristics are the values of each of the baddies (arsenic, lead, cadmium, nitrate, nitrite, and microplastics), along with each of their descriptors
///The [subscriptions] map is created which stores listeners who listen for updates in the values on each of the characteristics
class WaterBaddiesState extends ChangeNotifier {
  BluetoothDevice? _device;

  BluetoothDevice? get device => _device;

  set device(BluetoothDevice? newDevice) {
    if (newDevice == null) throw Exception("Bluetooth device is null.");
    _device = newDevice;
    fetchCharacteristics(_device!);
    notifyListeners();  // Notify listeners when the device is updated
  }

  Map<String, double> _characteristicsData = {};

  Map<String, double> get characteristicsData => Map.from(_characteristicsData);

  Map<BluetoothCharacteristic, StreamSubscription<List<int>>> subscriptions = {};

  void fetchCharacteristics(BluetoothDevice device) async {
    if (_device == null) throw Exception("Bluetooth device not set.");

    final targetServiceUuid = "00000001-710e-4a5b-8d75-3e5b444bc3cf"; // Your service UUID

    // Map of characteristic UUIDs to descriptor UUIDs (and optionally names)
    final targetCharacteristics = {
      "00000002-710e-4a5b-8d75-3e5b444bc3cf": "2901", // Microplastic
      "00000002-810e-4a5b-8d75-3e5b444bc3cf": "2904", // Metal
      "00000002-910e-4a5b-8d75-3e5b444bc3cf": "2903", // Inorganics
    };

    try {
      final services = await device.discoverServices();

      final service = services.where((s) => s.uuid.toString() == targetServiceUuid).firstOrNull;

      if (service != null) {
        for (final characteristic in service.characteristics) {
          final targetDescriptorUuid = targetCharacteristics[characteristic.uuid.toString()];

          if (targetDescriptorUuid != null) { // Only process if a target descriptor is defined
            if (characteristic.properties.read) {
              try{
                final charValue = await characteristic.read();
                final charValueString = String.fromCharCodes(charValue);
                final charValueDouble = double.tryParse(charValueString) ?? 0.0;

                for (final descriptor in characteristic.descriptors) {
                  if (descriptor.uuid.toString().toUpperCase() == targetDescriptorUuid.toUpperCase()) { // Case-insensitive comparison
                    final descValue = await descriptor.read();
                    if (descValue.isNotEmpty && !descValue.every((v) => v == 0)) {
                      final descString = String.fromCharCodes(descValue);
                      _characteristicsData[descString] = charValueDouble;
                    }
                  }
                }

                if (characteristic.properties.notify) {
                  await characteristic.setNotifyValue(true);
                  subscriptions[characteristic] = characteristic.lastValueStream.listen((value) async {
                    final updatedCharValue = String.fromCharCodes(value);
                    final updatedDoubleValue = double.tryParse(updatedCharValue) ?? 0.0;

                    for (final descriptor in characteristic.descriptors) {
                      if (descriptor.uuid.toString().toUpperCase() == targetDescriptorUuid.toUpperCase()) {
                        final descValue = await descriptor.read();
                        if ((descValue as List).isNotEmpty && !(descValue as List).every((v) => v == 0)) {
                          final descString = String.fromCharCodes(descValue);
                          _characteristicsData[descString] = updatedDoubleValue;
                        }
                      }
                    }
                    notifyListeners();
                    print("Notified");
                  });
                }
              }catch(e){
                print("Error reading characteristic: $e");
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
    }
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
        page = Placeholder();
      case 2:
        page = Placeholder();
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
  final DeepCollectionEquality _mapEquality = const DeepCollectionEquality();

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
  }

  Future<Position> _getLocation() async {
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
    return await Geolocator.getCurrentPosition();
  }

  List<String> _getHealthy(Map<String, double> newData) {
    //This function provides warning messages for which materials were above their EPA approved threasholds
    //todo: Update the newData to fetch more specific than 'Inorganics' and 'Metals'
    List<String> warningMessages = [];

    if (newData.containsKey('Microplastics') && newData['Microplastics']! > maxQuantities['Microplastics']!) {
      warningMessages.add("High Microplastic Levels");
    }

    if (newData.containsKey('Inorganics')) {
      if (newData['Inorganics']! > maxQuantities['Nitrites']!) {
        warningMessages.add("High Nitrites Levels");
      }
      if (newData['Inorganics']! > maxQuantities['Nitrates']!) {
        warningMessages.add("High Nitrate Levels");
      }
    }

    if (newData.containsKey('Metals')) {
      if (newData['Metals']! > maxQuantities['Cadmium']!) {
        warningMessages.add("High Cadmium Levels");
      }
      if (newData['Metals']! > maxQuantities['Arsenic']!) {
        warningMessages.add("High Arsenic Levels");
      }
      if (newData['Metals']! > maxQuantities['Lead']!) {
        warningMessages.add("High Lead Levels");
      }
    }

    return warningMessages;
  }

  void addHistory(Map<String, double> newData) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> historyInfo = [];
    
    // Retrieve any previously saved data
    if (prefs.containsKey('history')) {
      String? savedData = prefs.getString('history');
      if (savedData != null) {
        historyInfo = List<Map<String, dynamic>>.from(jsonDecode(savedData));
      }
    }

    historyInfo.add(
      {
      "date": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()).toString(),
      "lead": newData["Metal Concentration"],
      "cadmium": newData["Metal Concentration"],
      "arsenic": newData["Metal Concentration"],
      "nitrate": newData["Inorganics Concentration"],
      "nitrite": newData["Inorganics Concentration"],
      "microplastics": newData["Microplastic Concentration"],
      "location": _getLocation(),
      "healthy": _getHealthy(newData)
      }
    );

    await prefs.setString('history', jsonEncode(historyInfo));
  }

  void _updateDisplayedData() {
    final newData = wbState.characteristicsData;
    if (!_mapEquality.equals(_displayedData, newData)) { 
      addHistory(newData);
      setState(() {
        _displayedData = Map.from(newData);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!,
      textAlign: TextAlign.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Selector<WaterBaddiesState, BluetoothDevice?>(
              selector: (context, state) => state.device,
              builder: (context, device, child) {
                return Text(device != null ? "Connected" : "Please Connect a Bluetooth Device");
              },
            ),

            Selector<WaterBaddiesState, bool>(
              selector: (context, state) => !_mapEquality.equals(state.characteristicsData, _displayedData) && state.characteristicsData.isNotEmpty,
              builder: (context, hasNewData, child) {
                if (hasNewData) {
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "New data is available!",
                        style: TextStyle(
                          fontSize: 16, 
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _updateDisplayedData,
                      child: Text("Fetch New Data"),
                    ),
                  ]);
                } else if (_displayedData.isEmpty) {
                  return Column(
                    children: [
                      Text("No Data Available"),  
                    ]
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('You have ${_displayedData.keys.length} characteristics:'),
            ),
            Column(
              children: [
              InfoCard(
                key: ValueKey("Metals${_displayedData["Metal Concentration"]}"),
                showChart: showMetalChart,
                showInfo: showMetalInfo,
                cardTitle: "Metals",
                barChartData: _displayedData.isEmpty
                    ? []
                    : _displayedData.containsKey("Metal Concentration")
                        ? [
                            {
                              'name': 'Cadmium',
                              'maxQuantity': maxQuantities['Cadmium'],
                              'quantity': _displayedData["Metal Concentration"]
                            },
                            {
                              'name': 'Arsenic',
                              'maxQuantity': maxQuantities['Arsenic'],
                              'quantity': _displayedData["Metal Concentration"]
                            },
                            {
                              'name': 'Lead',
                              'maxQuantity': maxQuantities['Lead'],
                              'quantity': _displayedData["Metal Concentration"]
                            }
                          ]
                        : [], // Return empty list if key is missing
              ),
              InfoCard(
                key: ValueKey("Inorganics${_displayedData["Inorganics Concentration"]}"),
                showChart: showInorganicsChart,
                showInfo: showInorganicsInfo,
                cardTitle: "Inorganics",
                barChartData: _displayedData.isEmpty
                    ? []
                    : _displayedData.containsKey("Inorganics Concentration")
                        ? [
                            {
                              'name': 'Nitrites',
                              'maxQuantity': maxQuantities['Nitrites'],
                              'quantity': _displayedData["Inorganics Concentration"]
                            },
                            {
                              'name': 'Nitrates',
                              'maxQuantity': maxQuantities['Nitrates'],
                              'quantity': _displayedData["Inorganics Concentration"]
                            }
                          ]
                        : [], // Return empty list if key is missing
              ),
              InfoCard(
                key: ValueKey("Microplastics${_displayedData["Microplastic Concentration"]}"),
                showChart: showPlasticChart,
                showInfo: showPlasticInfo,
                cardTitle: "Microplastics",
                barChartData: _displayedData.isEmpty
                    ? []
                    : _displayedData.containsKey("Microplastic Concentration")
                        ? [
                            {
                              'name': 'Microplastics',
                              'maxQuantity': maxQuantities['Microplastics'],
                              'quantity': _displayedData["Microplastic Concentration"]
                            }
                          ]
                        : [], // Return empty list if key is missing
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
    fetchHistory();
  }

  Map<String, List<double>> history = {};

  Future<Map<String, List<double>>> fetchHistory() async{
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('history');
    
    if (savedData != null) {
      return Map<String, List<double>>.from(jsonDecode(savedData));
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}

class InfoCard extends StatefulWidget {
  const InfoCard({
    super.key,
    required this.showChart,
    required this.showInfo,
    required this.cardTitle,
    required this.barChartData,
  });

  final BooleanWrapper showChart;
  final BooleanWrapper showInfo;
  final String cardTitle;
  final List<Map<String, dynamic>> barChartData;

  @override
  State<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.barcode_reader),
            title: Text(widget.cardTitle),
            subtitle: Text("More Information"),
          ),
          Row (
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
                    widget.showInfo.value = !widget.showInfo.value;
                  });
                },
              )
            ]
          ),
          
          if (widget.barChartData.isNotEmpty && widget.showChart.value)
            BarChart(
              key: ValueKey(widget.barChartData), // Key handles barChartData changes
              barData: widget.barChartData,
              showChart: widget.showChart,
          ),

          if (widget.showInfo.value)
            Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      // Use Expanded or Flexible to allow text to wrap
                      Expanded( // Or Flexible(flex: 1,) for more control
                        child: Image.asset("images/HeavyMetalsDrawing.jpg",
                        fit: BoxFit.contain, // Important for image scaling
                        ),
                      ),
                    ],
                  ),
                  Row (
                    children: [
                      Expanded( // Or Flexible(flex: 2,) for more control
                        child: Text(
                          "Heavy Metals - Lead, Arsenic, and Cadmium",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          softWrap: true, // Allow text to wrap to multiple lines
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16,),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildSectionTitle('Background'),
                      _buildText('Natural Occurrence: These metals exist naturally in soil, rocks, and water at low concentrations.'),
                      _buildText('Anthropogenic Sources: Human activities like mining, smelting, industrial production, waste disposal, and the use of pesticides and fertilizers contribute to elevated levels of these metals in the environment.'),
                      _buildText('Persistence: Heavy metals are persistent pollutants, meaning they don\'t break down in the environment and can accumulate over time.'),

                      _buildSectionTitle('Effects on Humans'),
                      _buildSubSectionTitle('Lead'),
                      _buildText('Sources: Old lead-based paint, contaminated water pipes, industrial emissions.'),
                      _buildText('Effects: Neurological damage (especially in children), developmental problems, kidney damage, high blood pressure.'),

                      _buildSubSectionTitle('Arsenic'),
                      _buildText('Sources: Contaminated drinking water (especially groundwater), industrial waste, pesticides.'),
                      _buildText('Effects: Skin lesions, various cancers (lung, bladder, skin), cardiovascular disease, developmental problems.'),

                      _buildSubSectionTitle('Cadmium'),
                      _buildText('Sources: Industrial discharge, mining, contaminated food (especially shellfish and leafy vegetables), cigarette smoke.'),
                      _buildText('Effects: Kidney damage, bone disease, lung cancer.'),

                      _buildSectionTitle('Presence in Water'),
                      _buildSubSectionTitle('Contamination Pathways'),
                      _buildText('Industrial discharge: Wastewater from industries like mining, smelting, and manufacturing.'),
                      _buildText('Agricultural runoff: Use of fertilizers and pesticides containing heavy metals.'),
                      _buildText('Natural leaching: Erosion of rocks and soil containing these metals.'),
                      _buildText('Atmospheric deposition: Air pollution settling into water bodies.'),
                      _buildSubSectionTitle('Health Risks'),
                      _buildText('Contaminated water can be a significant source of exposure, leading to the health problems mentioned above.'),
                    ],
                  ),
                ],
              )
            ),
        ],
      ),
    ); 
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Expanded(
        child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        softWrap: true,
        )
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, left: 16),
      child: Expanded(
        child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        softWrap: true,
        )
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 16),
      child: Expanded(
        child: Text(
        text,
        softWrap: true,
        )
      ),
    );
  }
}

