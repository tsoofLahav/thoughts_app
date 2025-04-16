import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'section_file_page.dart';
import 'topic_manager.dart';

class TopicPage extends StatefulWidget {
  final String name;

  TopicPage({required this.name});

  @override
  _TopicPageState createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  List<String> plansFiles = [];
  List<String> tasksFiles = [];
  List<String> docsFiles = [];
  Color? backgroundColor;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadTopicColor();
  }

  void _loadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      plansFiles = _getList(prefs, 'plans');
      tasksFiles = _getList(prefs, 'tasks');
      docsFiles = _getList(prefs, 'docs');
    });
  }

  void _loadTopicColor() {
    final topic = TopicManager.topics.firstWhere(
      (t) => t['name'] == widget.name,
      orElse: () => {'color': Colors.white},
    );
    final baseColor = topic['color'] as Color;
    final hsl = HSLColor.fromColor(baseColor);
    backgroundColor = hsl.withLightness((hsl.lightness + 0.6).clamp(0.75, 0.92)).toColor();
  }

  List<String> _getList(SharedPreferences prefs, String section) {
    final key = '${widget.name}_$section';
    final stored = prefs.getString(key);
    if (stored != null) {
      return List<String>.from(jsonDecode(stored));
    }
    return [];
  }

  void _saveFiles(String section) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list;
    switch (section) {
      case 'plans':
        list = plansFiles;
        break;
      case 'tasks':
        list = tasksFiles;
        break;
      case 'docs':
        list = docsFiles;
        break;
      default:
        list = [];
    }
    await prefs.setString('${widget.name}_$section', jsonEncode(list));
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
          onSubmitted: (_) {
            if (fileName.trim().isEmpty) return;
            Navigator.pop(context);
            setState(() {
              _addToList(section, fileName.trim());
            });
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
              onPressed: () {
                if (fileName.trim().isEmpty) return;
                Navigator.pop(context);
                setState(() {
                  _addToList(section, fileName.trim());
                });
              },
              child: Text('צור')),
        ],
      ),
    );
  }

  void _addToList(String section, String fileName) {
    if (section == 'plans') plansFiles.add(fileName);
    if (section == 'tasks') tasksFiles.add(fileName);
    if (section == 'docs') docsFiles.add(fileName);
    _saveFiles(section);
  }

  void _editFile(String section, int index, String oldName) {
    String newName = oldName;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ערוך שם הקובץ'),
        content: TextField(
          textDirection: TextDirection.rtl,
          controller: TextEditingController(text: oldName),
          onChanged: (value) => newName = value,
          onSubmitted: (_) {
            if (newName.trim().isEmpty) return;
            _renameFile(section, index, newName.trim());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
              onPressed: () {
                if (newName.trim().isEmpty) return;
                _renameFile(section, index, newName.trim());
                Navigator.pop(context);
              },
              child: Text('שמור')),
        ],
      ),
    );
  }

  void _openFile(String section, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionFilePage(
          topicName: widget.name,
          section: section,
          fileName: fileName,
        ),
      ),
    );
  }


  void _renameFile(String section, int index, String newName) {
    setState(() {
      if (section == 'plans') plansFiles[index] = newName;
      if (section == 'tasks') tasksFiles[index] = newName;
      if (section == 'docs') docsFiles[index] = newName;
    });
    _saveFiles(section);
  }

  void _deleteFile(String section, int index) {
    setState(() {
      if (section == 'plans') plansFiles.removeAt(index);
      if (section == 'tasks') tasksFiles.removeAt(index);
      if (section == 'docs') docsFiles.removeAt(index);
    });
    _saveFiles(section);
  }

  Widget _buildSection(String label, List<String> files, String key) {
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
                  onPressed: () => _addFile(key),
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
                          PopupMenuItem(value: 'rename', child: Text('שנה שם')),
                          PopupMenuItem(value: 'delete', child: Text('מחק')),
                        ],
                      );

                      if (selected == 'rename') _editFile(key, index, files[index]);
                      if (selected == 'delete') _deleteFile(key, index);
                    },
                    child: ListTile(
                      title: Text(files[index]),
                      onTap: () => _openFile(key, files[index]),
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
        appBar: AppBar(title: Text(widget.name)),
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
