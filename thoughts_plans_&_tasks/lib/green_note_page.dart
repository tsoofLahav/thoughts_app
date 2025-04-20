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
    currentDate = _getTodayDate();
    _loadTopics();
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

  Future<void> _handleMidnight() async {
    await _saveCurrentFile();
    await _saveTopics();
    await _createNewVersion();
    _resetFields();
    currentDate = _getTodayDate();
    _scheduleMidnightSave();
  }

  void _resetFields() {
    for (final c in _goodThingsControllers) c.clear();
    _improvementController.clear();
    scores = {for (var t in topics) t: 3.0};
    setState(() => currentSignature = null);
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
      print('Error loading topics: $e');
    }
  }

  Future<void> _saveTopics() async {
    try {
      await http.post(
        Uri.parse('$backendUrl/green_note_topics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topics': topics}),
      );
    } catch (e) {
      print('Error saving topics: $e');
    }
  }

  Future<void> _loadLatestVersion() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/signatures'));
      if (res.statusCode == 200) {
        final list = List<String>.from(jsonDecode(res.body))
          .where((s) => s.startsWith(currentDate))
          .toList();
        if (list.isNotEmpty) {
          currentSignature = list.last;
          await _loadVersion(currentSignature!);
        }
      }
    } catch (e) {
      print('Load version error: $e');
    }
  }

  Future<void> _loadVersion(String signature) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/version/$signature'));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body);
        setState(() {
          _goodThingsControllers[0].text = data['good_1'] ?? '';
          _goodThingsControllers[1].text = data['good_2'] ?? '';
          _goodThingsControllers[2].text = data['good_3'] ?? '';
          _improvementController.text = data['improve'] ?? '';
          scores = {
            for (var score in data['scores'])
              score['category']: (score['score'] ?? 3).toDouble()
          };
        });
      }
    } catch (e) {
      print('Error loading version: $e');
    }
  }

  Future<void> _saveCurrentFile() async {
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
      print('Save error: $e');
    }
  }

  Future<void> _createNewVersion() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/signatures'));
      final list = res.statusCode == 200
          ? List<String>.from(jsonDecode(res.body)).where((s) => s.startsWith(currentDate)).toList()
          : [];
      final versionNumber = list.length + 1;
      final newSignature = "$currentDate - $versionNumber";

      final data = {
        'signature': newSignature,
        'date': currentDate,
        'good_1': '',
        'good_2': '',
        'good_3': '',
        'improve': '',
        'scores': topics.map((t) => {'category': t, 'score': 3}).toList()
      };

      final resPost = await http.post(
        Uri.parse('$backendUrl/green_notes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (resPost.statusCode == 200) {
        setState(() => currentSignature = newSignature);
      }
    } catch (e) {
      print('Create version error: $e');
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _saveCurrentFile();
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
              icon: Icon(Icons.save),
              onPressed: () async {
                await _saveCurrentFile();
                await _saveTopics();
                await _createNewVersion();
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
