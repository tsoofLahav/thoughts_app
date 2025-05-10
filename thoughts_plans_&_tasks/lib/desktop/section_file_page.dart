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
    print('[SectionFilePage] initState: topicId=${widget.topicId}, fileName=${widget.fileName}, section=${widget.section}');
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
      content.add({'text': value}); // ✅ instead of just adding 'value'
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
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        setState(() {
          final item = content.removeAt(oldIndex);
          content.insert(newIndex, item);
        });
      },
      children: [
        for (int i = 0; i < content.length; i++)
          Container(
            key: ValueKey(content[i]),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  (widget.section == 'plans')
                      ? (useNumbers ? '${i + 1}.' : '•')
                      : '•',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: content[i]['text'],
                        selection: TextSelection.collapsed(
                          offset: content[i]['text'].length,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      content[i]['text'] = val;
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      decoration: (widget.section == 'tasks' && content[i]['done'] == true)
                          ? TextDecoration.lineThrough
                          : null,
                      color: (widget.section == 'tasks' && content[i]['done'] == true)
                          ? Colors.grey
                          : null,
                    ),
                    onTap: () {
                      // Stop toggle-on-tap behavior
                    },
                  ),
                ),
                if (widget.section == 'docs')
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      content[i]['date'],
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (widget.section == 'tasks')
                  IconButton(
                    icon: Icon(
                      content[i]['done'] == true
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: content[i]['done'] == true ? Colors.green : null,
                    ),
                    onPressed: () {
                      setState(() {
                        content[i]['done'] = !(content[i]['done'] == true);
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _removeEntry(i),
                ),
              ],
            ),
          )
      ],
    );
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
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: AppBar(
            backgroundColor: appBarColor ?? Theme.of(context).primaryColor,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.fileName} - $topicName',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(isLinked ? Icons.link_off : Icons.link),
                  tooltip: isLinked ? 'הסר משורת קיצורים' : 'הצמד לשורת קיצורים',
                  onPressed: _toggleLink,
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _saveContent,
                ),
              ],
            ),
          ),
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
