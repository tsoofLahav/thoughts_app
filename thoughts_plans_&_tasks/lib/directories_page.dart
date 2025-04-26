import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'topic_page.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
      final housesRes = await http.get(Uri.parse('$backendUrl/houses'));
      final topicsRes = await http.get(Uri.parse('$backendUrl/directories'));
      if (housesRes.statusCode == 200 && topicsRes.statusCode == 200) {
        final List<dynamic> housesData = jsonDecode(housesRes.body);
        final Map<String, dynamic> topicsData = jsonDecode(topicsRes.body);

        houseNames = List<String>.from(housesData);
        houses = {
          for (var house in houseNames)
            house: List<Map<String, dynamic>>.from(
              (topicsData[house] ?? []).map((e) => {
                'id': e['id'],
                'name': e['name'],
                'color': Color(e['color']),
                'order': e['order'],
              }),
            )
        };

        setState(() {});
      }
    } catch (e) {
      print('Failed to load directories: $e');
    }
  }

  Future<void> _addHouse() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('הוסף בית'),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: 'שם הבית')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text('ביטול')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('צור')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await http.post(Uri.parse('$backendUrl/add_house'), body: jsonEncode({'name': name}), headers: {'Content-Type': 'application/json'});
      _loadData();
    }
  }

  Future<void> _addTopic(String house) async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.teal;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('הוסף נושא'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: InputDecoration(hintText: 'שם הנושא')),
          SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showDialog<Color>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('בחר צבע'),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: selectedColor,
                      onColorChanged: (color) => Navigator.pop(context, color),
                    ),
                  ),
                ),
              );
              if (picked != null) {
                setState(() => selectedColor = picked);
              }
            },
            child: Container(
              width: double.infinity,
              height: 40,
              color: selectedColor,
              child: Center(child: Text('בחר צבע', style: TextStyle(color: Colors.white))),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'color': selectedColor.value,
                  }),
              child: Text('צור')),
        ],
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      await http.post(Uri.parse('$backendUrl/add_topic'),
          body: jsonEncode({'name': result['name'], 'color': result['color'], 'house': house}),
          headers: {'Content-Type': 'application/json'});
      _loadData();
    }
  }

  void _moveTopic(int topicId, String newHouse, int newOrder) async {
    await http.post(Uri.parse('$backendUrl/move_topic'),
        body: jsonEncode({'topic_id': topicId, 'new_house': newHouse, 'new_order': newOrder}),
        headers: {'Content-Type': 'application/json'});
    _loadData();
  }

  void _onTopicRightClick(Map<String, dynamic> topic, String house, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: [
        PopupMenuItem(child: Text('ערוך'), onTap: () {
          // TODO: Edit topic dialog
        }),
        PopupMenuItem(child: Text('מחק'), onTap: () async {
          await http.post(Uri.parse('$backendUrl/delete_topic'),
              body: jsonEncode({'id': topic['id']}), headers: {'Content-Type': 'application/json'});
          _loadData();
        }),
      ],
    );
  }

  void _onHouseRightClick(String house, Offset position) {
    if (house == 'כללי') return; // prevent deleting general house
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: [
        PopupMenuItem(child: Text('ערוך'), onTap: () {
          // TODO: Edit house dialog
        }),
        PopupMenuItem(child: Text('מחק'), onTap: () async {
          await http.post(Uri.parse('$backendUrl/delete_house'),
              body: jsonEncode({'name': house}), headers: {'Content-Type': 'application/json'});
          _loadData();
        }),
      ],
    );
  }

  Widget _buildTopicTile(Map<String, dynamic> topic, String house) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'topic': topic, 'fromHouse': house},
      feedback: Material(
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: topic['color'], borderRadius: BorderRadius.circular(8)),
          child: Text(topic['name'], style: TextStyle(color: Colors.white)),
        ),
      ),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
            _onTopicRightClick(topic, house, event.position);
          }
        },
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicPage(topicId: topic['id']))),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              tileColor: topic['color'],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(topic['name'], style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
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
            IconButton(icon: Icon(Icons.add_box), onPressed: _addHouse),
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: houseNames.map((house) {
              final topics = houses[house]!;
              return DragTarget<Map<String, dynamic>>(
                onAccept: (data) {
                  final topic = data['topic'];
                  final fromHouse = data['fromHouse'];
                  if (fromHouse != house) {
                    _moveTopic(topic['id'], house, topics.length);
                  }
                },
                builder: (context, candidateData, rejectedData) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onSecondaryTapDown: (details) => _onHouseRightClick(house, details.globalPosition),
                        child: Row(
                          children: [
                            Text(house, style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: Icon(Icons.add), onPressed: () => _addTopic(house)),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      ...topics.map((topic) => _buildTopicTile(topic, house)).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
