import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'green_note_page.dart';
import 'directories_page.dart';
import 'section_file_page.dart';
import 'task_page.dart';
import 'daily_tasks_page.dart';
import 'history_graph_page.dart';
import 'control_page.dart';
import 'green_note_history_page.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(ThoughtOrganizerApp());
}

class ThoughtOrganizerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thought Organizer',
      home: MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  final List<String> topIcons = [
    'assets/green_note.png',
    'assets/daily_tasks.png',
    'assets/tasks.png',
    'assets/control.png',
    'assets/data.png',
    'assets/history.png',
    'assets/directories.png',
  ];

  final TextEditingController _mainNoteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> pinnedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadPinnedFiles();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPinnedFiles();
    }
  }

  Future<void> _loadPinnedFiles() async {
    try {
      final res = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/pinned_files'));
      if (res.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(res.body);

        setState(() {
          pinnedFiles = decoded.map((file) => {
            'file': file['name'],
            'section': file['section'],
            'file_id': file['id'],
            'topic': file['topic_name'],
            'color': Color(file['topic_color']),
          }).toList();
        });
      } else {
        print('Failed to fetch pinned files: ${res.statusCode}');
      }
    } catch (e) {
      print('Error loading pinned files: $e');
    }
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 180,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 180,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: topIcons.map((iconPath) {
                    return GestureDetector(
                      onTap: () {
                        if (iconPath == 'assets/green_note.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GreenNotePage()));
                        }
                        if (iconPath == 'assets/directories.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DirectoriesPage()));
                        }
                        if (iconPath == 'assets/tasks.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage()));
                        }
                        if (iconPath == 'assets/daily_tasks.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DailyTasksPage()));
                        }
                        if (iconPath == 'assets/data.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryPage()));
                        }
                        if (iconPath == 'assets/history.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GreenNoteHistoryPage()));
                        }
                        if (iconPath == 'assets/control.png') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ControlPage()));
                        }
                      },
                      child: Image.asset(iconPath, height: 32),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _mainNoteController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration.collapsed(
                        hintText: 'כתוב את המחשבות שלך כאן...',
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 110,
                child: Row(
                  children: [
                    IconButton(icon: Icon(Icons.arrow_right), onPressed: _scrollLeft),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: pinnedFiles.length,
                        itemBuilder: (context, index) {
                          final file = pinnedFiles[index];
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SectionFilePage(
                                    section: file['section'],
                                    fileName: file['file'],
                                    fileId: file['file_id'],
                                  ),
                                ),
                              );
                              await _loadPinnedFiles();
                            },
                            onSecondaryTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              setState(() {
                                pinnedFiles.removeAt(index);
                              });
                              await prefs.setString('pinned_files', jsonEncode(pinnedFiles));
                            },
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (file['color'] as Color).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(file['topic'], style: TextStyle(fontSize: 12, color: Colors.white)),
                                  SizedBox(height: 6),
                                  Text(file['file'],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(icon: Icon(Icons.arrow_left), onPressed: _scrollRight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
