import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'topic_manager.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({Key? key}) : super(key: key);

  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  List<Map<String, dynamic>> documentingFiles = [];
  List<Map<String, dynamic>> planningFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final docs = prefs.getString('control_docs');
    final plans = prefs.getString('control_plans');

    setState(() {
      documentingFiles = docs != null
          ? List<Map<String, dynamic>>.from(jsonDecode(docs))
          : [];

      planningFiles = plans != null
          ? List<Map<String, dynamic>>.from(jsonDecode(plans))
          : [];
    });
  }

  Color _getTopicColor(String topicName) {
    final match = TopicManager.topics.firstWhere(
      (t) => t['name'] == topicName,
      orElse: () => {'color': Colors.teal},
    );
    return (match['color'] as Color).withOpacity(0.6);
  }

  void _removeFromList(String section, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final key = section == 'docs' ? 'control_docs' : 'control_plans';
    List list = section == 'docs' ? documentingFiles : planningFiles;

    list.removeAt(index);
    await prefs.setString(key, jsonEncode(list));
    setState(() {});
  }

  void _showContextMenu(BuildContext context, Offset position, String section, int index) async {
    final selected = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(value: 'remove', child: Text('הסר מהרשימה')),
      ],
    );

    if (selected == 'remove') {
      _removeFromList(section, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(
          title: const Text('דף בקרה'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'רשימות תיעוד',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView(
                  onReorder: _onReorderDocumenting,
                  children: List.generate(documentingFiles.length, (index) {
                    final file = documentingFiles[index];
                    return GestureDetector(
                      key: ValueKey(file['file']),
                      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, 'docs', index),
                      child: ListTile(
                        tileColor: _getTopicColor(file['topic']),
                        title: Text(
                          file['file'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          file['topic'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'רשימות תכנון',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView(
                  onReorder: _onReorderPlanning,
                  children: List.generate(planningFiles.length, (index) {
                    final file = planningFiles[index];
                    return GestureDetector(
                      key: ValueKey(file['file']),
                      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition, 'plans', index),
                      child: ListTile(
                        tileColor: _getTopicColor(file['topic']),
                        title: Text(
                          file['file'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          file['topic'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onReorderDocumenting(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > documentingFiles.length) newIndex = documentingFiles.length;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = documentingFiles.removeAt(oldIndex);
      documentingFiles.insert(newIndex, item);
    });
  }

  void _onReorderPlanning(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > planningFiles.length) newIndex = planningFiles.length;
      if (oldIndex < newIndex) newIndex -= 1;
      final item = planningFiles.removeAt(oldIndex);
      planningFiles.insert(newIndex, item);
    });
  }
}
