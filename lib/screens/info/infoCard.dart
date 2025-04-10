import 'package:flutter/material.dart';
import '../../utils/utils.dart';
import 'barChart.dart';
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
  });

  final BooleanWrapper showChart;
  final BooleanWrapper showInfo;
  final String cardTitle;
  final List<Map<String, dynamic>> barChartData;

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            widget.cardTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
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