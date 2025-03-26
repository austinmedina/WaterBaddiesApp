import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import '../../screens/home/barChart.dart';
import 'infoUtils.dart';
import 'heavyMetalsInfo.dart';
import 'inorganicsInfo.dart';
import 'microplasticsInfo.dart';

class InfoCard extends StatefulWidget {
  const InfoCard({
    super.key,
    required this.showChart,
    required this.showInfo,
    required this.cardTitle,
    required this.barChartData,
    this.content = const [],
    this.imagePath = '',
  });

  final BooleanWrapper showChart;
  final BooleanWrapper showInfo;
  final String cardTitle;
  final List<Map<String, dynamic>> barChartData;
  final List<Map<String, dynamic>> content;
  final String imagePath;

  @override
  State<InfoCard> createState() => InfoCardState();
}

class InfoCardState extends State<InfoCard> {
  bool _showMoreInfo = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.info),
            title: Text(widget.cardTitle),
            //subtitle: Text("More Information"),
          ),
          Row(
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
                    _showMoreInfo = !_showMoreInfo;
                  });
                },
              )
            ],
          ),
          if (widget.barChartData.isNotEmpty && widget.showChart.value)
            BarChart(
              key: ValueKey(widget.barChartData), // Key handles barChartData changes
              barData: widget.barChartData,
              showChart: widget.showChart,
          ),
          if (widget.showInfo.value) _buildInfoContent(),
          if (_showMoreInfo) _buildMoreInfoContent(),
        ],
      ),
    );
  }

  Widget _buildInfoContent() {
    final List<Map<String, dynamic>> contentData = widget.content;
    return Column(
      children: [
        Image.asset(widget.imagePath, fit: BoxFit.contain),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            widget.cardTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentData.map((item) {
            switch (item["type"]) {
              case "section":
                return buildSectionTitle(item["text"]);
              case "subsection":
                return buildSubSectionTitle(item["text"]);
              case "text":
                return buildText(item["text"]);
              default:
                return SizedBox.shrink();
            }
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoreInfoContent() {
    if (widget.cardTitle == "Metals") {
      return HeavyMetalsInfo();
    } else if (widget.cardTitle == "Inorganics") {
      return InorganicsInfo();
    } else if (widget.cardTitle == "Microplastics") {
      return MicroplasticsInfo();
    } else {
      return SizedBox.shrink();
    }
  }
}