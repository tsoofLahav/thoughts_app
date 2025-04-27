import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SectionFilePage extends StatefulWidget {
  final int topicId;
  final String section;
  final String fileName;

  SectionFilePage({
    required this.topicId,
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
  bool isLinked = false;
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/file_info?topic_id=${widget.topicId}&file_name=${widget.fileName}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          content = data['content'] ?? [];
          isLinked = data['linked'] ?? false;
        });
      }
    } catch (e) {
      print('Failed to load file info: $e');
    }

    try {
      final res = await http.get(Uri.parse('$backendUrl/topic_details/${widget.topicId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final colorValue = data['color'];
        topicName = data['name'];
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

  Future<void> _saveContent() async {
    final body = {
      'topic_id': widget.topicId,
      'name': widget.fileName,
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
    setState(() {});
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  void _removeEntry(int index) {
    setState(() {
      content.removeAt(index);
    });
  }

  void _toggleDone(int index) {
    setState(() {
      content[index]['done'] = !(content[index]['done'] ?? false);
    });
  }

  Future<void> _toggleLink() async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/file_link/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic_id': widget.topicId,
          'name': widget.fileName,
        }),
      );
      if (res.statusCode == 200) {
        setState(() {
          isLinked = !isLinked;
        });
      }
    } catch (e) {
      print('Failed to toggle link: $e');
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
          final entry = content[i];
          final text = entry is String ? entry : (entry['text'] ?? '');
          final prefix = useNumbers ? '${i + 1}.' : '•';
          return ListTile(
            title: Text('$prefix $text'),
            trailing: IconButton(icon: Icon(Icons.delete), onPressed: () => _removeEntry(i)),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _saveContent();
    super.dispose();
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
              icon: Icon(isLinked ? Icons.link_off : Icons.link),
              tooltip: isLinked ? 'הסר משורת קיצורים' : 'הצמד לשורת קיצורים',
              onPressed: _toggleLink,
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadMetadata,
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
