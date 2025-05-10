// TaskPage with draggable sections
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';
  final List<String> sections = ["בהמשך", "שבוע הבא", "השבוע", "היום", "לא ממוין"];
  Map<String, List<Map<String, dynamic>>> sectionTasks = {};
  Map<int, Color> topicColors = {}; // topic_id -> color

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    Map<String, List<Map<String, dynamic>>> result = {
      for (var s in sections) s: []
    };

    try {
      final unclassifiedRes = await http.get(Uri.parse('$backendUrl/unclassified_tasks'));
      if (unclassifiedRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(unclassifiedRes.body);
        result['לא ממוין'] = List<Map<String, dynamic>>.from(data);
      }

      final tasksRes = await http.get(Uri.parse('$backendUrl/tasks'));
      if (tasksRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(tasksRes.body);
        for (var task in data) {
          result[task['section']]?.add(task);
        }
      }

      for (var section in result.values) {
        for (var task in section) {
          int topicId = task['topic_id'];
          if (!topicColors.containsKey(topicId)) {
            final res = await http.get(Uri.parse('$backendUrl/topic_details/$topicId'));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              topicColors[topicId] = Color(data['color']);
            }
          }
        }
      }

      setState(() => sectionTasks = result);
    } catch (e) {
      print('Failed to load tasks: $e');
    }
  }

  Future<void> _moveTask(Map<String, dynamic> task, String toSection, int newOrder) async {
    setState(() {
      for (var list in sectionTasks.values) list.remove(task);
      sectionTasks[toSection]!.insert(newOrder, task);
      task['section'] = toSection;
    });

    if (toSection == 'לא ממוין') {
      await http.post(Uri.parse('$backendUrl/update_unclassified_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'content': task['content'],
          'order': newOrder,
        }));
    } else {
      await http.post(Uri.parse('$backendUrl/update_task'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic_id': task['topic_id'],
          'file_name': task['file_name'],
          'section': toSection,
          'order': newOrder,
        }));
    }
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final color = topicColors[task['topic_id']] ?? Colors.teal;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        tileColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          task['content'] ?? task['file_name'],
          style: TextStyle(color: Colors.white, fontSize: 13),
          overflow: TextOverflow.ellipsis,
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
        appBar: AppBar(title: Text('משימות', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: sections.reversed.map((section) {
              final tasks = sectionTasks[section] ?? [];
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 200,
                  child: DragTarget<Map<String, dynamic>>(
                    onWillAccept: (data) => true,
                    onAcceptWithDetails: (details) {
                      final task = details.data;
                      _moveTask(task, section, tasks.length);
                    },
                    builder: (context, _, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section, style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ...tasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return DragTarget<Map<String, dynamic>>(
                            onWillAccept: (data) => true,
                            onAcceptWithDetails: (details) => _moveTask(details.data, section, index),
                            builder: (_, __, ___) => Draggable(
                              data: task,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: 180,
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: topicColors[task['topic_id']] ?? Colors.teal, borderRadius: BorderRadius.circular(16)),
                                  child: Text(task['content'] ?? task['file_name'], style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.5, child: _buildTaskTile(task)),
                              child: _buildTaskTile(task),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
