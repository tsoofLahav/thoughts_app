import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, Map<String, int>> historyData = {}; // key -> topic -> score
  Map<String, Color> topicColors = {};
  Set<String> hiddenTopics = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('green_history_'));
    final Map<String, Map<String, int>> parsedHistory = {};

    for (String key in keys) {
      final note = prefs.getString(key);
      if (note != null) {
        try {
          final Map<String, dynamic> parsed = jsonDecode(note);
          final scores = Map<String, int>.from(parsed['scores'] ?? {});
          parsedHistory[key] = scores;
        } catch (e) {
          debugPrint("Skipping invalid entry in $key: $e");
        }
      }
    }

    final colorData = prefs.getString('greenNoteColors');
    if (colorData != null) {
      try {
        final colorMap = jsonDecode(colorData);
        topicColors = Map<String, Color>.from(
          colorMap.map((k, v) => MapEntry(k, Color(v))),
        );
      } catch (e) {
        debugPrint("Invalid color data: $e");
      }
    }

    setState(() {
      historyData = parsedHistory;
    });
  }

  Future<void> _clearHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('green_history_')).toList();
    for (String key in keys) {
      await prefs.remove(key);
    }
    setState(() {
      historyData.clear();
    });
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
          if (spots.isNotEmpty) break; // Break line if topic disappeared
        }
      }
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 2,
        dotData: FlDotData(show: spots.length == 1),
        color: topicColors[topic] ?? Colors.primaries[topics.toList().indexOf(topic) % Colors.primaries.length],
      );
    }).whereType<LineChartBarData>().toList(); // Filter out nulls
  }

  bool _isDeletable(String topic) {
    final sortedKeys = historyData.keys.toList()..sort();
    if (sortedKeys.isEmpty) return false;
    final lastEntry = historyData[sortedKeys.last];
    return !(lastEntry?.containsKey(topic) ?? false);
  }

  void _deleteTopic(String topic) {
    setState(() {
      historyData.forEach((key, map) => map.remove(topic));
      topicColors.remove(topic);
      hiddenTopics.remove(topic);
    });
  }

  void _showTopicOptions(String topic) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDeletable(topic))
            ListTile(
              title: Text('מחק נושא'),
              onTap: () {
                Navigator.pop(context);
                _deleteTopic(topic);
              },
            ),
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
      setState(() {
        topicColors[topic] = picked;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('greenNoteColors', jsonEncode(
        topicColors.map((k, v) => MapEntry(k, v.value)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = historyData.keys.toList()..sort((a, b) => a.compareTo(b));
    final topics = historyData.values.expand((map) => map.keys).toSet();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        appBar: AppBar(
          title: Text('היסטוריית פתק ירוק'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: 'אפס היסטוריה',
              onPressed: _clearHistory,
            )
          ],
        ),
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
                                getTitlesWidget: (value, _) =>
                                    Text(value.toInt().toString(), style: TextStyle(fontSize: 10)),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, _) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < sortedKeys.length) {
                                    final key = sortedKeys[idx].replaceFirst('green_history_', '');
                                    final parts = key.split(' ');
                                    if (parts.length == 2) {
                                      final dateParts = parts[0].split('-');
                                      if (dateParts.length == 3) {
                                        return Text('${dateParts[1]}-${dateParts[2]} ${parts[1]}',
                                            style: TextStyle(fontSize: 8));
                                      }
                                    }
                                    return Text(key, style: TextStyle(fontSize: 8));
                                  }
                                  return Text('');
                                },
                              ),
                            ),
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
