import 'package:flutter/material.dart';
import 'infoUtils.dart';

class InorganicsInfo extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _InorganicssInfoState createState() => _InorganicssInfoState();
}

class _InorganicssInfoState extends State<InorganicsInfo> {
  String? selectedInorganic;


  final Map<String, String> inorganicsInfo = {
    'Nitrates': "EPA Standards: 10g/ml.\nNitrates are relatively less toxic than nitrites. They origincate from fertilizers, natural soil decomposition, and wastewater.",
    'Nitrites': "EPA Standards: 1g/ml.\nNitrites are more reactive and can interfere with oxygen transport in the blood. Nitrite exposure may contribute to high blood pressure and vascular damage, increasing the risk of heart disease and stroke They originate from industrial waster, bacterial breakdown, and food preservatives.",
    'Phosphates': "Phosphorus is commonly found in agricultural fertilizers, manure, and organic waste from sewage and industrial effluent. While it is essential for plant growth, excessive phosphorus in water can accelerate eutrophication which is a process where increased mineral and organic nutrients reduce dissolved oxygen levels in rivers and lakes."
  };

  @override
  Widget build(BuildContext context) {
     return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: SizedBox.fromSize(
              size: const Size.fromRadius(150),
              child: Image.asset(
                "images/Inorganics2.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 10),

          // Always Visible Buttons
          Wrap(
            spacing: 10.0, // Space between buttons
            children: inorganicsInfo.keys.map((inorganic) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedInorganic = (selectedInorganic == inorganic) ? null : inorganic;
                  });
                },
                child: Text(inorganic,
                  style: TextStyle(fontSize: 16), // Set font size here
                ),
              );
             }).toList(),
            ),
             
  
          SizedBox(height: 10),
          //details in boxes
          if (selectedInorganic != null)
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
                    selectedInorganic!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    inorganicsInfo[selectedInorganic!]!,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),

          SizedBox(height: 10),

          // Background information (Always Visible)
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
                buildSectionTitle("Inorganics"),
                buildText("Nitrite and nitrate ions are a part of the earth’s nitrogen cycle, they naturally occur in the soil and water environments. These inorganics are also released through human made products like fertilizers, waste water treatment facilities’ runoff."),
                buildText("Excessive nitrate consumption can interfere with the blood’s ability to carry oxygen, leading to methemoglobinemia, also known as blue baby syndrome. Bottle-fed infants under six months old are most vulnerable to this condition, which can cause serious illness or even death. Recent scientific studies suggest that long-term exposure to nitrate in drinking water, even at levels below the current regulatory standard, may be linked to thyroid disorders, adverse pregnancy outcomes, and certain cancers, particularly colorectal cancer. Further research is needed to confirm these findings."),
                
              ], 
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}