import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SectionFilePage extends StatefulWidget {
  final String topicName;
  final String section;
  final String fileName;

  SectionFilePage({
    required this.topicName,
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
  late String storageKey;
  bool isPinned = false;

  @override
  void initState() {
    super.initState();
    storageKey =
        '${widget.topicName}_${widget.section}_${widget.fileName}'.replaceAll(' ', '_');
    _loadContent();
    _checkPinnedStatus();
    _updateControlPageList();
  }

  void _loadContent() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (stored != null) {
      final decoded = jsonDecode(stored);
      if (widget.section == 'tasks') {
        content = decoded.map((e) => e is Map ? e : {'text': e.toString(), 'done': false}).toList();
      } else {
        content = decoded;
      }
      setState(() {});
    }
  }

  void _saveContent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(content));
    _updateControlPageList();
  }

  Future<void> _updateControlPageList() async {
    if (widget.section != 'plans' && widget.section != 'docs') return;

    final prefs = await SharedPreferences.getInstance();
    final key = widget.section == 'plans' ? 'control_plans' : 'control_docs';
    List list = [];
    final stored = prefs.getString(key);
    if (stored != null) {
      list = jsonDecode(stored);
    }

    list.removeWhere((item) =>
      item['file'] == widget.fileName && item['topic'] == widget.topicName);

    list.add({
      'file': widget.fileName,
      'topic': widget.topicName,
      'color': await _getTopicColor(widget.topicName),
    });

    await prefs.setString(key, jsonEncode(list));
  }

  void _addEntry(String value) {
    if (value.isEmpty) return;
    if (widget.section == 'docs') {
      final now = DateTime.now();
      content.add({'text': value, 'date': now.toString().split(' ').first});
    } else if (widget.section == 'tasks') {
      content.add({'text': value, 'done': false});
    } else {
      content.add(value.toString());
    }
    _textController.clear();
    _saveContent();
    setState(() {});
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  void _removeEntry(int index) {
    content.removeAt(index);
    _saveContent();
    setState(() {});
  }

  void _toggleDone(int index) {
    setState(() {
      content[index]['done'] = !(content[index]['done'] ?? false);
    });
    _saveContent();
  }

  Future<int> _getTopicColor(String topicName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final colorData = prefs.getString('greenNoteColors');
    if (colorData != null) {
      final Map<String, dynamic> colors = jsonDecode(colorData);
      final raw = colors[topicName];
      if (raw is int) return raw;
    }
    return Colors.teal.value;
  }

  Future<void> _checkPinnedStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pinned_files');
    if (stored != null) {
      final List<dynamic> files = jsonDecode(stored);
      isPinned = files.any((item) =>
        item['topic'] == widget.topicName &&
        item['section'] == widget.section &&
        item['file'] == widget.fileName);
      setState(() {});
    }
  }

  void _togglePinStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('pinned_files');
    List<dynamic> pinned = stored != null ? jsonDecode(stored) : [];

    final current = {
      'topic': widget.topicName,
      'section': widget.section,
      'file': widget.fileName,
      'color': await _getTopicColor(widget.topicName),
    };

    final matchIndex = pinned.indexWhere((item) =>
      item['topic'] == current['topic'] &&
      item['section'] == current['section'] &&
      item['file'] == current['file']);

    if (matchIndex >= 0) {
      pinned.removeAt(matchIndex);
      isPinned = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הקובץ הוסר משורת הקיצורים')),
      );
    } else {
      pinned.add(current);
      isPinned = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הקובץ נשלח לשורת הקיצורים')),
      );
    }

    await prefs.setString('pinned_files', jsonEncode(pinned));
    setState(() {});
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
            onChanged: (val) {
              setState(() => useNumbers = val);
            },
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.section == 'docs') {
      return ListView.builder(
        itemCount: content.length,
        itemBuilder: (_, i) {
          final entry = content[i];
          return ListTile(
            title: Text(entry['text']),
            subtitle: Text(entry['date']),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeEntry(i),
            ),
          );
        },
      );
    }

    if (widget.section == 'tasks') {
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
    }

    if (widget.section == 'plans') {
      return ListView.builder(
        itemCount: content.length,
        itemBuilder: (_, i) {
          final prefix = useNumbers ? '${i + 1}.' : '•';
          final text = content[i] is String
              ? content[i]
              : (content[i] is Map ? content[i]['text'] ?? '' : content[i].toString());

          return ListTile(
            title: Text('$prefix $text'),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeEntry(i),
            ),
          );
        },
      );
    }

    return Text('לא נתמך');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.fileName} - ${widget.topicName}'),
          actions: [
            IconButton(
              icon: Icon(isPinned ? Icons.link_off : Icons.link),
              tooltip: isPinned ? 'הסר משורת קיצורים' : 'שלח לשורת הקיצורים',
              onPressed: _togglePinStatus,
            ),
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
