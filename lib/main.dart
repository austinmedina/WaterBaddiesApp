import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/bluetooth/bluetoothBar.dart';
import 'screens/analytics/analyticsPage.dart';
import 'screens/history/history.dart';
import 'screens/about/about.dart';
import 'screens/info/baddiesInfo.dart';

///The main method that instantiates an instance of the entire app
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  runApp(const WaterBaddiesApp());
}

///The [WaterBaddiesApp] itself which is created once upon the [main] running
///The [build] function creates the entire view of the app, everything you see on the screen
///In the build function, a [ChangeNotifierProvider] is used to notify any listeners of the [WaterBaddiesState]
///The first thing you see is the [BaddiesHomePage]
class WaterBaddiesApp extends StatelessWidget {
  const WaterBaddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WaterBaddiesState>(
      create: (_) => WaterBaddiesState(),
      child: MaterialApp(
        title: 'Water Baddies App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color.fromARGB(255, 146, 195, 243),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 146, 195, 243)),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 4, 63, 122),
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 2,
            titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
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
  String changeKey = "";
  String _connectionMessage = "Please Connect a Bluetooth Device";
  bool newDataAvailable = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  Map<String, double> _characteristicsData = {};
  Map<BluetoothCharacteristic, StreamSubscription<List<int>>> subscriptions = {};
  List<BluetoothCharacteristic> characteristics = [];
  List<dynamic> readingSubs = [];

  BluetoothDevice? get device => _device;

  set device(BluetoothDevice? newDevice) {
    _device = newDevice;
    if (newDevice != null) { // Only fetch characteristics if newDevice is not null
      createConnectionSubscription();
      fetchCharacteristics(_device!);
      startFetchingData();
    }
    notifyListeners();  // Notify listeners when the device is updated
  }

  StreamSubscription<BluetoothConnectionState>? get connectionSub => _connectionSub;

  set connectionSub( StreamSubscription<BluetoothConnectionState>? newSub) {
    _connectionSub = newSub;
  }

  String get connectionMessage => _connectionMessage;

  set connectionMessage(String? newMessage) {
    // Check if the newMessage is null, if so, assign a default value.
    _connectionMessage = newMessage ?? "Please Connect a Bluetooth Device";
  }

  Map<String, double> get characteristicsData => Map.from(_characteristicsData);

  set characteristicsData(Map<String, double> cd) {
    _characteristicsData = cd;
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

  void startFetchingData() {
    _fetchTimer?.cancel(); // Cancel any existing timer
    _fetchTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      didKeyChange();
      if (newDataAvailable && (device != null)) {
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

  final List<String> pageTitles = [
    'Water Baddies: Breakdown',
    'Water Baddies: History',
    'Water Baddies: Cloud Analytics',
    'Water Baddies: About',
  ];

  final List<Widget> pages = [
    WaterBaddiesInfo(),
    History(),
    AnalyticsPage(),
    About(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BluetoothBar(),
      appBar: AppBar(
        title: Text(pageTitles[currentPageIndex]),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: currentPageIndex,
        onDestinationSelected: (index) => setState(() => currentPageIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Info'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
      body: pages[currentPageIndex],
    );
  }
}


