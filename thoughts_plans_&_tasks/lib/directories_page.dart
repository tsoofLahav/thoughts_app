import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'topic_page.dart';
import 'topic_manager.dart';
import 'package:flutter/gestures.dart';

class DirectoriesPage extends StatefulWidget {
  @override
  _DirectoriesPageState createState() => _DirectoriesPageState();
}

class _DirectoriesPageState extends State<DirectoriesPage> {
  Map<String, List<Map<String, dynamic>>> houses = {};
  List<String> houseNames = [];
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/directories'));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        houses = {
          for (var key in decoded.keys)
            key: List<Map<String, dynamic>>.from(decoded[key].map((e) => {
                  'name': e['name'],
                  'color': Color(e['color'])
                }))
        };
        houseNames = houses.keys.toList();
        TopicManager.topics = houses.values.expand((list) => list).toList();
        setState(() {});
      }
    } catch (e) {
      print('Failed to load directories: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final encoded = jsonEncode({
        for (var house in houses.keys)
          house: houses[house]!.map((t) => {
                'name': t['name'],
                'color': (t['color'] as Color).value,
              }).toList()
      });
      await http.post(Uri.parse('$backendUrl/directories'),
          headers: {'Content-Type': 'application/json'},
          body: encoded);
    } catch (e) {
      print('Failed to save directories: $e');
    }
  }

  void _addTopic() {
    String name = '';
    Color selectedColor = Colors.teal;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Align(alignment: Alignment.centerRight, child: Text('הוסף נושא חדש')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: 'שם הנושא'),
              onChanged: (value) => name = value,
              onSubmitted: (_) => _submitNewTopic(name, selectedColor),
            ),
            SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: Text('בחר צבע:')),
            MaterialPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => selectedColor = color,
              enableLabel: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(onPressed: () => _submitNewTopic(name, selectedColor), child: Text('אישור')),
        ],
      ),
    );
  }

  void _submitNewTopic(String name, Color color) async {
    if (name.trim().isNotEmpty) {
      houses.putIfAbsent('כללי', () => []);
      houses['כללי']!.add({'name': name.trim(), 'color': color});
      await _saveData();
      await _loadData(); // 🔄 reload from backend to reflect changes
      Navigator.pop(context);
    }
  }

  void _addHouse() {
    String houseName = '';
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Align(alignment: Alignment.centerRight, child: Text('הוסף בית חדש')),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(labelText: 'שם הבית'),
          onChanged: (val) => houseName = val,
          onSubmitted: (_) => _submitNewHouse(houseName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(onPressed: () => _submitNewHouse(houseName), child: Text('אישור')),
        ],
      ),
    );
  }

  void _submitNewHouse(String houseName) {
    if (houseName.trim().isNotEmpty && !houses.containsKey(houseName)) {
      setState(() {
        houses[houseName.trim()] = [];
        houseNames.add(houseName.trim());
      });
      _saveData();
    }
    Navigator.pop(context);
  }

  void _deleteHouse(String house) {
    if (house != 'כללי') {
      setState(() {
        houses['כללי']!.addAll(houses[house]!);
        houses.remove(house);
        houseNames.remove(house);
      });
      _saveData();
    }
  }

  void _showEditDeleteMenu(BuildContext context, Offset position, String house, Map<String, dynamic> topic) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(value: 'edit', child: Text('ערוך')),
        PopupMenuItem(value: 'delete', child: Text('מחק')),
      ],
    );

    if (selected == 'edit') {
      _editTopic(house, topic);
    } else if (selected == 'delete') {
      setState(() {
        houses[house]!.remove(topic);
      });
      _saveData();
    }
  }

  void _editTopic(String house, Map<String, dynamic> topic) {
    String newName = topic['name'];
    Color selectedColor = topic['color'];
    final controller = TextEditingController(text: newName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ערוך נושא'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: 'שם חדש'),
              onChanged: (val) => newName = val,
            ),
            SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: Text('בחר צבע:')),
            MaterialPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => selectedColor = color,
              enableLabel: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
            onPressed: () {
              setState(() {
                topic['name'] = newName.trim();
                topic['color'] = selectedColor;
              });
              _saveData();
              Navigator.pop(context);
            },
            child: Text('שמור'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTile(Map<String, dynamic> topic,
      {VoidCallback? onLeftClick, void Function(Offset)? onRightClick}) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
          onRightClick?.call(event.position);
        }
      },
      child: GestureDetector(
        onTap: onLeftClick,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 180),
            child: ListTile(
              tileColor: topic['color'],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                topic['name'],
                style: TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTopic(String house, int index, Map<String, dynamic> topic) {
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (_) => true,
      onAccept: (data) {
        setState(() {
          houses[data['fromHouse']]!.remove(data['topic']);
          houses[house]!.insert(index, data['topic']);
        });
        _saveData();
      },
      builder: (context, _, __) => Draggable<Map<String, dynamic>>(
        data: {'topic': topic, 'fromHouse': house},
        feedback: Material(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: topic['color'],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(topic['name'], style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildTopicTile(topic),
        ),
        child: _buildTopicTile(
          topic,
          onLeftClick: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TopicPage(name: topic['name']),
              ),
            );
          },
          onRightClick: (position) {
            _showEditDeleteMenu(context, position, house, topic);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(
          title: Text('נושאים', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: _addHouse, icon: Icon(Icons.house)),
            IconButton(onPressed: _addTopic, icon: Icon(Icons.add)),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: IntrinsicWidth(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: houseNames.map((house) {
                        final topics = houses[house]!;
                        return Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: DragTarget<Map<String, dynamic>>(
                            onWillAccept: (_) => true,
                            onAccept: (data) {
                              setState(() {
                                houses[data['fromHouse']]!.remove(data['topic']);
                                houses[house]!.add(data['topic']);
                              });
                              _saveData();
                            },
                            builder: (context, _, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 18),
                                      onPressed: () => _deleteHouse(house),
                                    ),
                                    Text(house, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                ...List.generate(topics.length, (index) {
                                  return _buildDraggableTopic(house, index, topics[index]);
                                }),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}
