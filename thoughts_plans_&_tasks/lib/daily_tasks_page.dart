import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'topic_manager.dart';
import 'section_file_page.dart';

class DailyTasksPage extends StatefulWidget {
  @override
  _DailyTasksPageState createState() => _DailyTasksPageState();
}

class _DailyTasksPageState extends State<DailyTasksPage> {
  List<String> constantTasks = [];
  List<String> todayTasks = [];
  Map<String, Color> taskColors = {};
  Set<String> finishedConstantToday = {};

  String get todayKey => 'finished_constant_tasks_${DateTime.now().toIso8601String().split('T').first}';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      constantTasks = prefs.getStringList('constantTasks') ?? [];
      todayTasks = prefs.getStringList('todayTasks') ?? [];
      final colors = prefs.getString('todayTaskColors');
      if (colors != null) {
        taskColors = Map<String, Color>.from(
          jsonDecode(colors).map((k, v) => MapEntry(k, Color(v))),
        );
      }
      finishedConstantToday = prefs.getStringList(todayKey)?.toSet() ?? {};
    });
  }

  void _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('constantTasks', constantTasks);
    await prefs.setStringList('todayTasks', todayTasks);
    await prefs.setString(
      'todayTaskColors',
      jsonEncode(taskColors.map((k, v) => MapEntry(k, v.value))),
    );
    await prefs.setStringList(todayKey, finishedConstantToday.toList());
  }

  void _addTask(bool isConstant) {
    String newTask = '';
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('הוסף משימה חדשה'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          autofocus: true,
          onChanged: (value) => newTask = value,
          onSubmitted: (_) {
            Navigator.of(context).pop();
            if (newTask.trim().isNotEmpty) {
              setState(() {
                if (isConstant) {
                  constantTasks.add(newTask.trim());
                } else {
                  todayTasks.add(newTask.trim());
                }
              });
              _saveTasks();
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (newTask.trim().isNotEmpty) {
                setState(() {
                  if (isConstant) {
                    constantTasks.add(newTask.trim());
                  } else {
                    todayTasks.add(newTask.trim());
                  }
                });
                _saveTasks();
              }
            },
            child: Text('הוסף'),
          ),
        ],
      ),
    );
  }

  void _showTaskOptions(String task, bool isConstant) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: isConstant
          ? [
              PopupMenuItem(value: 'hide', child: Text('סיים משימה')),
              PopupMenuItem(value: 'delete', child: Text('מחק משימה')),
            ]
          : [
              PopupMenuItem(value: 'finish', child: Text('סיים משימה')),
              PopupMenuItem(value: 'remove', child: Text('הסר מהיומי')),
            ],
    );

    final prefs = await SharedPreferences.getInstance();

    if (action == 'hide') {
      setState(() {
        finishedConstantToday.add(task);
      });
    } else if (action == 'delete') {
      setState(() {
        constantTasks.remove(task);
      });
    } else if (action == 'finish') {
      setState(() {
        todayTasks.remove(task);
      });
      final parts = task.split('::');
      if (parts.length == 2) {
        final topic = parts[0];
        final fileName = parts[1];
        final key = '${topic}_tasks';
        final stored = prefs.getString(key);
        if (stored != null) {
          final files = List<String>.from(jsonDecode(stored));
          files.remove(fileName);
          await prefs.setString(key, jsonEncode(files));
        }
      }
    } else if (action == 'remove') {
      setState(() {
        todayTasks.remove(task);
      });
    }
    _saveTasks();
  }

  Widget _buildTask(String task, bool isConstant) {
    return GestureDetector(
      onSecondaryTap: () => _showTaskOptions(task, isConstant),
      onTap: () {
        if (!isConstant && task.contains('::')) {
          final parts = task.split('::');
          final topic = parts[0];
          final fileName = parts[1];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionFilePage(
                topicName: topic,
                section: 'tasks',
                fileName: fileName,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: taskColors[task]?.withOpacity(0.2) ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.radio_button_unchecked, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(task.split('::').last)),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableTodayTasks() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = todayTasks.removeAt(oldIndex);
          todayTasks.insert(newIndex, item);
          _saveTasks();
        });
      },
      children: [
        for (int i = 0; i < todayTasks.length; i++)
          ListTile(
            key: ValueKey(todayTasks[i]),
            title: _buildTask(todayTasks[i], false),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('משימות יומיות')),
        backgroundColor: Colors.teal.shade50,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text('משימות קבועות', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTask(true),
                ),
              ),
              ...constantTasks.where((t) => !finishedConstantToday.contains(t)).map((task) => _buildTask(task, true)).toList(),
              Divider(),
              ListTile(
                title: Text('משימות להיום', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTask(false),
                ),
              ),
              _buildReorderableTodayTasks(),
            ],
          ),
        ),
      ),
    );
  }
}
