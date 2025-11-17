import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DtrScreen extends StatefulWidget {
  final int fieldEngineerId;


  const DtrScreen({required this.fieldEngineerId, super.key});

  @override
  State<DtrScreen> createState() => _DtrScreenState();
}

class _DtrScreenState extends State<DtrScreen> {
  List attendanceLogs = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  final apiUrl = dotenv.env['API_URL'];



  DateTime parseServerTime(String dateString) {
    final parsed = DateTime.parse(dateString);
    // Backend sends UTC but without 'Z', so manually correct it
    final corrected = parsed.subtract(const Duration(hours: 8));
    return corrected;
  }


  @override
  void initState() {
    super.initState();
    fetchAttendanceLogs();
  }

  Future<void> fetchAttendanceLogs() async {
    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/FieldEngineer/${widget.fieldEngineerId}/attendance',
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          print('🕒 Raw JSON: ${response.body}');

          attendanceLogs = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List get logsForSelectedDate {
    return attendanceLogs.where((log) {
      final timeIn = parseServerTime(log['timeIn']);



      return timeIn.year == selectedDate.year &&
          timeIn.month == selectedDate.month &&
          timeIn.day == selectedDate.day;
    }).toList();
  }

  String formatPhTime(DateTime time) {
    return DateFormat.jm().format(time);
  }



  String formatPhDate(DateTime time) {
    return DateFormat('MMM d, yyyy').format(time);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Daily Time Record'),
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🗓 Date Picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.tonalIcon(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: TextTheme(
                          bodyMedium: TextStyle(color: Colors.black), // Text color in calendar
                        ),
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          onSurface: Colors.black, // Text color for selected date
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (pickedDate != null) {
                  setState(() => selectedDate = pickedDate);
                }
              },
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(
                DateFormat('MMMM d, yyyy').format(selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // 🧾 DTR Logs
          Expanded(
            child: logsForSelectedDate.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    "No attendance records for this date",
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: logsForSelectedDate.length,
              itemBuilder: (context, index) {
                final log = logsForSelectedDate[index];
                final timeIn = parseServerTime(log['timeIn']);
                final timeOut = log['timeOut'] != null
                    ? parseServerTime(log['timeOut'])
                    : null;


                final duration = timeOut != null
                    ? timeOut.difference(timeIn).inMinutes
                    : null;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Time In',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              formatPhTime(timeIn),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Time Out',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              timeOut != null
                                  ? formatPhTime(timeOut)
                                  : 'Still Active',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Duration',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                              ),
                            ),
                            Text(
                              duration != null
                                  ? '${(duration / 60).floor()}h ${duration % 60}m'
                                  : '--',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium!
                                  .copyWith(
                                color: Colors.black, // Changed to black
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
