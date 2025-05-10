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

  Future<void> _addUnclassifiedTask() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('הוסף משימה'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'כתוב את המשימה'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('הוסף')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await http.post(
        Uri.parse('$backendUrl/add_unclassified'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': result}),
      );
      _loadTasks();
    }
  }


  Future<void> _moveTask(Map<String, dynamic> task, String toSection, int newOrder) async {
    final fromSection = task['section'];

    if (fromSection != toSection){
      if (fromSection == 'לא ממוין' || toSection == 'לא ממוין') {
        return;
      }
    }

    setState(() {
      sectionTasks[fromSection]?.remove(task);
      final targetList = sectionTasks[toSection]!;
      final clampedIndex = newOrder.clamp(0, targetList.length);
      targetList.insert(clampedIndex, task);
      task['section'] = toSection;
    });

    if (toSection == 'לא ממוין') {
      final reordered = sectionTasks['לא ממוין']!
          .asMap()
          .entries
          .map((entry) => {
            'content': entry.value['content'],
            'order': entry.key,
          })
          .toList();

      await http.post(
        Uri.parse('$backendUrl/reorder_unclassified'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tasks': reordered}),
      );
    } else {
      final reordered = sectionTasks[toSection]!
          .asMap()
          .entries
          .map((entry) => {
            'topic_id': entry.value['topic_id'],
            'file_name': entry.value['file_name'],
            'order': entry.key,
            'section': toSection,
          })
          .toList();

      await http.post(
        Uri.parse('$backendUrl/reorder_task'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tasks': reordered}),
      );
    }
  }

  void _showTaskContextMenu(Offset position, Map task) async {
    final selected = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'delete', child: Text('מחק')),
        PopupMenuItem(value: 'new_window', child: Text('פתח בחלון חדש')),
      ],
    );

    if (selected == 'delete') {
      final section = task['section'];
      if (section == 'לא ממוין') {
        await http.post(
          Uri.parse('$backendUrl/delete_unclassified'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'content': task['content']}),
        );
      } else {
        await http.post(
          Uri.parse('$backendUrl/delete_task_and_file'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'topic_id': task['topic_id'],
            'file_name': task['file_name'],
          }),
        );
      }
      _loadTasks();
    }
  }


  Widget _buildTaskTile(Map<String, dynamic> task) {
    final color = topicColors[task['topic_id']] ?? Colors.teal;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showTaskContextMenu(details.globalPosition, task),
        child: ListTile(
          tileColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            task['content'] ?? task['file_name'],
            style: TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
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
                padding: const EdgeInsets.all(6.0),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(section, style: TextStyle(fontWeight: FontWeight.bold)),
                            if (section == 'לא ממוין')
                              IconButton(
                                icon: Icon(Icons.add),
                                iconSize: 20,
                                padding: EdgeInsets.all(2.0),
                                constraints: BoxConstraints(),
                                onPressed: _addUnclassifiedTask,
                                tooltip: 'הוסף משימה',
                              ),
                          ],
                        ),
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
