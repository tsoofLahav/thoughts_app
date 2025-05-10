import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
  String? currentSignature;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _wakeServer();
    currentDate = _getTodayDate();
    _initializeNote();
    _scheduleMidnightSave();
  }

  void _wakeServer() {
    http.get(Uri.parse('$backendUrl/ping')).catchError((e) {
      print('Wake-up failed: $e');
    });
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  void _scheduleMidnightSave() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);
    _midnightTimer = Timer(durationUntilMidnight, _handleMidnight);
  }

  Future<void> _handleMidnight() async {
    await _saveCurrentNote();
    await _saveTopics();

    // 🔽 ADD THIS LINE to reload topics just before creating the new note
    await _loadTopics();

    await _createNewVersion(dateBased: true);
    _resetFields();
    currentDate = _getTodayDate();
    _scheduleMidnightSave();
  }

  Future<void> _initializeNote() async {
    await _loadTopics();
    await _loadOrCreateLatestNote();
  }

  Future<void> _loadTopics() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_note_topics'));
      if (res.statusCode == 200) {
        final list = List<String>.from(jsonDecode(res.body));
        setState(() {
          topics = list;
          scores = {for (var t in topics) t: 3.0};
        });
      }
    } catch (e) {
      print('Failed to load topics: $e');
    }
  }

  Future<void> _saveTopics() async {
    try {
      await http.post(Uri.parse('$backendUrl/green_note_topics'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'topics': topics}));
    } catch (e) {
      print('Failed to save topics: $e');
    }
  }

  Future<void> _loadOrCreateLatestNote() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/signatures'));
      if (res.statusCode == 200) {
        final list = List<String>.from(jsonDecode(res.body))
            .where((s) => s.startsWith(currentDate))
            .toList();
        if (list.isNotEmpty) {
          currentSignature = list.last;
          await _loadNoteBySignature(currentSignature!);
          return;
        }
      }
    } catch (_) {}
    await _createNewVersion(dateBased: false); // fallback if nothing loaded
  }

  Future<void> _createNewVersion({required bool dateBased}) async {
    final res = await http.get(Uri.parse('$backendUrl/green_notes/signatures'));
    final list = res.statusCode == 200
        ? List<String>.from(jsonDecode(res.body))
            .where((s) => s.startsWith(currentDate))
            .toList()
        : [];
    final version = list.length + 1;
    final signature = "$currentDate - $version";

    final data = {
      'signature': signature,
      'date': currentDate,
      'good_1': '',
      'good_2': '',
      'good_3': '',
      'improve': '',
      'scores': topics.map((t) => {'category': t, 'score': 3}).toList()
    };

    final post = await http.post(
      Uri.parse('$backendUrl/green_notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (post.statusCode == 200) {
      setState(() {
        currentSignature = signature;
        _resetFields();
      });
    }
  }

  Future<void> _loadNoteBySignature(String signature) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/version/$signature'));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body);
        setState(() {
          currentSignature = signature;
          _goodThingsControllers[0].text = data['good_1'] ?? '';
          _goodThingsControllers[1].text = data['good_2'] ?? '';
          _goodThingsControllers[2].text = data['good_3'] ?? '';
          _improvementController.text = data['improve'] ?? '';
          scores = {
            for (var item in data['scores']) item['category']: (item['score'] ?? 3).toDouble()
          };
        });
      }
    } catch (e) {
      print('Error loading note: $e');
    }
  }

  Future<void> _saveCurrentNote() async {
    if (currentSignature == null) return;
    final data = {
      'signature': currentSignature,
      'date': currentDate,
      'good_1': _goodThingsControllers[0].text,
      'good_2': _goodThingsControllers[1].text,
      'good_3': _goodThingsControllers[2].text,
      'improve': _improvementController.text,
      'scores': scores.entries.map((e) => {'category': e.key, 'score': e.value.toInt()}).toList()
    };

    try {
      await http.post(
        Uri.parse('$backendUrl/green_notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (e) {
      print('Failed to save note: $e');
    }
  }

  void _resetFields() {
    for (var controller in _goodThingsControllers) controller.clear();
    _improvementController.clear();
    scores = {for (var t in topics) t: 3.0};
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _saveCurrentNote();
    _saveTopics();
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
          title: Text('פתק ירוק - ${currentSignature ?? ""}'),
          actions: [
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                String newTopic = '';
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('הוסף נושא'),
                    content: TextField(onChanged: (val) => newTopic = val),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
                      TextButton(
                        onPressed: () {
                          if (newTopic.trim().isNotEmpty) {
                            setState(() {
                              topics.add(newTopic);
                              scores[newTopic] = 3.0;
                            });
                          }
                          Navigator.pop(context);
                        },
                        child: Text('הוסף'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () async {
                await _saveCurrentNote();
                await _saveTopics();
                await _createNewVersion(dateBased: false);
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('3 דברים טובים מאתמול:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (int i = 0; i < 3; i++)
                TextField(controller: _goodThingsControllers[i], decoration: InputDecoration(hintText: '${i + 1}.')),
              SizedBox(height: 20),
              Text('דבר אחד לשיפור:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _improvementController),
              SizedBox(height: 30),
              Text('נושאי דירוג:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...topics.map((topic) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('$topic: ${scores[topic]?.toInt() ?? 3}'),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.delete, size: 20),
                            onPressed: () {
                              setState(() {
                                topics.remove(topic);
                                scores.remove(topic);
                              });
                            },
                          )
                        ],
                      ),
                      Slider(
                        value: scores[topic] ?? 3.0,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: scores[topic]?.toInt().toString(),
                        onChanged: (val) => setState(() => scores[topic] = val),
                      )
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}