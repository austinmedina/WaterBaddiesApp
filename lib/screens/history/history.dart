import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../utils/utils.dart';

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
    final savedData = prefs.getString('history');
    if (savedData != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(savedData));
    }
    return [];
  }

  Widget _buildKeyValueRow(String key, Map<String, dynamic> data) {
    final value = data[key];
    String displayValue = "No Value";
    if (value != null) {
      if (key == "Location") {
        displayValue = "${value['Latitude']}, ${value['Longitude']}";
      } else {
        displayValue = value.toString();
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$key:',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const Center(child: Text('No history found.'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: item.containsKey('Date')
                        ? Text(item['Date'])
                        : const Text("No Date"),
                    subtitle: Text(
                      "High levels of: ${item['Healthy'] is List ? (item['Healthy'] as List).join(', ') : item['Healthy']}",
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                    children: [
                      _buildKeyValueRow('Lead', item),
                      _buildKeyValueRow('Cadmium', item),
                      _buildKeyValueRow('Mercury', item),
                      _buildKeyValueRow('Nitrate', item),
                      _buildKeyValueRow('Phosphate', item),
                      _buildKeyValueRow('Microplastic', item),
                      _buildKeyValueRow('Location', item),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await createPDF(item);
                        },
                        child: const Text('Generate PDF'),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}