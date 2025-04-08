import 'package:flutter/material.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Members Section
            const Text(
              "Our Team",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              itemCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/team_placeholder.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Instructions Section
            const Text(
              "Instructions",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Insert instructions here on how to use the system. Provide step-by-step guides or video tutorials as needed.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            // FAQ Section
            const Text(
              "Frequently Asked Questions (FAQ)",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text("Question 1: How do I use the system?"),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text("Answer: Follow the step-by-step guide provided in the Instructions section."),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text("Question 2: How do I report an issue?"),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text("Answer: Contact support via the support email provided in the app."),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text("Question 3: How do I access team support?"),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text("Answer: Navigate to the support section from the main menu to contact team support."),
                ),
              ],
            ),
            // Add more FAQs as needed
          ],
        ),
      ),
    );
  }
}
