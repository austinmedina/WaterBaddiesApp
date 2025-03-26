import 'package:flutter/material.dart';
import 'infoUtils.dart';

class MicroplasticsInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        ClipOval(
          child: SizedBox.fromSize(
            size: const Size.fromRadius(144),
            child: Image.asset(
              "images/Water Baddies.jpg",
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: 20),

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
              buildSectionTitle("Microplastics"),
              buildText("Microplastics are tiny plastic particles (less than 5mm in size) that contaminate drinking water through industrial waste, plastic pollution, and the breakdown of larger plastics. These particles have been found in tap water, bottled water, and even the air we breathe, raising concerns about their long-term health effects."),
              buildText("Since microplastics can degrade to microscopic sizes, they  can penetrate human cells, causing inflammation, oxidative stress, and DNA damage. Microplastics can act as carriers rather than catalysts and they can contain endocrine-disrupting chemicals (EDCs), which can interfere with hormone regulation."),
              buildText("Microplastics absorb and transport harmful pollutants, such as pesticides, heavy metals, and industrial chemicals, into the human body. These contaminants may increase the risk of neurotoxicity, liver damage, and immune system dysfunction."),
              buildText("Since microplastics are invisible to the naked eye and cannot be easily filtered out by standard water treatment processes, reducing plastic waste and using advanced filtration methods may help minimize exposure."),
            ]
          ),
        ),
      ]      
      ),
    );
  }
}