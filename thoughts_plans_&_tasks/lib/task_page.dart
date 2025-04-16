import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'topic_manager.dart';
import 'section_file_page.dart';

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  Map<String, List<String>> sections = {
    'השבוע': [],
    'שבוע הבא': [],
    'בעתיד': [],
  };
  Map<String, Color> fileColors = {};
  Map<String, bool> calendarMarks = {};

  @override
  void initState() {
    super.initState();
    _loadAllTaskFiles();
  }

  void _loadAllTaskFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, List<String>> tempMap = {
      'השבוע': [],
      'שבוע הבא': [],
      'בעתיד': [],
    };
    Map<String, Color> tempColors = {};
    Map<String, bool> tempMarks = {};

    for (var topic in TopicManager.topics) {
      final topicName = topic['name'];
      final color = topic['color'] as Color;
      final key = '${topicName}_tasks';
      final stored = prefs.getString(key);
      if (stored != null) {
        final files = List<String>.from(jsonDecode(stored));
        for (var file in files) {
          final fullName = '$topicName::$file';
          tempMap['בעתיד']!.add(fullName);
          tempColors[fullName] = color;
          tempMarks[fullName] = false;
        }
      }
    }

    setState(() {
      sections = tempMap;
      fileColors = tempColors;
      calendarMarks = tempMarks;
    });
  }

  void _moveTask(String fromSection, String toSection, String file, [int? index]) {
    setState(() {
      sections[fromSection]!.remove(file);
      if (index != null) {
        sections[toSection]!.insert(index, file);
      } else {
        sections[toSection]!.add(file);
      }
    });
  }

  void _handleRightClick(BuildContext context, String section, String file) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: [
        PopupMenuItem(value: 'daily', child: Text('העבר למשימות יומיות')),
        PopupMenuItem(value: 'finish', child: Text('סיים משימה')),
      ],
    );

    if (selected == 'daily') {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> daily = prefs.getStringList('todayTasks') ?? [];
      if (!daily.contains(file)) {
        daily.add(file);
        await prefs.setStringList('todayTasks', daily);
        final color = fileColors[file];
        if (color != null) {
          final colorMap = prefs.getString('todayTaskColors');
          Map<String, dynamic> decoded = colorMap != null ? jsonDecode(colorMap) : {};
          decoded[file] = color.value;
          await prefs.setString('todayTaskColors', jsonEncode(decoded));
        }
      }
    }

    if (selected == 'finish') {
      setState(() {
        sections.forEach((key, list) => list.remove(file));
      });

      final parts = file.split('::');
      final topic = parts[0];
      final fileName = parts[1];
      final key = '${topic}_tasks';
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      if (stored != null) {
        final files = List<String>.from(jsonDecode(stored));
        files.remove(fileName);
        await prefs.setString(key, jsonEncode(files));
      }

      List<String> daily = prefs.getStringList('todayTasks') ?? [];
      daily.remove(file);
      await prefs.setStringList('todayTasks', daily);
    }
  }

  Widget _buildTaskItem(String section, String file, int index) {
    return Draggable<Map<String, dynamic>>(
      data: {'from': section, 'file': file},
      feedback: Material(
        child: Container(
          padding: EdgeInsets.all(8),
          color: fileColors[file]?.withOpacity(0.8) ?? Colors.grey,
          child: Text(file.split('::')[1], style: TextStyle(color: Colors.white)),
        ),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (_) => true,
        onAccept: (data) => _moveTask(data['from'], section, data['file'], index),
        builder: (context, candidateData, rejectedData) => GestureDetector(
          onTap: () {
            final parts = file.split('::');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectionFilePage(
                  topicName: parts[0],
                  section: 'tasks',
                  fileName: parts[1],
                ),
              ),
            );
          },
          onSecondaryTap: () => _handleRightClick(context, section, file),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fileColors[file]?.withOpacity(0.2) ?? Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      calendarMarks[file] = !(calendarMarks[file] ?? false);
                    });
                  },
                  child: Icon(
                    calendarMarks[file] ?? false ? Icons.circle : Icons.circle_outlined,
                    size: 18,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.split('::')[1],
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionColumn(String title) {
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (_) => true,
      onAccept: (data) => _moveTask(data['from'], title, data['file']),
      builder: (context, candidateData, rejectedData) => Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...List.generate(
              sections[title]!.length,
              (index) => _buildTaskItem(title, sections[title]![index], index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(title: Text('משימות')),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildSectionColumn('השבוע'),
              _buildSectionColumn('שבוע הבא'),
              _buildSectionColumn('בעתיד'),
            ],
          ),
        ),
      ),
    );
  }
}
