import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
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
  List<String> topics = [];


  late String currentDate;
  late String currentKey;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    currentDate = _getTodayDate();
    _loadTopics().then((_) => _loadCurrentNote());
    _scheduleMidnightSave();
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('green_note_topics') ??
        ['כושר', 'שיער', 'ראייה', 'תקשורת', 'ניהול'];
    topics = stored;
    scores = {for (var t in stored) t: 3.0};
  }

  Future<void> _saveTopics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('green_note_topics', topics);
  }

  void _scheduleMidnightSave() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, _autoSaveAndReset);
  }

  void _autoSaveAndReset() async {
    await _saveToHistory();
    _resetNote();
    await _createNewVersion();
    _scheduleMidnightSave();
  }

  void _resetNote() {
    for (final c in _goodThingsControllers) {
      c.clear();
    }
    _improvementController.clear();
    scores.updateAll((key, value) => 3.0);
    setState(() {});
  }

  Future<void> _saveNoteManually() async {
    await _saveToHistory();
    _resetNote();
    await _createNewVersion();
  }

  Future<void> _createNewVersion() async {
    final prefs = await SharedPreferences.getInstance();
    int index = 1;
    while (prefs.containsKey('green_history_${currentDate} $index')) {
      index++;
    }
    currentKey = 'green_history_${currentDate} $index';
    await prefs.setString('green_note_current', currentKey);
    await prefs.remove(currentKey); // ensure fresh state
  }

  Future<void> _loadCurrentNote() async {
    final response = await http.get(Uri.parse('$backendUrl/green_notes/$currentDate'));

    if (response.statusCode == 200 && response.body != 'null') {
      final data = jsonDecode(response.body);
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
    }

    setState(() {});
  }


  Future<void> _saveCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'goodThings': _goodThingsControllers.map((c) => c.text).toList(),
      'improvement': _improvementController.text,
      'scores': scores,
    };
    await prefs.setString(currentKey, jsonEncode(data));
  }

  Future<void> _saveToHistory() async {
    final data = {
      'date': currentDate,
      'good_1': _goodThingsControllers[0].text,
      'good_2': _goodThingsControllers[1].text,
      'good_3': _goodThingsControllers[2].text,
      'improve': _improvementController.text,
      'scores': scores.entries.map((e) => {
        'category': e.key,
        'score': e.value.toInt()
      }).toList()
    };

    await http.post(
      Uri.parse('$backendUrl/green_notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
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
              _saveTopics();
              _saveCurrentData();
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
    _saveTopics();
    _saveCurrentData();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    for (final controller in _goodThingsControllers) {
      controller.dispose();
    }
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
          title: Text('פתק ירוק - $currentKey'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              tooltip: 'שמור פתק ידנית',
              onPressed: _saveNoteManually,
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
                  onChanged: (_) => _saveCurrentData(),
                  decoration: InputDecoration(hintText: '${i + 1}.'),
                ),
              SizedBox(height: 20),
              Text('דבר אחד לשיפור:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(
                controller: _improvementController,
                onChanged: (_) => _saveCurrentData(),
              ),
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
                        setState(() {
                          scores[topic] = val;
                        });
                        _saveCurrentData();
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
