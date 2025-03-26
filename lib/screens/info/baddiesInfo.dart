import 'package:flutter/material.dart';
import '../../main.dart';

import 'package:flutter_tts/flutter_tts.dart';
import '../../utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'infoCard.dart';


///[WaterBaddiesInfo] is one of the pages in the body of the [BaddiesHomePage]
///It creates the [_WaterBaddiesInfoState] which displays data on our baddies, and charts of the current data from the raspberry pi
class WaterBaddiesInfo extends StatefulWidget {
  const WaterBaddiesInfo({super.key});

  @override
  State<WaterBaddiesInfo> createState() => _WaterBaddiesInfoState();
}

class _WaterBaddiesInfoState extends State<WaterBaddiesInfo> {
  Map<String, double> _displayedData = {};
  List<Map<String, dynamic>> offlineData = [];

  WaterBaddiesState wbState = WaterBaddiesState();
  final FlutterTts flutterTts = FlutterTts();

  late final BooleanWrapper showMetalChart;
  late final BooleanWrapper showInorganicsChart;
  late final BooleanWrapper showPlasticChart;
  late final BooleanWrapper showMetalInfo;
  late final BooleanWrapper showInorganicsInfo;
  late final BooleanWrapper showPlasticInfo;
  late final BooleanWrapper internetConnected;
  
  Timer? _internetTimer;

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
    internetConnected = BooleanWrapper(false);
    _initTts();
    _checkOfflineData();
    startConnectivityCheck();
  }

  _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.5);
  }

  //With the use of firebase cloud storage we need to periodically check if we have internet connectivity.
  //If there is internet connectivity and the user has data that needs to be uploaded, a button will appear
  _checkOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('offline_history')) {
      String? offlineDataString = prefs.getString('offline_history');
      if (offlineDataString != null) {
        if (mounted) {
          setState(() {
            offlineData = List<Map<String, dynamic>>.from(jsonDecode(offlineDataString));
          });
        } 
      }
    }
  }

  void startConnectivityCheck() {
    _internetTimer?.cancel();
    _internetTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      // Check internet connectivity using connectivity_plus
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (mounted){
        setState(() {
          if (connectivityResult[0] == ConnectivityResult.mobile ||
              connectivityResult[0] == ConnectivityResult.wifi) {
            internetConnected.value = true;
          } else {
            internetConnected.value = false;
          }
        });
      }
    });
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
    return warningMessages;
  }

  Future<void> addHistory(Map<String, double?> newData) async {
    try {
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
      newEntry["Healthy"] = _getHealthy(newData.cast<String, double>());

      historyInfo.add(newEntry);

      await prefs.setString('history', jsonEncode(historyInfo));

      // Check for internet connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult[0] == ConnectivityResult.none) {
        // No internet connection, store data locally
        if (prefs.containsKey('offline_history')) {
          String? offlineDataString = prefs.getString('offline_history');
          if (offlineDataString != null) {
            offlineData = List<Map<String, dynamic>>.from(jsonDecode(offlineDataString));
          }
        }
        offlineData.add(newEntry);
        await prefs.setString('offline_history', jsonEncode(offlineData));
        if (mounted) {
          _showNoInternetPopup(context);
        }
      } else {
        // Internet connection available, upload data to Firebase
        try {
          await FirebaseFirestore.instance.collection('history').add(newEntry);
          // Attempt to upload any previously stored offline data
          await _uploadOfflineData();
        } catch (e) {
          print("Error uploading data to Firebase: $e");
        }
      }
    } catch (e) {
      print("Error saving data to history: $e");
    }
  }

  Future<void> _uploadOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('offline_history')) {
      String? offlineDataString = prefs.getString('offline_history');
      if (offlineDataString != null) {
        offlineData = List<Map<String, dynamic>>.from(jsonDecode(offlineDataString));
        for (var data in offlineData) {
          try {
            await FirebaseFirestore.instance.collection('history').add(data);
          } catch (e) {
            print("Error uploading offline data: $e");
            return; // Stop uploading if an error occurs
          }
        }
        // Clear offline data after successful upload
        await prefs.remove('offline_history');
        setState(() {
          offlineData = [];
        });
        
      }
    }
  }

  void _showNoInternetPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("No Internet Connectivity"),
          content: const Text("When internet becomes available, click the upload data button."),
        );
      },
    );
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

  Map<String, double> generateRandomData() {
    final Random random = Random(); // Create a Random object

    // Generate random numbers between 120.00 and 150.00
    double generateRandomValue() {
      return 120.00 + random.nextDouble() * (150.00 - 120.00);
    }

    Map<String, double> _characteristicsData = {};

    _characteristicsData['Lead'] = generateRandomValue();
    _characteristicsData['Cadmium'] = generateRandomValue();
    _characteristicsData['Mercury'] = generateRandomValue();
    _characteristicsData['Phosphate'] = generateRandomValue();
    _characteristicsData['Nitrate'] = generateRandomValue();
    _characteristicsData['Microplastic'] = generateRandomValue();

    return _characteristicsData;
  }
  
  void _updateDisplayedData(BuildContext context) {
    //final newData = wbState.characteristicsData;
    Map<String, double> newData = generateRandomData();
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
                  child: Text(connectionMessage ?? "", textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30.0, ),
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
                  return Column(children: [ElevatedButton(
                      onPressed: () {
                        _updateDisplayedData(context);
                      },
                      child: Text("Fetch New Data"),
                    )]);
                  //return const SizedBox.shrink();
                }
              }
            ),
            Selector<WaterBaddiesState, bool>(
              selector: (context, state) => internetConnected.value && offlineData.isNotEmpty,
              builder: (context, internetConnectedAndData, child) {
                if (internetConnectedAndData) {
                  if (offlineData.isNotEmpty) {
                    return TextButton(
                      child: const Text("Upload Data"),
                      onPressed: () async {
                        await _uploadOfflineData(); // Upload offline data
                      },
                    );
                  }
                }
                return const SizedBox.shrink(); // Don't display the button if conditions aren't met
              },
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