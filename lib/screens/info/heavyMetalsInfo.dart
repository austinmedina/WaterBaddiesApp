import 'package:flutter/material.dart';
import 'infoUtils.dart';

class HeavyMetalsInfo extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _HeavyMetalsInfoState createState() => _HeavyMetalsInfoState();
}

class _HeavyMetalsInfoState extends State<HeavyMetalsInfo> {
  String? selectedMetal;

  final Map<String, String> metalInfo = {
    'Lead': "EPA Standard: 5.0 mg/L \nLead exposure can cause neurological damage, especially in children. Sources include old lead-based paint, industrial emissions, and contaminated water pipes.",
    'Cadmium': "EPA Standard: 1.0 mg/L\nCadmium exposure is linked to kidney damage and lung disease. It is commonly deposited in water systems through in groundwater contamination, pesticides, industrial waste.",
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          ClipOval(
            child: Image.asset(
              "images/HeavyMetals.jpg",
              width: 300,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 10),

          // Always Visible Buttons
          Wrap(
            spacing: 10.0, // Space between buttons
            children: metalInfo.keys.map((metal) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedMetal = (selectedMetal == metal) ? null : metal;
                  });
                },
                child: Text(
                  metal,
                  style: TextStyle(fontSize: 16), // Set font size here
                ),
              );
             }).toList(),
            ),
          SizedBox(height: 10),

          // Selected metal information in card
          if (selectedMetal != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xffAFDBF5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
    
              Text(
                    selectedMetal!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    metalInfo[selectedMetal!]!,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
             ),
SizedBox(height: 10),

          // Background Information Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff6CB4EE),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
            ),
            
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSectionTitle("Heavy Metals"),
                buildText("Heavy metals are naturally ocurring and generally toxic to humans, they can deposit into water systems through household plumbing through runoff from mining operations, petroleum refineries, cement or electronics manufacturures, and waste disposal operations.\nHumans can be detrimentally affected by increased exposure to heavy metals. Heavy metals bioaccumulate in the body over time, meaning they are not easily excreted and can cause long-term health damage. Chronic exposure can lead to organ failure, neurological disorders, and increased cancer risk. Heavy metal contamination is a serious global issue, and staying informed can help minimize health risks",),
              ],
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}