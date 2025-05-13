import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'green_note_page.dart';
import 'directories_page.dart';
import 'section_file_page.dart';
import 'task_page.dart';
import 'tracking_page.dart';
import 'history_graph_page.dart';
import 'control_page.dart';
import 'green_note_history_page.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';


class ThoughtOrganizerApp extends StatelessWidget {
  const ThoughtOrganizerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainPage(), // Your main app page
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
    'assets/tracking.png',
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

  /////////////////////////////////////////////////////////////
  /////////////////// LOAD + TOGGLE PINNED FILES //////////////
  /////////////////////////////////////////////////////////////

  Future<void> _loadPinnedFiles() async {
    try {
      final res = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/linked_files'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        List<Map<String, dynamic>> files = [];

        for (var item in data) {
          final topicId = item['topic_id'];
          final topicRes = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/topic_details/$topicId'));
          if (topicRes.statusCode == 200) {
            final topicData = jsonDecode(topicRes.body);
            files.add({
              'file': item['file_name'],
              'section': item['section'],
              'topic_id': topicId,
              'topic': topicData['name'],
              'color': Color(topicData['color'])
            });
          }
        }

        setState(() {
          pinnedFiles = files;
        });
      }
    } catch (e) {
      print('Failed to load linked files: $e');
    }
  }

  void _toggleLink(String fileName, int topicId) async {
    try {
      await http.post(
        Uri.parse('https://thoughts-app-92lm.onrender.com/file_link/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': fileName, 'topic_id': topicId}),
      );
      _loadPinnedFiles();
    } catch (e) {
      print('Failed to toggle link: $e');
    }
  }

  /////////////////////////////////////////////////////////////
  ////////////////////////// SAVE TO FILE /////////////////////
  /////////////////////////////////////////////////////////////

  void _saveToFile() async {
    String selectedText = '';
    final selection = _mainNoteController.selection;
    if (!selection.isCollapsed) {
      selectedText = _mainNoteController.text.substring(selection.start, selection.end).trim();
    } else {
      List<String> lines = _mainNoteController.text.trim().split('\n');
      selectedText = lines.isNotEmpty ? lines.last.trim() : '';
    }

    if (selectedText.isEmpty) return;

    final topicsRes = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/directories'));
    if (topicsRes.statusCode != 200) return;
    final Map<String, dynamic> houses = jsonDecode(topicsRes.body);

    final List<Map<String, dynamic>> topics = [];
    houses.forEach((house, topicsList) {
      for (var t in topicsList) {
        topics.add(t);
      }
    });

    final topic = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('בחר נושא'),
        children: topics.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, t),
          child: Text(t['name'], style: TextStyle(color: Color(t['color']))),
        )).toList(),
      ),
    );
    if (topic == null) return;

    final filesRes = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/files/${topic['id']}'));
    if (filesRes.statusCode != 200) return;
    final Map<String, dynamic> groupedFiles = jsonDecode(filesRes.body);

    final List<Map<String, dynamic>> files = [];
    groupedFiles.forEach((section, fileNames) {
      for (var name in fileNames) {
        files.add({'name': name, 'section': section});
      }
    });

    final file = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('בחר קובץ'),
        children: files.map((f) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, f),
          child: Text('${f['name']} (${f['section']})'),
        )).toList(),
      ),
    );
    if (file == null) return;

    final contentRes = await http.get(Uri.parse(
      'https://thoughts-app-92lm.onrender.com/file_info?topic_id=${topic['id']}&file_name=${Uri.encodeComponent(file['name'])}',
    ));
    if (contentRes.statusCode != 200) return;
    List<dynamic> content = jsonDecode(contentRes.body)['content'];

    List<String> points = selectedText.split('\n').where((s) => s.trim().isNotEmpty).toList();
    content.addAll(points.map((p) => {'text': p}));

    await http.post(
      Uri.parse('https://thoughts-app-92lm.onrender.com/file_content'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'topic_id': topic['id'],
        'name': file['name'],
        'content': content,
      }),
    );
  }

  /////////////////////////////////////////////////////////////
  ////////////////////////// UI HELPERS ///////////////////////
  /////////////////////////////////////////////////////////////

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

  /////////////////////////////////////////////////////////////
  /////////////////////// CONTEXT MENU ////////////////////////
  /////////////////////////////////////////////////////////////

  void _showContextMenu(Offset position, Map file) async {
    final selected = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 'unlink',
          child: Text('Unlink'),
        ),
        PopupMenuItem(
          value: 'new_window',
          child: Text('Open in new window'),
        ),
      ],
    );

    if (selected == 'unlink') {
      _toggleLink(file['file'], file['topic_id']);
    } else if (selected == 'new_window') {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({
        'page': 'file',
        'topicId': file['topic_id'],
        'section': file['section'],
        'fileName': file['file'],
      }));
      window
        ..setFrame(const Offset(200, 200) & const Size(800, 600))
        ..setTitle(file['file'])
        ..show();
    }
  }
  /////////////////////////////////////////////////////////////
  ////////////////////////// OPEN ICONPATH ////////////////////
  /////////////////////////////////////////////////////////////
  void _openPage(String iconPath, {required bool newWindow}) async {
    String? page;

    if (iconPath == 'assets/green_note.png') page = 'green_note';
    if (iconPath == 'assets/directories.png') page = 'directories';
    if (iconPath == 'assets/tasks.png') page = 'tasks';
    if (iconPath == 'assets/tracking.png') page = 'tracking';
    if (iconPath == 'assets/data.png') page = 'data';
    if (iconPath == 'assets/history.png') page = 'green_note_history';
    if (iconPath == 'assets/control.png') page = 'control';

    if (page == null) return;

    if (newWindow) {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({'page': page}));
      window
        ..setFrame(const Offset(200, 200) & const Size(800, 600))
        ..setTitle(page)
        ..show();
    } else {
      Widget destination;
      switch (page) {
        case 'green_note': destination = GreenNotePage(); break;
        case 'directories': destination = DirectoriesPage(); break;
        case 'tasks': destination = TaskPage(); break;
        case 'tracking': destination = TrackingPage(); break;
        case 'data': destination = HistoryPage(); break;
        case 'green_note_history': destination = GreenNoteHistoryPage(); break;
        case 'control': destination = ControlPage(); break;
        default: return;
      }

      Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
    }
  }
  /////////////////////////////////////////////////////////////
  ////////////////////////// BUILD UI /////////////////////////
  /////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: SafeArea(
          child: Column(
            children: [
              // Top Icons Bar with Refresh and New Window Support
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icons row
                    Row(
                      children: topIcons.map((iconPath) {
                        return GestureDetector(
                          onTap: () => _openPage(iconPath, newWindow: false),
                          onSecondaryTap: () => _openPage(iconPath, newWindow: true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Image.asset(iconPath, height: 32),
                          ),
                        );
                      }).toList(),
                    ),
                    // Refresh button
                    IconButton(
                      icon: Icon(Icons.refresh),
                      tooltip: 'רענון נתונים',
                      onPressed: _loadPinnedFiles,
                    ),
                  ],
                ),
              ),
              // Main Note Area + Save Button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Expanded(
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
                      SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.teal.shade900,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _saveToFile,
                        child: Text('שמירה לקובץ', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),

              // Pinned Files Bar
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
                                    topicId: file['topic_id'],
                                    section: file['section'],
                                    fileName: file['file'],
                                  ),
                                ),
                              );
                              _loadPinnedFiles();
                            },
                            onSecondaryTapDown: (details) {
                              _showContextMenu(details.globalPosition, file);
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
