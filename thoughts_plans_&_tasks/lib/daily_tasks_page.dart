import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'section_file_page.dart';

class DailyTasksPage extends StatefulWidget {
  @override
  _DailyTasksPageState createState() => _DailyTasksPageState();
}

class _DailyTasksPageState extends State<DailyTasksPage> {
  List<Map<String, dynamic>> constantTasks = [];
  List<Map<String, dynamic>> todayTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    try {
      final resToday = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/today_tasks'));
      final resConstant = await http.get(Uri.parse('https://thoughts-app-92lm.onrender.com/constant_tasks'));

      if (resToday.statusCode == 200 && resConstant.statusCode == 200) {
        final List todayData = jsonDecode(resToday.body);
        final List constantData = jsonDecode(resConstant.body);
        setState(() {
          todayTasks = List<Map<String, dynamic>>.from(todayData);
          constantTasks = List<Map<String, dynamic>>.from(constantData);
        });
      } else {
        print('Failed to load tasks. Today: ${resToday.statusCode}, Constant: ${resConstant.statusCode}');
      }
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  void _showTaskOptions(Map<String, dynamic> task, bool isConstant) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: [
        PopupMenuItem(value: 'finish', child: Text('סיים משימה')),
        PopupMenuItem(value: 'remove', child: Text('הסר')),
      ],
    );

    if (action == 'finish' || action == 'remove') {
      try {
        await http.post(
          Uri.parse('https://thoughts-app-92lm.onrender.com/remove_task'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'task_id': task['id'], 'is_constant': isConstant}),
        );
        _loadTasks();
      } catch (e) {
        print('Failed to update task status: $e');
      }
    }
  }

  Widget _buildTask(Map<String, dynamic> task, bool isConstant) {
    return GestureDetector(
      onSecondaryTap: () => _showTaskOptions(task, isConstant),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(task['color']).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              task['is_done'] ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(task['name'])),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableTodayTasks() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex--;
        final item = todayTasks.removeAt(oldIndex);
        todayTasks.insert(newIndex, item);

        final orderUpdate = todayTasks
            .asMap()
            .entries
            .map((e) => {'id': e.value['id'], 'order': e.key})
            .toList();

        await http.post(
          Uri.parse('https://thoughts-app-92lm.onrender.com/update_today_task_order'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'updates': orderUpdate}),
        );

        setState(() {});
      },
      children: [
        for (int i = 0; i < todayTasks.length; i++)
          ListTile(
            key: ValueKey(todayTasks[i]['id']),
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
              ),
              ...constantTasks.map((task) => _buildTask(task, true)).toList(),
              Divider(),
              ListTile(
                title: Text('משימות להיום', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildReorderableTodayTasks(),
            ],
          ),
        ),
      ),
    );
  }
}
