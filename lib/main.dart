import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/bluetooth/bluetoothBar.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(const WaterBaddiesApp());

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
        page = Placeholder();
      case 1:
        page = Placeholder();
      case 2:
        page = TestBluetooth();
      case 3:
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
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.safety_check),
                label: 'Microplastics',
              ),
              NavigationDestination(
                icon: Icon(Icons.stadium),
                label: 'Metals',
              ),
              NavigationDestination(
                icon: Icon(Icons.play_lesson_outlined),
                label: 'Inorganics',
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

// class GeneratorPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     var appState = context.watch<WaterBaddiesState>();
//     var pair = appState.current;

//     IconData icon;
//     if (appState.favorites.contains(pair)) {
//       icon = Icons.favorite;
//     } else {
//       icon = Icons.favorite_border;
//     }

//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           BigCard(pair: pair),
//           SizedBox(height: 10),
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: () {
//                   appState.toggleFavorite();
//                 },
//                 icon: Icon(icon),
//                 label: Text('Like'),
//               ),
//               SizedBox(width: 10),
//               ElevatedButton(
//                 onPressed: () {
//                   appState.getNext();
//                 },
//                 child: Text('Next'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class FavoritesPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     var appState = context.watch<WaterBaddiesState>();

//     if (appState.favorites.isEmpty) {
//       return Center(
//         child: Text('No favorites yet.'),
//       );
//     }

//     return ListView(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(20),
//           child: Text('You have '
//               '${appState.favorites.length} favorites:'),
//         ),
        
//         for (var pair in appState.favorites) 
//           ListTile(
//             leading: Icon(Icons.favorite),
//             title: Text(pair.asLowerCase)
//           )
//       ],
//     );
//   }
// }

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
            // Handle case where snapshot has no data (unlikely here)
            children = <Widget>[Center(child: Text('No data available.'))];
          }
          children.add(BarChart());
          children.add(ExpansionTile(
            title: Text("Microplastics"),
            subtitle: Text("More Information"),
            ));
          children.add(ExpansionTile(
            title: Text("Metals"),
            subtitle: Text("More Information"),
            ));
          children.add(ExpansionTile(
            title: Text("Inorganics"),
            subtitle: Text("More Information"),
            ));
          return Center(
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

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          pair.asLowerCase, 
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",),
      ),
    );
  }
}

class BarChart extends StatelessWidget {
  const BarChart({super.key, this.prop});

  Map<String, int> testMap = {'Cadmium': 10};

  @override
  Widget build(BuildContext context) {
    
    throw UnimplementedError();
  }
}