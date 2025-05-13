import 'package:flutter/material.dart';
import 'dart:convert';

import 'desktop/section_file_page.dart';
import 'desktop/home_page.dart';
import 'desktop/green_note_page.dart';
import 'desktop/directories_page.dart';
import 'desktop/task_page.dart';
import 'desktop/history_graph_page.dart';
import 'desktop/control_page.dart';
import 'desktop/green_note_history_page.dart';
import 'desktop/tracking_page.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('App started with args: $args');

  if (args.length > 2) {
    final windowArgs = jsonDecode(args[2]);

    switch (windowArgs['page']) {
      case 'file':
        runApp(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          home: SectionFilePage(
            topicId: windowArgs['topicId'],
            section: windowArgs['section'],
            fileName: windowArgs['fileName'],
          ),
        ));
        return;

      case 'green_note':
        runApp(MaterialApp(home: GreenNotePage(), debugShowCheckedModeBanner: false));
        return;

      case 'directories':
        runApp(MaterialApp(home: DirectoriesPage(), debugShowCheckedModeBanner: false));
        return;

      case 'tasks':
        runApp(MaterialApp(home: TaskPage(), debugShowCheckedModeBanner: false));
        return;

      case 'tracking':
        runApp(MaterialApp(home: TrackingPage(), debugShowCheckedModeBanner: false));
        return;

      case 'data':
        runApp(MaterialApp(home: HistoryPage(), debugShowCheckedModeBanner: false));
        return;

      case 'green_note_history':
        runApp(MaterialApp(home: GreenNoteHistoryPage(), debugShowCheckedModeBanner: false));
        return;

      case 'control':
        runApp(MaterialApp(home: ControlPage(), debugShowCheckedModeBanner: false));
        return;
    }
  }

  // Main window
  runApp(ThoughtOrganizerApp());
}
