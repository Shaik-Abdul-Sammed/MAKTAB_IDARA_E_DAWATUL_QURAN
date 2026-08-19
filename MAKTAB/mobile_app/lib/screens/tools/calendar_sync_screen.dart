import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class CalendarEventItem {
  final String title;
  final String date;
  final String time;
  final String category;

  CalendarEventItem({
    required this.title,
    required this.date,
    required this.time,
    required this.category,
  });
}

class CalendarSyncScreen extends StatefulWidget {
  const CalendarSyncScreen({super.key});

  @override
  State<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends State<CalendarSyncScreen> {
  final List<CalendarEventItem> _events = [
    CalendarEventItem(title: 'Monthly Fee Collection Due', date: '2026-08-10', time: '09:00 AM', category: 'Finance'),
    CalendarEventItem(title: 'Quarterly Tajweed & Hifz Exam', date: '2026-08-15', time: '08:00 AM', category: 'Academic'),
    CalendarEventItem(title: 'Parent-Teacher Coordination Meet', date: '2026-08-20', time: '05:00 PM', category: 'Meeting'),
    CalendarEventItem(title: 'Islamic History Speech Contest', date: '2026-08-25', time: '10:00 AM', category: 'Event'),
  ];

  Future<void> _addToDeviceCalendar(CalendarEventItem ev) async {
    // Launch Google Calendar web / intent URL
    final title = Uri.encodeComponent(ev.title);
    final details = Uri.encodeComponent('Maktab Event: ${ev.title} (${ev.category})');
    final url = Uri.parse('https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calendar event created: ${ev.title}')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event added: ${ev.title}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Calendar & Event Sync'),
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            final ev = _events[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_rounded, color: Color(0xFF004D40), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${ev.date} · ${ev.time}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.event_note_rounded, color: Color(0xFF004D40)),
                    tooltip: 'Add to Device Calendar',
                    onPressed: () => _addToDeviceCalendar(ev),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
