import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../utils/utils.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _signInAndCheck();
  }

  Future<void> _signInAndCheck() async {
    try {
      final userCredential = await signInWithGoogle();
      setState(() {
        _user = userCredential.user;
      });
    } catch (e) {
      print("Error signing in: $e");
      // Optionally, show a snackbar or error message.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null && _user!.email == 'austinmedina@comcast.net') {
      return Scaffold(
        body: _user != null
            ? StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('history').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No data available.'));
                  }
                  final data = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                  return AnalyticsView(data: data);
                },
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Not authenticated, you must sign into a Google account."),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _signInAndCheck,
                      child: const Text("Sign in with Google"),
                    ),
                  ],
                ),
              ),
      );
    } else {
      // User is not authorized
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Access Denied. Only authorized users can access the cloud.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20.0),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signInAndCheck,
                child: const Text("Sign in with Google"),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class AnalyticsView extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const AnalyticsView({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, double> averages = calculateAverages(data);
    double unhealthyPercentage = calculateUnhealthyPercentage(data);
    List<Marker> markers = createMapMarkers(data);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Average Contaminant Levels
            Card(
              margin: const EdgeInsets.only(bottom: 24.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Contaminant Levels',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: BarChartWidget(averages: averages),
                    ),
                  ],
                ),
              ),
            ),
            // Section: Drinkable Water Percentage
            Card(
              margin: const EdgeInsets.only(bottom: 24.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                leading: Icon(
                  Icons.water,
                  size: 40,
                  color: unhealthyPercentage < 30
                      ? Colors.redAccent
                      : unhealthyPercentage < 70
                          ? Colors.orange
                          : Colors.green,
                ),
                title: Text(
                  'Drinkable Water Percentage',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${unhealthyPercentage.toStringAsFixed(2)}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        color: unhealthyPercentage < 30
                            ? Colors.redAccent
                            : unhealthyPercentage < 70
                                ? Colors.orange
                                : Colors.green,
                      ),
                ),
              ),
            ),
            // Section: Water Quality Map
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      'Water Quality Map',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: 300,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(32.2422, -110.9617),
                          initialZoom: 10.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> calculateAverages(List<Map<String, dynamic>> data) {
    final Map<String, List<double>> contaminantValues = {};
    for (final entry in data) {
      entry.forEach((key, value) {
        if (value is double) {
          contaminantValues.putIfAbsent(key, () => []).add(value);
        }
      });
    }
    final Map<String, double> averages = {};
    contaminantValues.forEach((key, values) {
      if (values.isNotEmpty) {
        averages[key] = double.parse((values.reduce((a, b) => a + b) / values.length)
            .toStringAsFixed(2));
      }
    });
    return averages;
  }

  double calculateUnhealthyPercentage(List<Map<String, dynamic>> data) {
    final unhealthyCount = data.where((entry) {
      if (entry['Healthy'] is List) {
        return (entry['Healthy'] as List).isEmpty;
      } else {
        return true;
      }
    }).length;
    return (unhealthyCount / data.length) * 100;
  }

  List<Marker> createMapMarkers(List<Map<String, dynamic>> data) {
    return data.map((entry) {
      final latitude = entry['Location']['Latitude'] as double;
      final longitude = entry['Location']['Longitude'] as double;
      final List<String> unhealthyContaminants =
          List<String>.from(entry['Healthy'] ?? []);
      final isHealthy = unhealthyContaminants.isEmpty;
      return Marker(
        point: LatLng(latitude, longitude),
        width: 40.0,
        height: 40.0,
        child: Icon(
          Icons.location_on,
          color: isHealthy ? Colors.green : Colors.red,
          size: 40.0,
        ),
      );
    }).toList();
  }
}

class BarChartWidget extends StatelessWidget {
  final Map<String, double> averages;

  BarChartWidget({required this.averages});

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = averages.entries.map((entry) {
      return BarChartGroupData(
        x: averages.keys.toList().indexOf(entry.key),
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: Colors.blue,
          ),
        ],
        showingTooltipIndicators: [1],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: averages.values.reduce(max) * 1.2,
        titlesData: FlTitlesData(
          show: true,
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Padding( // Added padding
                  padding: const EdgeInsets.only(top: 25.0, right: 25.0), // Added top padding
                  child: Transform.rotate(
                    angle: -pi / 4,
                    child: Text(averages.keys.toList()[value.toInt()]),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == averages.values.reduce(max) * 1.2) { // Hide max value label
                  return const Text('');
                }
                return Text(
                  value.toStringAsFixed(1),
                  softWrap: false, // Prevent wrapping
                );
              },
            )
          )
        ),
        barGroups: barGroups,
      ),
    );
  }
}