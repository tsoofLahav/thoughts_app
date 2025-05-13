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
      final exists = sectionTasks['לא ממוין']!
          .any((t) => t['content'] == result);

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('המשימה כבר קיימת')),
        );
        return;
      }

      await http.post(
        Uri.parse('$backendUrl/add_unclassified'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': result}),
      );
      _loadTasks();
    }
  }


  Future<void> _moveTask(Map<String, dynamic> task, String toSection, int newOrder) async {
    if (task.containsKey('file_name')) {
      await _moveRegularTask(task, toSection, newOrder);
    } else {
      await _moveUnclassifiedTask(task, newOrder);
    }
  }

  Future<void> _moveRegularTask(Map<String, dynamic> task, String toSection, int newOrder) async {
    final fromSection = task['section'];

    setState(() {
      sectionTasks[fromSection]?.removeWhere((t) =>
        t['file_name'] == task['file_name'] &&
        t['topic_id'] == task['topic_id']
      );
      final targetList = sectionTasks[toSection]!;
      final clampedIndex = newOrder.clamp(0, targetList.length);
      targetList.insert(clampedIndex, task);
      task['section'] = toSection;
    });

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

  Future<void> _moveUnclassifiedTask(Map<String, dynamic> task, int newOrder) async {
    setState(() {
      sectionTasks['לא ממוין']?.removeWhere((t) => t['content'] == task['content']);
      final list = sectionTasks['לא ממוין']!;
      final clampedIndex = newOrder.clamp(0, list.length);
      list.insert(clampedIndex, task);
    });

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
      if (task.containsKey('file_name')) {
        // regular task → delete from both tables
        await http.post(
          Uri.parse('$backendUrl/delete_task_and_file'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'topic_id': task['topic_id'],
            'file_name': task['file_name'],
          }),
        );
      } else {
        // unclassified task
        await http.post(
          Uri.parse('$backendUrl/delete_unclassified'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'content': task['content'],
            'order': task['order'],
          }),
        );
      }
      _loadTasks();
    }
  }


  Widget _buildTaskTile(Map<String, dynamic> task) {
    final color = topicColors[task['topic_id']] ?? const Color.fromARGB(255, 164, 219, 213);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showTaskContextMenu(details.globalPosition, task),
        child: ListTile(
          tileColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            task['content'] ?? task['file_name'],
            style: TextStyle(color: const Color.fromARGB(255, 39, 39, 39), fontSize: 13),
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
        appBar: AppBar(
          title: Text(
            'משימות',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: sections.reversed.map((section) {
              final tasks = sectionTasks[section] ?? [];
              final isUnclassified = section == 'לא ממוין';

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.teal.shade200, width: 1), // ✅ separator line
                  ),
                ),
                padding: const EdgeInsets.all(6.0),
                child: SizedBox(
                  width: isUnclassified ? 200 : 160, // ✅ narrower for all except unclassified
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
                            if (isUnclassified)
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

                          final taskColor = isUnclassified
                            ? Colors.teal.shade200.withOpacity(0.7) // ✅ teal-grey frame for unclassified
                            : topicColors[task['topic_id']] ?? Colors.teal;

                          return DragTarget<Map<String, dynamic>>(
                            onWillAccept: (data) => true,
                            onAcceptWithDetails: (details) =>
                                _moveTask(details.data, section, index),
                            builder: (_, __, ___) => Draggable(
                              data: task,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: 180,
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: taskColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    task['content'] ?? task['file_name'],
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.5,
                                child: _buildTaskTile(task),
                              ),
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
