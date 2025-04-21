import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SectionFilePage extends StatefulWidget {
  final int fileId;
  final String section;
  final String fileName;

  SectionFilePage({
    required this.fileId,
    required this.section,
    required this.fileName,
  });

  @override
  _SectionFilePageState createState() => _SectionFilePageState();
}

class _SectionFilePageState extends State<SectionFilePage> {
  List<dynamic> content = [];
  bool useNumbers = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  Color? appBarColor;
  String topicName = '';
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadTopicDetails();
    _loadContent();
  }

  Future<void> _loadTopicDetails() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/file_metadata/${widget.fileId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colorValue = data['color'];
        topicName = data['topic_name'];
        final baseColor = Color(colorValue);
        final hsl = HSLColor.fromColor(baseColor);
        setState(() {
          appBarColor = hsl.withLightness((hsl.lightness + 0.5).clamp(0.7, 0.9)).toColor();
        });
      }
    } catch (e) {
      print('Failed to load topic details: $e');
    }
  }

  Future<void> _loadContent() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/file_content/${widget.fileId}'));
      if (res.statusCode == 200) {
        setState(() {
          content = jsonDecode(res.body);
        });
      }
    } catch (e) {
      print('Failed to load content: $e');
    }
  }

  Future<void> _saveContent() async {
    final body = {
      'file_id': widget.fileId,
      'section': widget.section,
      'content': content,
    };

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/file_content'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      print('Saved file (status: ${res.statusCode})');
    } catch (e) {
      print('Failed to save content: $e');
    }
  }

  void _addEntry(String value) {
    if (value.isEmpty) return;
    if (widget.section == 'docs') {
      final now = DateTime.now();
      content.add({'text': value, 'date': now.toString().split(' ').first});
    } else if (widget.section == 'tasks') {
      content.add({'text': value, 'done': false});
    } else {
      content.add(value);
    }
    _textController.clear();
    _saveContent();
    setState(() {});
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  void _removeEntry(int index) async {
    setState(() {
      content.removeAt(index);
    });
    _saveContent();
  }

  void _toggleDone(int index) {
    setState(() {
      content[index]['done'] = !(content[index]['done'] ?? false);
    });
    _saveContent();
  }

  Future<void> _linkFile() async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/link_file'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'file_id': widget.fileId}),
      );
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('הקובץ נשלח לשורת קיצורים')));
      }
    } catch (e) {
      print('Failed to link file: $e');
    }
  }

  Widget _buildInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _inputFocusNode,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(hintText: 'הוסף תוכן...'),
            onSubmitted: _addEntry,
          ),
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: () => _addEntry(_textController.text.trim()),
        ),
        if (widget.section == 'plans')
          Switch(
            value: useNumbers,
            onChanged: (val) => setState(() => useNumbers = val),
          )
      ],
    );
  }

  Widget _buildContent() {
    if (widget.section == 'docs') {
      return ListView.builder(
        itemCount: content.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(content[i]['text']),
          subtitle: Text(content[i]['date']),
          trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => _removeEntry(i)),
        ),
      );
    } else if (widget.section == 'tasks') {
      return ListView.builder(
        itemCount: content.length,
        itemBuilder: (_, i) {
          final task = content[i];
          final isDone = task['done'] == true;
          return GestureDetector(
            onTap: () => _toggleDone(i),
            onSecondaryTap: () => _removeEntry(i),
            child: ListTile(
              title: Text(
                task['text'],
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : null,
                ),
              ),
              trailing: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? Colors.green : null,
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: content.length,
        itemBuilder: (_, i) {
          final prefix = useNumbers ? '${i + 1}.' : '•';
          return ListTile(
            title: Text('$prefix ${content[i]}'),
            trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => _removeEntry(i)),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.fileName} - $topicName'),
          backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
          actions: [
            IconButton(
              icon: Icon(Icons.link),
              tooltip: 'הצמד לשורת קיצורים',
              onPressed: _linkFile,
            )
          ],
        ),
        body: Column(
          children: [
            _buildInput(),
            Divider(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}
