import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class AnalyticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Water Quality Analytics')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('history').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No data available.'));
          }

          List<Map<String, dynamic>> data = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          return AnalyticsView(data: data);
        },
      ),
    );
  }
}

class AnalyticsView extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  AnalyticsView({required this.data});

  @override
  Widget build(BuildContext context) {
    // Calculate analytics
    Map<String, double> averages = calculateAverages(data);
    double unhealthyPercentage = calculateUnhealthyPercentage(data);
    List<Marker> markers = createMapMarkers(data);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average Contaminant Levels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Container(height: 200, child: BarChartWidget(averages: averages)),
          SizedBox(height: 40),
          Text(
            'Percentage of Healthy: ${unhealthyPercentage.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 16,
              color: unhealthyPercentage < 30
                  ? Colors.red
                  : unhealthyPercentage < 70
                      ? Colors.yellow
                      : Colors.green,
            ),
          ),
          SizedBox(height: 20),
          Text('Water Quality Map', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Container(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(32.2422, -110.9617), // Default center
                initialZoom: 10.0,
              ),
              children: [ // Add the children parameter here
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          )
        ],
      ),
    );
  }

  Map<String, double> calculateAverages(List<Map<String, dynamic>> data) {
    Map<String, List<double>> contaminantValues = {};
    data.forEach((entry) {
      entry.forEach((key, value) {
        if (value is double) {
          contaminantValues.putIfAbsent(key, () => []);
          contaminantValues[key]!.add(value);
        }
      });
    });

    Map<String, double> averages = {};
    contaminantValues.forEach((key, values) {
      if (values.isNotEmpty) {
        averages[key] = double.parse(
            (values.reduce((a, b) => a + b) / values.length).toStringAsFixed(2));
      }
    });
    return averages;
  }

  double calculateUnhealthyPercentage(List<Map<String, dynamic>> data) {
    int unhealthyCount = data.where((entry) {
      if (entry['Healthy'] is List) {
        return (entry['Healthy'] as List).isEmpty;
      } else {
        return true; // Or handle other cases as needed
      }
    }).length;

    return (unhealthyCount / data.length) * 100;
  }

  List<Marker> createMapMarkers(List<Map<String, dynamic>> data) {
    return data.map((entry) {
      double latitude = entry['Location']['Latitude'];
      double longitude = entry['Location']['Longitude'];
      List<String> unhealthyContaminants = List<String>.from(entry['Healthy'] ?? []); // Ensure Healthy is a list

      bool isHealthy = unhealthyContaminants.isEmpty; // If the array is empty, it's healthy

      return Marker(
        point: LatLng(latitude, longitude),
        child: Icon(
          Icons.location_on,
          color: isHealthy ? Colors.green : Colors.red,
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