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
  List<String> topics = ['כושר', 'שיער', 'ראייה', 'תקשורת', 'ניהול'];

  late String currentDate;
  String? currentKey;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    currentDate = _getTodayDate();
    _loadLatestVersion();
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
    _midnightTimer = Timer(durationUntilMidnight, _handleMidnight);
  }

  void _handleMidnight() async {
    await _saveNote(isFinal: true);
    await _createNewEmptyVersion();
    currentDate = _getTodayDate();
    _resetFields();
    _scheduleMidnightSave();
  }

  void _resetFields() {
    for (final c in _goodThingsControllers) c.clear();
    _improvementController.clear();
    scores = {for (var t in topics) t: 3.0};
    setState(() => currentKey = null);
  }

  Future<void> _loadLatestVersion() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes_unsaved/$currentDate'));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body);
        setState(() {
          currentKey = data['key'];
          _goodThingsControllers[0].text = data['good_1'] ?? '';
          _goodThingsControllers[1].text = data['good_2'] ?? '';
          _goodThingsControllers[2].text = data['good_3'] ?? '';
          _improvementController.text = data['improve'] ?? '';
          for (var score in data['scores']) {
            scores[score['category']] = (score['score'] ?? 3).toDouble();
            if (!topics.contains(score['category'])) topics.add(score['category']);
          }
        });
      }
    } catch (e) {
      print('Load error: $e');
    }
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
      'scores': scores.entries.map((e) => {'category': e.key, 'score': e.value.toInt()}).toList()
    };

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/green_notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      final body = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        currentKey = body['key'];
      });
    } catch (e) {
      print('Save error: $e');
    }
  }

  Future<void> _createNewEmptyVersion() async {
    final data = {
      'date': currentDate,
      'key': null,
      'is_final': false,
      'good_1': '',
      'good_2': '',
      'good_3': '',
      'improve': '',
      'scores': topics.map((t) => {'category': t, 'score': 3}).toList()
    };

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/green_notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      final body = jsonDecode(res.body);
      if (!mounted) return;
      setState(() => currentKey = body['key']);
    } catch (e) {
      print('New version error: $e');
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _saveNote(isFinal: false);
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
          title: Text('פתק ירוק - ${currentKey ?? ""}'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () async {
                await _saveNote(isFinal: true);
                await _createNewEmptyVersion();
                _resetFields();
              },
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
                    activeColor: Colors.green[900],
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
