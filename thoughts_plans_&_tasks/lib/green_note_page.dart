import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

const String backendUrl = 'https://thoughts-app-92lm.onrender.com';

class GreenNotePage extends StatefulWidget {
  @override
  _GreenNotePageState createState() => _GreenNotePageState();
}

class _GreenNotePageState extends State<GreenNotePage> {
  final List<TextEditingController> _goodThingsControllers =
      List.generate(3, (_) => TextEditingController());
  final TextEditingController _improvementController = TextEditingController();
  Map<String, double> scores = {};
  List<String> topics = ['כושר', 'שיער', 'ראייה', 'תקשורת', 'ניהול'];
  late String currentDate;
  String? currentKey;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    currentDate = _getTodayDate();
    _loadCurrentNote();
    _scheduleMidnightSave();
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  void _scheduleMidnightSave() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);
    _midnightTimer = Timer(durationUntilMidnight, _autoSaveAndReset);
  }

  void _autoSaveAndReset() async {
    await _saveNote(isFinal: true);
    _resetNote();
    _scheduleMidnightSave();
  }

  void _resetNote() {
    for (final c in _goodThingsControllers) c.clear();
    _improvementController.clear();
    scores.updateAll((key, _) => 3.0);
    setState(() => currentKey = null);
  }

  Future<void> _saveNote({required bool isFinal}) async {
    final data = {
      'date': currentDate,
      'key': currentKey,
      'is_final': isFinal,
      'good_1': _goodThingsControllers[0].text,
      'good_2': _goodThingsControllers[1].text,
      'good_3': _goodThingsControllers[2].text,
      'improve': _improvementController.text,
      'scores': scores.entries.map((e) => {
        'category': e.key,
        'score': e.value.toInt()
      }).toList()
    };

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/green_notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      final body = jsonDecode(res.body);
      setState(() => currentKey = body['key']);
    } catch (e) {
      print('Error saving note: $e');
    }
  }

  Future<void> _loadCurrentNote() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/green_notes_unsaved/$currentDate'));
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body);
        currentKey = data['key'];
        _goodThingsControllers[0].text = data['good_1'] ?? '';
        _goodThingsControllers[1].text = data['good_2'] ?? '';
        _goodThingsControllers[2].text = data['good_3'] ?? '';
        _improvementController.text = data['improve'] ?? '';
        for (var score in data['scores']) {
          scores[score['category']] = (score['score'] ?? 3).toDouble();
          if (!topics.contains(score['category'])) {
            topics.add(score['category']);
          }
        }
        setState(() {});
      }
    } catch (e) {
      print('Error loading note: $e');
    }
  }

  void _addRatingTopic() {
    String topic = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('הוסף נושא לדירוג'),
        content: TextField(
          onChanged: (value) => topic = value,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
          TextButton(
            onPressed: () {
              if (topic.trim().isEmpty) return;
              setState(() {
                topics.add(topic.trim());
                scores[topic.trim()] = 3.0;
              });
              Navigator.pop(context);
            },
            child: Text('הוסף'),
          ),
        ],
      ),
    );
  }

  void _deleteRatingTopic(String topic) {
    setState(() {
      topics.remove(topic);
      scores.remove(topic);
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    for (final c in _goodThingsControllers) c.dispose();
    _improvementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.lightGreen[100],
        appBar: AppBar(
          title: Text('פתק ירוק - ${currentKey ?? "טויטה"}'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              tooltip: 'שמור פתק ידנית',
              onPressed: () => _saveNote(isFinal: true),
            ),
            IconButton(
              icon: Icon(Icons.add),
              tooltip: 'הוסף נושא לדירוג',
              onPressed: _addRatingTopic,
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('3 דברים טובים מאתמול:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (int i = 0; i < 3; i++)
                TextField(
                  controller: _goodThingsControllers[i],
                  decoration: InputDecoration(hintText: '${i + 1}.'),
                ),
              SizedBox(height: 20),
              Text('דבר אחד לשיפור:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _improvementController),
              SizedBox(height: 30),
              Text('נושאי דירוג:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...topics.map((topic) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$topic: ${scores[topic]?.toInt() ?? 3}'),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteRatingTopic(topic),
                        ),
                      ],
                    ),
                    Slider(
                      value: scores[topic] ?? 3.0,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: scores[topic]?.toInt().toString(),
                      activeColor: Colors.green[900],
                      onChanged: (val) {
                        setState(() => scores[topic] = val);
                      },
                    )
                  ],
                );
              })
            ],
          ),
        ),
      ),
    );
  }
}
