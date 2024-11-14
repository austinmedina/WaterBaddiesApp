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

  Future<Map<String, List<List<int>>>> fetchData(BluetoothDevice device) async {
    if (_device == null) throw Exception("Bluetooth device not set.");
    Map<String, List<List<int>>> data = {};
    List<BluetoothService> services = await device.discoverServices();
    
    for (BluetoothService service in services) {
      List<List<int>> serviceData = [];
      var characteristics = service.characteristics;
      
      for (BluetoothCharacteristic c in characteristics) {
        List<int> value = await c.read();
        serviceData.add(value);
      }
      
      data[service.toString()] = serviceData;
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
  State<TestBluetooth> createState() => _TestBluetoothState() ;
}

class _TestBluetoothState extends State<TestBluetooth> {
  dynamic _appState;
  late Future<Map<String, List<List<int>>>> _data;

  @override
  initState() {
    super.initState();
    _appState = context.watch<WaterBaddiesState>();
    _data = _appState.fetchData(_appState.device);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.displayMedium!, 
      textAlign: TextAlign.center,
      child: FutureBuilder<Map<String, List<List<int>>>>(
        future: _data,
        builder: (BuildContext context, AsyncSnapshot<Map<String, List<List<int>>>> snapshot) {
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
                    '${data.keys.length} services:'),
              )];
            for (String serv in data.keys) {
              List<Widget> deepChildren = [];
              if (data[serv]!.isNotEmpty) {
                for (var charc in data[serv]!) {
                  deepChildren.add(ListTile(
                    title: Text(charc.toString()),
                  ));
                }
              }
              children.add(ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  ListTile(title: Text(serv),),
                  SizedBox(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: deepChildren,
                    ),
                  ),
                ],
              ));
            } 
          } else {
            // Handle case where snapshot has no data (unlikely here)
            children = <Widget>[Center(child: Text('No data available.'))];
          }
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