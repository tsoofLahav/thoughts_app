import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackingPage extends StatefulWidget {
  @override
  _TrackingPageState createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final String backendUrl = 'YOUR_BACKEND_URL';
  final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<Map<String, dynamic>> foodItems = [];
  List<Map<String, dynamic>> trackingItems = [];

  double get totalCalories => foodItems.fold(0.0, (sum, item) => sum + ((item['calories'] ?? 0) as num).toDouble());
  double get totalProtein => foodItems.fold(0.0, (sum, item) => sum + ((item['protein'] ?? 0) as num).toDouble());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final foodRes = await http.get(Uri.parse('$backendUrl/get_food?date=$today'));
    final trackingRes = await http.get(Uri.parse('$backendUrl/get_tracking'));
    setState(() {
      foodItems = List<Map<String, dynamic>>.from(jsonDecode(foodRes.body));
      trackingItems = List<Map<String, dynamic>>.from(jsonDecode(trackingRes.body));
    });
  }

  Future<void> _addFoodItem(String name, int calories, int protein) async {
    await http.post(
      Uri.parse('$backendUrl/add_food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'date': today, 'name': name, 'calories': calories, 'protein': protein}),
    );
    _loadData();
  }

  Future<void> _toggleDone(String name, int index, bool checked) async {
    await http.post(
      Uri.parse('$backendUrl/update_tracking_done'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'index': index, 'checked': checked}),
    );
    _loadData();
  }

  Future<void> _addTrackingItem(String name, int amount, List<String> content) async {
    await http.post(
      Uri.parse('$backendUrl/add_tracking_item'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'amount': amount, 'content': content}),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('מעקב יומי')),
      body: Row(
        children: [
          // Food Tracking
          Expanded(
            child: Column(
              children: [
                Text('אוכל - $today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                DataTable(columns: [
                  DataColumn(label: Text('שם')),
                  DataColumn(label: Text('קלוריות')),
                  DataColumn(label: Text('חלבון')),
                ], rows: foodItems.map((item) {
                  return DataRow(cells: [
                    DataCell(Text(item['name'] ?? '')),
                    DataCell(Text(item['calories'].toString())),
                    DataCell(Text(item['protein'].toString())),
                  ]);
                }).toList()),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('סה"כ: $totalCalories קלוריות, $totalProtein חלבון'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nameCtrl = TextEditingController();
                    final calCtrl = TextEditingController();
                    final proCtrl = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('הוסף אוכל'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'שם')),
                            TextField(controller: calCtrl, decoration: InputDecoration(labelText: 'קלוריות'), keyboardType: TextInputType.number),
                            TextField(controller: proCtrl, decoration: InputDecoration(labelText: 'חלבון'), keyboardType: TextInputType.number),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
                          TextButton(
                            onPressed: () {
                              _addFoodItem(
                                nameCtrl.text,
                                int.tryParse(calCtrl.text) ?? 0,
                                int.tryParse(proCtrl.text) ?? 0,
                              );
                              Navigator.pop(context);
                            },
                            child: Text('הוסף'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text('+ הוסף אוכל'),
                ),
              ],
            ),
          ),

          VerticalDivider(width: 1),

          // Other Tracking
          Expanded(
            child: Column(
              children: [
                Text('מעקב כללי', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView(
                    children: trackingItems.map((item) {
                      return ListTile(
                        title: Row(
                          children: [
                            Tooltip(
                              message: (item['content'] as List<dynamic>).join('\n'),
                              child: Text(item['name']),
                            ),
                            SizedBox(width: 12),
                            ...List.generate(item['amount'], (i) {
                              final filled = i < item['done'];
                              return GestureDetector(
                                onTap: () => _toggleDone(item['name'], i, !filled),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Icon(
                                    filled ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: filled ? Colors.teal : Colors.grey,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nameCtrl = TextEditingController();
                    final amountCtrl = TextEditingController();
                    final contentCtrl = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('הוסף פריט מעקב'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'שם')),
                            TextField(controller: amountCtrl, decoration: InputDecoration(labelText: 'כמות'), keyboardType: TextInputType.number),
                            TextField(controller: contentCtrl, decoration: InputDecoration(labelText: 'הערות (מופרדות בקו חדש)'), maxLines: 3),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('ביטול')),
                          TextButton(
                            onPressed: () {
                              _addTrackingItem(
                                nameCtrl.text,
                                int.tryParse(amountCtrl.text) ?? 0,
                                contentCtrl.text.split('\n'),
                              );
                              Navigator.pop(context);
                            },
                            child: Text('הוסף'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text('+ הוסף פריט'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
