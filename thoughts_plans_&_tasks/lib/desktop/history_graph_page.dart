import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final String backendUrl = 'https://thoughts-app-92lm.onrender.com';
  Map<String, Map<String, int>> historyData = {}; // signature -> topic -> score
  Map<String, Color> topicColors = {};
  Set<String> hiddenTopics = {};

  @override
  void initState() {
    super.initState();
    _loadHistoryFromBackend();
  }

  Future<void> _loadHistoryFromBackend() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/green_notes/signatures'));
      if (res.statusCode != 200) return;
      final List<String> signatures = List<String>.from(jsonDecode(res.body));
      final Map<String, Map<String, int>> parsed = {};

      for (final signature in signatures) {
        final noteRes = await http.get(Uri.parse('$backendUrl/green_notes/version/$signature'));
        if (noteRes.statusCode == 200 && noteRes.body != 'null') {
          final data = jsonDecode(noteRes.body);
          final scores = Map<String, int>.fromIterable(
            data['scores'],
            key: (e) => e['category'],
            value: (e) => e['score'],
          );
          parsed[signature] = scores;
        }
      }

      setState(() => historyData = parsed);
    } catch (e) {
      print('Failed to load history: $e');
    }
  }

  List<LineChartBarData> _buildLines(List<String> sortedKeys) {
    final Set<String> topics = {};
    historyData.values.forEach((scores) => topics.addAll(scores.keys));

    return topics.map((topic) {
      if (hiddenTopics.contains(topic)) return null;

      final List<FlSpot> spots = [];
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        final score = historyData[key]?[topic];
        if (score != null) {
          spots.add(FlSpot(i.toDouble(), score.toDouble()));
        } else {
          if (spots.isNotEmpty) break;
        }
      }
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 2,
        dotData: FlDotData(show: spots.length == 1),
        color: topicColors[topic] ?? Colors.primaries[topics.toList().indexOf(topic) % Colors.primaries.length],
      );
    }).whereType<LineChartBarData>().toList();
  }

  void _showTopicOptions(String topic) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(hiddenTopics.contains(topic) ? 'הצג נושא' : 'הסתר נושא'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                if (hiddenTopics.contains(topic)) {
                  hiddenTopics.remove(topic);
                } else {
                  hiddenTopics.add(topic);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeColor(String topic) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('בחר צבע ל-$topic'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: topicColors[topic] ?? Colors.blue,
            onColorChanged: (color) => Navigator.pop(context, color),
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() => topicColors[topic] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = historyData.keys.toList()..sort();
    final topics = historyData.values.expand((map) => map.keys).toSet();
    final years = sortedKeys.map((k) => k.split(' ')[0].split('-')[0]).toSet().toList()..sort();
    final yearLabel = years.isEmpty ? '' : (years.length == 1 ? years.first : '${years.first}-${years.last}');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(title: Text('היסטוריה ${yearLabel.isNotEmpty ? '($yearLabel)' : ''}')),
        body: Column(
          children: [
            if (sortedKeys.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: sortedKeys.length * 40.0,
                      child: LineChart(
                        LineChartData(
                          minY: 1,
                          maxY: 5,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (value, _) =>
                                    Text(value.toInt().toString(), style: TextStyle(fontSize: 10)),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: 1,
                                getTitlesWidget: (value, _) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < sortedKeys.length) {
                                    final key = sortedKeys[idx];
                                    try {
                                      final parts = key.split(' ');
                                      final dateParts = parts[0].split('-');
                                      final version = parts[2];
                                      return Text('${dateParts[1]}-${dateParts[2]}-$version', style: TextStyle(fontSize: 8));
                                    } catch (_) {
                                      return Text(key, style: TextStyle(fontSize: 8));
                                    }
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          lineBarsData: _buildLines(sortedKeys),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: topics.map((topic) {
                  final color = topicColors[topic] ?? Colors.primaries.toList()[topics.toList().indexOf(topic) % Colors.primaries.length];
                  return GestureDetector(
                    onTap: () => _changeColor(topic),
                    onSecondaryTap: () => _showTopicOptions(topic),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(topic, style: TextStyle(color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
