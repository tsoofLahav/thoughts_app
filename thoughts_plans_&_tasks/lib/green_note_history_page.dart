import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GreenNoteHistoryPage extends StatefulWidget {
  @override
  _GreenNoteHistoryPageState createState() => _GreenNoteHistoryPageState();
}

class _GreenNoteHistoryPageState extends State<GreenNoteHistoryPage> {
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';
  List<Map<String, dynamic>> greenNotes = [];
  Map<String, dynamic>? selectedNote;

  @override
  void initState() {
    super.initState();
    _fetchGreenNotes();
  }

  Future<void> _fetchGreenNotes() async {
    final response = await http.get(Uri.parse('$backendUrl/green_notes_all'));
    if (response.statusCode == 200) {
      setState(() {
        greenNotes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('היסטוריית פתקים ירוקים')),
        backgroundColor: Colors.lightGreen[100],
        body: Row(
          children: [
            Container(
              width: 200,
              color: Colors.green[50],
              child: ListView.builder(
                itemCount: greenNotes.length,
                itemBuilder: (context, index) {
                  final note = greenNotes[index];
                  return ListTile(
                    title: Text(note['date']),
                    onTap: () {
                      setState(() {
                        selectedNote = note;
                      });
                    },
                  );
                },
              ),
            ),
            VerticalDivider(width: 1),
            Expanded(
              child: selectedNote == null
                  ? Center(child: Text('בחר פתק'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('3 דברים טובים מאתמול:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('1. ${selectedNote!['good_1'] ?? ''}'),
                            Text('2. ${selectedNote!['good_2'] ?? ''}'),
                            Text('3. ${selectedNote!['good_3'] ?? ''}'),
                            SizedBox(height: 16),
                            Text('דבר אחד לשיפור:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(selectedNote!['improve'] ?? ''),
                            SizedBox(height: 24),
                            Text('נושאי דירוג:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ...List.generate((selectedNote!['scores'] as List).length, (i) {
                              final item = selectedNote!['scores'][i];
                              return Text('${item['category']}: ${item['score']}');
                            })
                          ],
                        ),
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
