import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'section_file_page.dart';

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  Map<String, List<Map<String, dynamic>>> sections = {
    'השבוע': [],
    'שבוע הבא': [],
    'בעתיד': [],
  };

  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadTasksFromDB();
  }

  Future<void> _loadTasksFromDB() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/task_files'));
      if (res.statusCode == 200) {
        final decoded = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        Map<String, List<Map<String, dynamic>>> temp = {
          'השבוע': [],
          'שבוע הבא': [],
          'בעתיד': [],
        };

        for (var file in decoded) {
          final section = file['section'] ?? 'בעתיד';
          temp[section]!.add(file);
        }

        setState(() {
          sections = temp;
        });
      }
    } catch (e) {
      print('Failed to load task files: $e');
    }
  }

  Future<void> _saveTasksToDB() async {
    List<Map<String, dynamic>> updated = [];
    sections.forEach((section, files) {
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        updated.add({
          'topic_id': file['topic_id'],
          'file_name': file['name'],
          'section': section,
          'order_index': i
        });
      }
    });

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/update_task_sections'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'updates': updated}),
      );
      print('Saved task sections (status: ${res.statusCode})');
    } catch (e) {
      print('Failed to save task sections: $e');
    }
  }

  void _moveTask(String from, String to, Map<String, dynamic> file, [int? index]) {
    setState(() {
      sections[from]!.remove(file);
      if (index != null) {
        sections[to]!.insert(index, file);
      } else {
        sections[to]!.add(file);
      }
    });
  }

  @override
  void dispose() {
    _saveTasksToDB();
    super.dispose();
  }

  Widget _buildTaskItem(String section, Map<String, dynamic> file, int index) {
    return Draggable<Map<String, dynamic>>(
      data: {'from': section, 'file': file},
      feedback: Material(
        child: Container(
          padding: EdgeInsets.all(8),
          color: file['color'] != null ? Color(file['color']).withOpacity(0.8) : Colors.grey,
          child: Text(file['name'], style: TextStyle(color: Colors.white)),
        ),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (_) => true,
        onAccept: (data) => _moveTask(data['from'], section, data['file'], index),
        builder: (context, _, __) => GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectionFilePage(
                  topicId: file['topic_id'],
                  section: 'tasks',
                  fileName: file['name'],
                ),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: file['color'] != null ? Color(file['color']).withOpacity(0.2) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(file['name'], style: TextStyle(fontSize: 16))),
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
      builder: (context, _, __) => Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey))),
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