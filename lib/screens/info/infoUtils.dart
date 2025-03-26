import 'package:flutter/material.dart';

Widget buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
    child: Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      softWrap: true,
    ),
  );
}

Widget buildSubSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, left: 16),
    child: Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      softWrap: true,
    ),
  );
}

Widget buildText(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0, left: 16),
    child: Text(
      text,
      softWrap: true,
    ),
  );
}