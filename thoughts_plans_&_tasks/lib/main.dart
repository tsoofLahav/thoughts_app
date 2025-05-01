import 'package:flutter/material.dart';
import 'home_page.dart';
import 'section_file_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.isNotEmpty) {
    // This is a newly created window
    final windowId = int.parse(args[0]);
    final controller = WindowController.fromWindowId(windowId);

    final res = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/window_args'));
    final data = jsonDecode(res.body);

    runApp(MaterialApp(
      home: SectionFilePage(
        topicId: data['topicId'],
        section: data['section'],
        fileName: data['fileName'],
      ),
    ));
  } else {
    // This is the main window
    runApp(ThoughtOrganizerApp());
  }
}
