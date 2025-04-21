import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'section_file_page.dart';

class TopicPage extends StatefulWidget {
  final int topicId;

  TopicPage({required this.topicId});

  @override
  _TopicPageState createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  List<String> plansFiles = [];
  List<String> tasksFiles = [];
  List<String> docsFiles = [];
  Color? backgroundColor;
  String topicName = '';
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadTopicDetails();
    _loadFiles();
  }

  Future<void> _loadTopicDetails() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/topic_details/${widget.topicId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          topicName = data['name'];
          final baseColor = Color(data['color']);
          final hsl = HSLColor.fromColor(baseColor);
          backgroundColor = hsl.withLightness((hsl.lightness + 0.6).clamp(0.75, 0.92)).toColor();
        });
      }
    } catch (e) {
      print('Failed to load topic details: $e');
    }
  }

  Future<void> _loadFiles() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/files/${widget.topicId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          plansFiles = List<String>.from(data['plans'] ?? []);
          tasksFiles = List<String>.from(data['tasks'] ?? []);
          docsFiles = List<String>.from(data['docs'] ?? []);
        });
      }
    } catch (e) {
      print('Failed to load files: $e');
    }
  }

  void _addFile(String section) {
    String fileName = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('שם קובץ חדש'),
        content: TextField(
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(hintText: 'שם הקובץ'),
          onChanged: (value) => fileName = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
            onPressed: () async {
              if (fileName.trim().isEmpty) return;
              Navigator.pop(context);
              final body = {
                'topic_id': widget.topicId,
                'section': section,
                'name': fileName.trim()
              };
              try {
                final res = await http.post(
                  Uri.parse('$backendUrl/files/add'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                );
                if (res.statusCode == 200) {
                  setState(() {
                    if (section == 'plans') plansFiles.add(fileName.trim());
                    if (section == 'tasks') tasksFiles.add(fileName.trim());
                    if (section == 'docs') docsFiles.add(fileName.trim());
                  });
                }
              } catch (e) {
                print('Failed to add file: $e');
              }
            },
            child: Text('צור'),
          ),
        ],
      ),
    );
  }

  void _deleteFile(String section, String fileName) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/files/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic_id': widget.topicId,
          'name': fileName
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          if (section == 'plans') plansFiles.remove(fileName);
          if (section == 'tasks') tasksFiles.remove(fileName);
          if (section == 'docs') docsFiles.remove(fileName);
        });
      }
    } catch (e) {
      print('Failed to delete file: $e');
    }
  }

  void _openFile(String section, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionFilePage(
          topicId: widget.topicId,
          section: section,
          fileName: fileName,
        ),
      ),
    );
  }

  Widget _buildSection(String label, List<String> files, String section) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addFile(section),
                )
              ],
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onSecondaryTapDown: (details) async {
                      final selected = await showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          details.globalPosition.dx,
                          details.globalPosition.dy,
                          0,
                          0,
                        ),
                        items: [
                          PopupMenuItem(value: 'delete', child: Text('מחק')),
                        ],
                      );

                      if (selected == 'delete') _deleteFile(section, files[index]);
                    },
                    child: ListTile(
                      title: Text(files[index]),
                      onTap: () => _openFile(section, files[index]),
                    ),
                  );
                },
              ),
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
        backgroundColor: backgroundColor ?? Colors.white,
        appBar: AppBar(title: Text(topicName)),
        body: Column(
          children: [
            _buildSection("תוכניות", plansFiles, 'plans'),
            _buildSection("משימות", tasksFiles, 'tasks'),
            _buildSection("תיעוד", docsFiles, 'docs'),
          ],
        ),
      ),
    );
  }
}
