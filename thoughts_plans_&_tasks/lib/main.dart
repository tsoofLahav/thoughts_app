
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
import 'topic_manager.dart';
import 'control_page.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pinned_files');
    if (stored != null) {
      final decoded = List<Map<String, dynamic>>.from(jsonDecode(stored));
      final topicMap = {for (var t in TopicManager.topics) t['name']: t['color']};

      setState(() {
        pinnedFiles = decoded.map((file) {
          final topicColor = topicMap[file['topic']] ?? Colors.teal;
          return {
            ...file,
            'color': topicColor,
          };
        }).toList();
      });
    }
  }

  Future<void> _saveToTopic() async {
    final text = _mainNoteController.text;
    final selection = _mainNoteController.selection;
    if (selection.isCollapsed) return;

    final selectedText = text.substring(selection.start, selection.end).trim();
    if (selectedText.isEmpty) return;

    final selectedLines = selectedText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('בחר קובץ לשמירה'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("קבצים מהירים"),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pinnedFiles.map((file) {
                    return GestureDetector(
                      onTap: () => _saveToFile(
                        topic: file['topic'],
                        section: file['section'],
                        fileName: file['file'],
                        linesToSave: selectedLines,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (file['color'] as Color).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(file['file'], style: TextStyle(color: Colors.white)),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Text("נושאים"),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: TopicManager.topics.map((topic) {
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final section = await _pickSection();
                        if (section == null) return;
                        final file = await _pickFile(topic['name'], section);
                        if (file == null) return;

                        _saveToFile(
                          topic: topic['name'],
                          section: section,
                          fileName: file,
                          linesToSave: selectedLines,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: topic['color'],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(topic['name'], style: TextStyle(color: Colors.white)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('סגור'))
        ],
      ),
    );
  }

  Future<void> _saveToFile({
    required String topic,
    required String section,
    required String fileName,
    required List<String> linesToSave,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${topic}_$section\_$fileName'.replaceAll(' ', '_');
    final stored = prefs.getString(key);
    List<dynamic> content = stored != null ? jsonDecode(stored) : [];

    if (section == 'docs') {
      for (final line in linesToSave) {
        content.add({
          'text': line,
          'date': DateTime.now().toString().split(' ').first,
        });
      }
    } else {
      content.addAll(linesToSave);
    }

    await prefs.setString(key, jsonEncode(content));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('המשפט נשמר בהצלחה'),
    ));
  }

  Future<String?> _pickSection() async {
    return await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('בחר חלק'),
        children: [
          SimpleDialogOption(
            child: Text('תוכניות'),
            onPressed: () => Navigator.pop(context, 'plans'),
          ),
          SimpleDialogOption(
            child: Text('משימות'),
            onPressed: () => Navigator.pop(context, 'tasks'),
          ),
          SimpleDialogOption(
            child: Text('תיעוד'),
            onPressed: () => Navigator.pop(context, 'docs'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickFile(String topic, String section) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${topic}_$section';
    final stored = prefs.getString(key);
    final files = stored != null ? List<String>.from(jsonDecode(stored)) : [];

    return await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('בחר קובץ'),
        children: files
            .map((file) => SimpleDialogOption(
                  child: Text(file),
                  onPressed: () => Navigator.pop(context, file),
                ))
            .toList(),
      ),
    );
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _saveToTopic,
                      child: Text("שמור לנושא"),
                    ),
                  ],
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
                                    topicName: file['topic'],
                                    section: file['section'],
                                    fileName: file['file'],
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
