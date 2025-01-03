import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'screens/bluetooth/bluetoothBar.dart';
import 'screens/home/barChart.dart';

void main() {
  return runApp(const WaterBaddiesApp());
}

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 6, 24, 122)),
        ),
        home: BaddiesHomePage(),
      ),
    );
  }
}

class WaterBaddiesState extends ChangeNotifier {
  BluetoothDevice? _device;

  BluetoothDevice? get device => _device;

  Map<String, double> characteristicsData = {};
  Map<BluetoothCharacteristic, StreamSubscription<List<int>>> subscriptions = {};

  set device(BluetoothDevice? newDevice) {
    _device = newDevice;
    notifyListeners();  // Notify listeners when the device is updated
  }

  void fetchCharacteristic(BluetoothDevice device) async {
    if (_device == null) throw Exception("Bluetooth device not set.");
    
    List<BluetoothService> services = await device.discoverServices();
    
    for (BluetoothService service in services) {
      if (service.uuid.str == "00000001-710e-4a5b-8d75-3e5b444bc3cf") {
        try {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.properties.read) {
              // Read the initial value
              
              List<int> charValue = await c.read();
              try {
                String charValueString = String.fromCharCodes(charValue);
                double charValueInt = double.parse(charValueString);

                // Read descriptors and update the data map
                for (BluetoothDescriptor desc in c.descriptors) {
                  List<int> descValue = await desc.read();
                  if ((descValue.length > 5) && (!descValue.every((value) => value == 0))) {
                    String descString = String.fromCharCodes(descValue);
                    characteristicsData[descString] = charValueInt;
                    //Add value to history
                  }
                } 

                // Subscribe to notifications if the characteristic supports it
                // if (c.properties.notify) {
                //   await c.setNotifyValue(true);
                //   subscriptions[c] = c.lastValueStream.listen((value) async {
                //     String updatedCharValue = String.fromCharCodes(value);

                //     // Update descriptors during notifications
                //     for (BluetoothDescriptor desc in c.descriptors) {
                //       List<int> descValue = await desc.read();
                //       if (!descValue.every((v) => v == 0)) {
                //         String descString = String.fromCharCodes(descValue);
                //         characteristicsData[descString] = updatedCharValue;
                //         //Add the value to history
                //       }
                //     }
                //     notifyListeners(); // Notify UI of updated data
                //   });
                // }
              } catch (e) {
                print("Error parsing");
              }
            }
          }
        } catch (e) {
          print("Error reading characteristic: $e");
        } 
      }
    }
  }
}

class BaddiesHomePage extends StatefulWidget {
  @override
  State<BaddiesHomePage> createState() => _BaddiesHomePageState();
}

class _BaddiesHomePageState extends State<BaddiesHomePage> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<WaterBaddiesState>();
    Widget page;
    switch (currentPageIndex) {
      case 0:
        page = WaterBaddiesInfo(appState: appState,);
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

class WaterBaddiesInfo extends StatefulWidget {
  final WaterBaddiesState appState;
  const WaterBaddiesInfo({super.key, required this.appState});

  @override
  State<WaterBaddiesInfo> createState() => _WaterBaddiesInfoState();
}

class _WaterBaddiesInfoState extends State<WaterBaddiesInfo> {
  bool _dataAvailable = false;
  Map<String, double> _displayedData = {};

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_updateLatestData);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_updateLatestData);
    super.dispose();
  }

  void _updateLatestData() {
    setState(() {
      _dataAvailable = true;
    });
  }

  void _fetchNewData() {
    setState(() {
      _displayedData = Map.from(widget.appState.characteristicsData);
      _dataAvailable = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    BooleanWrapper showMetalChart = BooleanWrapper(false);
    BooleanWrapper showInorganicsChart = BooleanWrapper(false);
    BooleanWrapper showPlasticChart = BooleanWrapper(false);
    BooleanWrapper showMetalInfo = BooleanWrapper(false);
    BooleanWrapper showInorganicsInfo = BooleanWrapper(false);
    BooleanWrapper showPlasticInfo = BooleanWrapper(false);

    BluetoothDevice? device = widget.appState.device;
    if (device != null) {
      widget.appState.fetchCharacteristic(device);
      _dataAvailable = true;
    } else {
      return Center(child: Text("Please Connect a Bluetooth Device"),);
    }

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!,
      textAlign: TextAlign.center,
      child: AnimatedBuilder(
        animation: widget.appState,
        builder: (BuildContext context, Widget? child) {
          List<Widget> children = [];

          if (_displayedData.isEmpty && _dataAvailable) {
            children.addAll([
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "New data is available! Click below to update the display.",
                    style: TextStyle(color: Colors.blue),
                    ),
                ),
                ElevatedButton(
                  onPressed: _fetchNewData,
                  child: Text("Fetch New Data"),
                )
              ]);
          } else if (_displayedData.isNotEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('You have ${_displayedData.keys.length} characteristics:'),
              ),
            );
            children.addAll([
              InfoCard(
                showChart: showMetalChart,
                showInfo: showMetalInfo,
                cardTitle: "Metals",
                barChartData: [
                  {'name': 'Cadmium', 'maxQuantity': 90, 'quantity': _displayedData["Metal Concentration"]},
                  {'name': 'Arsenic', 'maxQuantity': 95, 'quantity': _displayedData["Metal Concentration"]},
                  {'name': 'Lead', 'maxQuantity': 60, 'quantity': _displayedData["Metal Concentration"]}
                ],
              ),
              InfoCard(
                showChart: showInorganicsChart,
                showInfo: showInorganicsInfo,
                cardTitle: "Inorganics",
                barChartData: [
                  {'name': 'Nirtrites', 'maxQuantity': 75, 'quantity': _displayedData["Inorganics Concentration"]},
                  {'name': 'Nitrates', 'maxQuantity': 80, 'quantity': _displayedData["Inorganics Concentration"]}
                ],
              ),
              InfoCard(
                showChart: showPlasticChart,
                showInfo: showPlasticInfo,
                cardTitle: "Microplastics",
                barChartData: [
                  {'name': 'Microplastics', 'maxQuantity': 110, 'quantity': _displayedData["Microplastic Concentration"]}
                ],
              ),
            ]);
          } else {
            children.add(Center(child: Text("No data available"),));
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          );
        },
      ),
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
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}

class BooleanWrapper {
  bool value;
  BooleanWrapper(this.value);
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
              TextButton(
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
          if (widget.showChart.value) 
            BarChart(
              barData: widget.barChartData
            ),
          if (widget.showInfo.value)
            Card(
              child: Text("Metal Information")
            ),
        ],
      ),
    ); 
  }
}

