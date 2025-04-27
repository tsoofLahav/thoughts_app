import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'topic_page.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform; // add this if not already imported

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

  Future<void> _openHouseDialog({String? oldName}) async {
    final controller = TextEditingController(text: oldName ?? '');
    final title = oldName == null ? 'הוסף בית' : 'ערוך בית';
    final action = oldName == null ? 'צור' : 'שמור';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textDirection: TextDirection.rtl), // ✅ Title right-aligned
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl, // ✅ Text field right-aligned
          onSubmitted: (value) => Navigator.pop(context, value.trim()), // ✅ Enter acts as save
          decoration: InputDecoration(hintText: 'שם הבית'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('ביטול', textDirection: TextDirection.rtl), // ✅ Right
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action, textDirection: TextDirection.rtl), // ✅ Right
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (oldName == null) {
        await http.post(Uri.parse('$backendUrl/add_house'),
            body: jsonEncode({'name': result}),
            headers: {'Content-Type': 'application/json'});
      } else {
        await http.post(Uri.parse('$backendUrl/edit_house'),
            body: jsonEncode({'old_name': oldName, 'new_name': result}),
            headers: {'Content-Type': 'application/json'});
      }
      _loadData();
    }
  }



  Future<void> _openTopicDialog({String? house, Map<String, dynamic>? oldTopic}) async {
    final nameController = TextEditingController(text: oldTopic?['name'] ?? '');
    Color selectedColor = oldTopic?['color'] ?? Colors.teal;
    final title = oldTopic == null ? 'הוסף נושא' : 'ערוך נושא';
    final action = oldTopic == null ? 'צור' : 'שמור';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, textDirection: TextDirection.rtl),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end, // ✅ Align right
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  onSubmitted: (_) {
                    Navigator.pop(context, {
                      'name': nameController.text.trim(),
                      'color': selectedColor.value,
                    });
                  },
                  decoration: InputDecoration(hintText: 'שם הנושא'),
                ),
                SizedBox(height: 12),
                Text('בחר צבע:', textDirection: TextDirection.rtl), // ✅ Small simple label
                SizedBox(height: 8),
                ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (color) {
                    selectedColor = color;
                    // No setState needed inside dialog normally unless you really want live effect
                  },
                  enableAlpha: false,
                  portraitOnly: true,
                  labelTypes: [],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('ביטול', textDirection: TextDirection.rtl),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text.trim(),
                'color': selectedColor.value,
              }),
              child: Text(action, textDirection: TextDirection.rtl),
            ),
          ],
        );
      },
    );

    if (result != null && result['name'].isNotEmpty) {
      if (oldTopic == null) {
        await http.post(Uri.parse('$backendUrl/add_topic'),
            body: jsonEncode({'name': result['name'], 'color': result['color'], 'house': house}),
            headers: {'Content-Type': 'application/json'});
      } else {
        await http.post(Uri.parse('$backendUrl/edit_topic'),
            body: jsonEncode({'id': oldTopic['id'], 'name': result['name'], 'color': result['color']}),
            headers: {'Content-Type': 'application/json'});
      }
      _loadData();
    }
  }


  void _moveTopic(int topicId, String newHouse, int newOrder) async {
    await http.post(Uri.parse('$backendUrl/move_topic'),
        body: jsonEncode({'topic_id': topicId, 'new_house': newHouse, 'new_order': newOrder}),
        headers: {'Content-Type': 'application/json'});
    _loadData(); // ✅ Important!
  }

  void _onTopicRightClick(Map<String, dynamic> topic, String house, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy), // ✅ Next to pointer
      items: [
        PopupMenuItem(
          child: Text('ערוך'),
          onTap: () async {
            await Future.delayed(Duration.zero); // ✅ Let the menu close first
            _openTopicDialog(oldTopic: topic);   // ✅ Open edit topic dialog
          },
        ),
        PopupMenuItem(
          child: Text('מחק'),
          onTap: () async {
            await Future.delayed(Duration.zero); // ✅ Let the menu close first
            await http.post(
              Uri.parse('$backendUrl/delete_topic'),
              body: jsonEncode({'id': topic['id']}),
              headers: {'Content-Type': 'application/json'},
            );
            _loadData();
          },
        ),
      ],
    );
  }

  void _onHouseRightClick(String house, Offset position) {
    if (house == 'כללי') return; // ✅ Prevent deleting the general house
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy), // ✅ Next to pointer
      items: [
        PopupMenuItem(
          child: Text('ערוך'),
          onTap: () async {
            await Future.delayed(Duration.zero); // ✅ Let the menu close first
            _openHouseDialog(oldName: house);     // ✅ Open edit house dialog
          },
        ),
        PopupMenuItem(
          child: Text('מחק'),
          onTap: () async {
            await Future.delayed(Duration.zero); // ✅ Let the menu close first
            await http.post(
              Uri.parse('$backendUrl/delete_house'),
              body: jsonEncode({'name': house}),
              headers: {'Content-Type': 'application/json'},
            );
            _loadData();
          },
        ),
      ],
    );
  }


  Widget _buildTopicTile(Map<String, dynamic> topic, String house) {
    final isDesktop = kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    final draggableWidget = isDesktop
        ? Draggable<Map<String, dynamic>>( // For desktop (mouse drag)
            data: {'topic': topic, 'fromHouse': house},
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 160,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: topic['color'], borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(
                    topic['name'],
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.5, child: _topicTileContent(topic)),
            child: _topicTileContent(topic),
          )
        : LongPressDraggable<Map<String, dynamic>>( // For mobile (long-press drag)
            data: {'topic': topic, 'fromHouse': house},
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 160,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: topic['color'], borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(
                    topic['name'],
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.5, child: _topicTileContent(topic)),
            child: _topicTileContent(topic),
          );

    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
          _onTopicRightClick(topic, house, event.position);
        }
      },
      child: draggableWidget,
    );
  }

  Widget _topicTileContent(Map<String, dynamic> topic) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicPage(topicId: topic['id']))),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
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
            IconButton(icon: Icon(Icons.add_box), onPressed: () => _openHouseDialog()),
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: MediaQuery.of(context).size.width,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: houseNames.map((house) {
                final topics = houses[house] ?? [];

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 200,
                    child: DragTarget<Map<String, dynamic>>(
                      onWillAccept: (data) => true,
                      onAcceptWithDetails: (details) {
                        final data = details.data;
                        final topic = data['topic'];
                        final fromHouse = data['fromHouse'];

                        _moveTopic(topic['id'], house, topics.length); // ✅ No manual setState
                      },
                      builder: (context, candidateData, rejectedData) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onSecondaryTapDown: (details) => _onHouseRightClick(house, details.globalPosition),
                            child: Row(
                              children: [
                                Text(house, style: TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: Icon(Icons.add), onPressed: () => _openTopicDialog(house: house)),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          ...topics.asMap().entries.map((entry) {
                            final index = entry.key;
                            final topic = entry.value;
                            return DragTarget<Map<String, dynamic>>(
                              onWillAccept: (data) => true,
                              onAcceptWithDetails: (details) {
                                final dragged = details.data['topic'];
                                final fromHouse = details.data['fromHouse'];

                                _moveTopic(dragged['id'], house, index); // ✅ Correct index
                              },
                              builder: (context, candidateData, rejectedData) {
                                return _buildTopicTile(topic, house);
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }


}
