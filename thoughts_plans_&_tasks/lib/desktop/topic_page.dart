import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'section_file_page.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

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
  bool isFlatView = false;
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
          isFlatView = data['flat'] ?? false;
          final baseColor = Color(data['color']);
          final hsl = HSLColor.fromColor(baseColor);
          backgroundColor = hsl.withLightness((hsl.lightness + 0.6).clamp(0.75, 0.92)).toColor();
        });
      }
    } catch (e) {
      print('Failed to load topic details: $e');
    }
  }

  Future<void> _toggleFlatView() async {
    setState(() => isFlatView = !isFlatView);
    try {
      await http.post(
        Uri.parse('$backendUrl/toggle_flat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic_id': widget.topicId, 'flat': isFlatView}),
      );
    } catch (e) {
      print('Failed to toggle flat view: $e');
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

  void _showFileNameDialog({required String section, String? oldName}) {
    final controller = TextEditingController(text: oldName ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          oldName == null ? 'שם קובץ חדש' : 'ערוך שם קובץ',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
          decoration: InputDecoration(
            hintText: 'שם הקובץ',
            hintTextDirection: TextDirection.rtl,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('שמור')),
        ],
      ),
    ).then((fileName) async {
      if (fileName == null || fileName.isEmpty) return;
      if (oldName == null) {
        final body = {'topic_id': widget.topicId, 'section': section, 'name': fileName};
        try {
          final res = await http.post(
            Uri.parse('$backendUrl/files/add'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );
          if (res.statusCode == 200) {
            setState(() {
              if (section == 'plans') plansFiles.add(fileName);
              if (section == 'tasks') tasksFiles.add(fileName);
              if (section == 'docs') docsFiles.add(fileName);
            });
          }
        } catch (e) {
          print('Failed to add file: $e');
        }
      } else {
        final body = {'topic_id': widget.topicId, 'section': section, 'old_name': oldName, 'new_name': fileName};
        try {
          final res = await http.post(
            Uri.parse('$backendUrl/files/rename'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );
          if (res.statusCode == 200) {
            setState(() {
              if (section == 'plans') {
                plansFiles.remove(oldName);
                plansFiles.add(fileName);
              }
              if (section == 'tasks') {
                tasksFiles.remove(oldName);
                tasksFiles.add(fileName);
              }
              if (section == 'docs') {
                docsFiles.remove(oldName);
                docsFiles.add(fileName);
              }
            });
          }
        } catch (e) {
          print('Failed to rename file: $e');
        }
      }
    });
  }

  void _deleteFile(String section, String fileName) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/files/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic_id': widget.topicId, 'name': fileName}),
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
                  onPressed: () => _showFileNameDialog(section: section),
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
                          PopupMenuItem(value: 'new_window', child: Text('פתח בחלון חדש')),
                          PopupMenuItem(value: 'edit', child: Text('ערוך')),
                          PopupMenuItem(value: 'delete', child: Text('מחק')),
                        ],
                      );
                      if (selected == 'edit') _showFileNameDialog(section: section, oldName: files[index]);
                      if (selected == 'delete') _deleteFile(section, files[index]);
                      if (selected == 'new_window') {
                        final window = await DesktopMultiWindow.createWindow(jsonEncode({
                          'page': 'file',
                          'topicId': widget.topicId,
                          'section': section,
                          'fileName': files[index],
                        }));
                        window
                          ..setFrame(const Offset(200, 200) & const Size(800, 600))
                          ..setTitle(files[index])
                          ..show();
                      }
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

  Widget _buildFlatView() {
    final allFiles = [
      ...plansFiles.map((f) => {'name': f, 'section': 'plans'}),
      ...tasksFiles.map((f) => {'name': f, 'section': 'tasks'}),
      ...docsFiles.map((f) => {'name': f, 'section': 'docs'}),
    ];

    return Expanded(
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text('קבצים', style: TextStyle(fontWeight: FontWeight.bold)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _showFileNameDialog(section: 'tasks'),
                ),
              ],
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: allFiles.length,
                itemBuilder: (context, index) {
                  final file = allFiles[index];
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
                          PopupMenuItem(value: 'edit', child: Text('ערוך')),
                          PopupMenuItem(value: 'delete', child: Text('מחק')),
                        ],
                      );
                      if (selected == 'edit') _showFileNameDialog(section: file['section'] as String, oldName: file['name'] as String);
                      if (selected == 'delete') _deleteFile(file['section'] as String, file['name'] as String);
                    },
                    child: ListTile(
                      title: Text(file['name'] as String),
                      onTap: () => _openFile(file['section'] as String, file['name'] as String),
                    ),
                  );
                },
              ),
            )
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
        appBar: AppBar(
          title: Text(topicName),
          actions: [
            IconButton(
              icon: Icon(isFlatView ? Icons.view_column : Icons.view_agenda),
              tooltip: isFlatView ? 'הצג לפי קטגוריות' : 'הצג כרשימה אחת',
              onPressed: _toggleFlatView,
            )
          ],
        ),
        body: Column(
          children: isFlatView
              ? [_buildFlatView()]
              : [
                  _buildSection("תוכניות", plansFiles, 'plans'),
                  _buildSection("משימות", tasksFiles, 'tasks'),
                  _buildSection("תיעוד", docsFiles, 'docs'),
                ],
        ),
      ),
    );
  }
}
