


import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/home_screen.dart'; // Reusing the AttendanceLog model
import 'package:http/http.dart' as http;

class DtrScreen extends StatefulWidget {
  final int fieldEngineerId;

  const DtrScreen({required this.fieldEngineerId, super.key});

  @override
  State<DtrScreen> createState() => _DtrScreenState();
}

class _DtrScreenState extends State<DtrScreen> {
  List attendanceLogs = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchAttendanceLogs();
  }

  Future<void> fetchAttendanceLogs() async {
    final response = await http.get(
      Uri.parse(
        'https://ecsmapappwebadminbackend-production.up.railway.app/api/FieldEngineer/${widget.fieldEngineerId}/attendance',
      ),
    );

    if (response.statusCode == 200) {
      setState(() {
        attendanceLogs = json.decode(response.body);
      });
    }
  }

  List get logsForSelectedDate {
    return attendanceLogs.where((log) {
      final timeIn = DateTime.parse(log['timeIn']).toLocal();
      return timeIn.year == selectedDate.year &&
          timeIn.month == selectedDate.month &&
          timeIn.day == selectedDate.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Logs')),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            onDateChanged: (date) {
              setState(() {
                selectedDate = date;
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: logsForSelectedDate.length,
              itemBuilder: (context, index) {
                final log = logsForSelectedDate[index];
                final timeIn = DateTime.parse(log['timeIn']).toLocal();
                final timeOut = log['timeOut'] != null
                    ? DateTime.parse(log['timeOut']).toLocal()
                    : null;
                return ListTile(
                  title: Text(
                    '🕓 ${timeIn.hour.toString().padLeft(2, '0')}:${timeIn.minute.toString().padLeft(2, '0')}'
                        '${timeOut != null ? " - ${timeOut.hour.toString().padLeft(2, '0')}:${timeOut.minute.toString().padLeft(2, '0')}" : ""}',
                  ),
                  subtitle: Text(
                    timeOut == null
                        ? "Still Active"
                        : "Duration: ${timeOut.difference(timeIn).inMinutes} mins",
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

