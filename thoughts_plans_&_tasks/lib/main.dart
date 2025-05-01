import 'package:flutter/material.dart';
import 'home_page.dart';
import 'section_file_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final res = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/window_args'));
  final args = jsonDecode(res.body);
  Widget app;

  if (args.isEmpty || args['page'] == null) {
    app = ThoughtOrganizerApp();
  } else if (args['page'] == 'file') {
    app = MaterialApp(
      home: SectionFilePage(
        topicId: args['topicId'],
        section: args['section'],
        fileName: args['fileName'],
      ),
    );
  } else {
    app = ThoughtOrganizerApp();
  }

  runApp(app);
}
