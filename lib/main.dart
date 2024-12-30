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

  set device(BluetoothDevice? newDevice) {
    _device = newDevice;
    notifyListeners();  // Notify listeners when the device is updated
  }

  void updateValues(List<int> value) {
    print("Updated");
  }

  Future<Map<String, String>> fetchCharacteristic(BluetoothDevice device) async {
    if (_device == null) throw Exception("Bluetooth device not set.");
    
    Map<String, String> data = {};
    List<BluetoothService> services = await device.discoverServices();
    
    for (BluetoothService service in services) {
      if (service.uuid.str == "00000001-710e-4a5b-8d75-3e5b444bc3cf") {
        var characteristics = service.characteristics;
        
        for (BluetoothCharacteristic c in characteristics) {
          // Check if the characteristic has the 'read' property
          if (c.properties.read) {
            // Read the characteristic value
            List<int> charValue = await c.read();
            String asciiString = String.fromCharCodes(charValue);

            for (BluetoothDescriptor desc in c.descriptors) {
              List<int> descriptionValue = await desc.read();  
              if (!descriptionValue.every((value) => value == 0)) {
                String asciiDescription = String.fromCharCodes(descriptionValue);
                data[asciiDescription] = asciiString;
              } 
            }
          }
        }
      }
    }
    
    return data;
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
    Widget page;
    switch (currentPageIndex) {
      case 0:
        page = TestBluetooth();
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

class TestBluetooth extends StatefulWidget {
  const TestBluetooth({super.key});

  @override
  State<TestBluetooth> createState() => _TestBluetoothState();
}

class _TestBluetoothState extends State<TestBluetooth> {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<WaterBaddiesState>();
    var data;
    BooleanWrapper showMetalChart = BooleanWrapper(false);
    BooleanWrapper showInorganicsChart = BooleanWrapper(false);
    BooleanWrapper showPlasticChart = BooleanWrapper(false);
    BooleanWrapper showMetalInfo = BooleanWrapper(false);
    BooleanWrapper showInorganicsInfo = BooleanWrapper(false);
    BooleanWrapper showPlasticInfo = BooleanWrapper(false);

    BluetoothDevice? device = appState.device;
    if (device != null) {
      data = appState.fetchCharacteristic(device);
    } else {
      data = null;
    }

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!, 
      textAlign: TextAlign.center,
      child: FutureBuilder<Map<String, String>>(
        future: data,
        builder: (BuildContext context, AsyncSnapshot<Map<String, String>> snapshot) {
          List<Widget> children;
          if (snapshot.connectionState == ConnectionState.waiting) {
            children = <Widget>[Center(child: CircularProgressIndicator())];
          } else if (snapshot.hasError) {
            // Error message if there was an error
            children = <Widget>[Center(child: Text('Error: ${snapshot.error}'))];
          } else if (snapshot.hasData) {
            var data = snapshot.data!;
            children = <Widget>[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('You have '
                    '${data.keys.length} characteristics:'),
              )];
            for (String description in data.keys) {
              children.add(ListTile(
                title: Text(description),
                subtitle: Text(data[description]!),
              ));
            }
          } else {
            //Handle case where snapshot has no data
            children = <Widget>[Center(child: Text('No data available.'))];
          }
          children.add(ListBody(
            children: [
              InfoCard(
                showChart: showMetalChart, 
                showInfo: showMetalInfo, 
                cardTitle: "Metals", 
                barChartData: [
                  {'name': 'Cadmium', 'maxQuantity': 10, 'quantity': 8.5}, 
                  {'name': 'Arsenic', 'maxQuantity': 15, 'quantity': 12.5},
                  {'name': 'Lead', 'maxQuantity': 5, 'quantity': 7.5}
                ]
              ),
              InfoCard(
                showChart: showInorganicsChart,
                showInfo: showInorganicsInfo,
                cardTitle: "Inorganics",
                barChartData: [
                  {'name': 'Nirtrites', 'maxQuantity': 10, 'quantity': 13.5}, 
                  {'name': 'Nitrates', 'maxQuantity': 15, 'quantity': 1.5}
                ]
              ),
              InfoCard(
                showChart: showPlasticChart,
                showInfo: showPlasticInfo,
                cardTitle: "Inorganics",
                barChartData: [{'name': 'Microplastics', 'maxQuantity': 11, 'quantity': 11.5}],
              )
            ],
          ));
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

