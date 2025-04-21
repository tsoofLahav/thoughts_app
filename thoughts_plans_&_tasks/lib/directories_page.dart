import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'topic_page.dart';
import 'dart:ui';
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
              'id': e['id'],
              'name': e['name'],
              'color': Color(e['color'])
            }))
        };
        houseNames = houses.keys.toList();
        setState(() {});
      }
    } catch (e) {
      print('Failed to load directories: $e');
    }
  }

  void _navigateToTopic(Map<String, dynamic> topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TopicPage(topicId: topic['id']),
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
        onTap: () => _navigateToTopic(topic),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(
          title: Text('נושאים', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: houseNames.map((house) {
              final topics = houses[house]!;
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(house, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ...topics.map((topic) => _buildTopicTile(topic)).toList(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
