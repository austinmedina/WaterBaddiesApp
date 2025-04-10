import 'package:flutter/material.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  @override
  Widget build(BuildContext context) {
    final List<String> peoplePhotos = [
      "images/austin.png",
      "images/alia.png",
      "images/tyler.png",
      "images/danny.png",
      "images/jameson.png",
      "images/brendan.png",
      "images/aidan.png",
    ];
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Our Team",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 10.0;
                        const itemsPerRow = 3;
                        final totalSpacing = spacing * (itemsPerRow - 1);
                        final itemSize = (constraints.maxWidth - totalSpacing) / itemsPerRow;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          alignment: WrapAlignment.center,
                          children: peoplePhotos.map((path) {
                            return Container(
                              width: itemSize,
                              height: itemSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                                image: DecorationImage(
                                  image: AssetImage(path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Water Baddies App", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      "How to:\n"
                      "Congratulations! You are one step closer to a better understanding of the water you are drinking. Baddies in water refers to lead, cadmium, mercury, and microplastics.\n\n"
                      "Now that you have the device running, it’s time to interpret the results. First, navigate to the information tab on the bottom left of the screen. Next, you’ll find more information concerning the ‘baddies’ in your water. Click ‘more information’ to read more about the effects, standards, and implications of water baddies.\n\n"
                      "After the device has analyzed your water sample, you will be able to see the bar chart describing the amount of ‘baddies’ in your water. Click the data button to view the charts. If there is no data, the button will say no data which means you are either not connected to the device or have not refreshed the app to get the newest data. There will be a red line that will compare your ‘baddie’ levels to the US Environmental Protection Agency’s allowable levels where the water is still safe to consume.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Frequently Asked Questions (FAQ)", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text("Q: What does ‘no data’ mean?"),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "A: You may be disconnected from the device, or you have not refreshed the app so that your most recent trial data has been collected.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text("Q: Why doesn’t my phone connect?"),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "A: Force reset button on the Water Baddies device, and reset the Bluetooth.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      title: const Text("Q: Do I need to keep the device powered on?"),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "A: Yes, if the power is turned off the device will turn off. If you turn it off using the display, the battery will also need to be turned off. Turning on the battery will initialize the system.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
