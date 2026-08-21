import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/bulk_fee_messaging_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class WhatsAppReminderScreen extends StatefulWidget {
  const WhatsAppReminderScreen({super.key});

  @override
  State<WhatsAppReminderScreen> createState() => _WhatsAppReminderScreenState();
}

class _WhatsAppReminderScreenState extends State<WhatsAppReminderScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  List<Student> _students = [];
  Student? _selectedStudent;
  bool _isLoading = true;

  final Map<String, String> _templates = {
    'Fee Due Reminder': 'Assalamu Alaikum, kindly note that the monthly fee for {StudentName} is due from MAKTAB IDARA E DAWATUL QURAN. JazakAllah Khair.',
    'Absence Alert': 'Assalamu Alaikum, {StudentName} was absent today from MAKTAB IDARA E DAWATUL QURAN. Please let us know if everything is fine.',
    'Exam Notice': 'Assalamu Alaikum, the quarterly Quran recitation evaluation for {StudentName} will be held next week at MAKTAB IDARA E DAWATUL QURAN.',
    'General Notice': 'Assalamu Alaikum, MAKTAB IDARA E DAWATUL QURAN will remain closed tomorrow for Islamic Holiday.',
  };

  @override
  void initState() {
    super.initState();
    _msgCtrl.text = _templates['Fee Due Reminder']!;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final list = await StudentRepository().getAllStudents();
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
          if (list.isNotEmpty) _selectedStudent = list.first;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBulkBatchMessaging() async {
    final batches = await BatchRepository().getAllBatches();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => BulkFeeMessagingDialog(batches: batches),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsApp() async {
    if (_selectedStudent == null) return;
    final phone = _selectedStudent!.phone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final text = _msgCtrl.text.replaceAll('{StudentName}', _selectedStudent!.name);

    final url = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $phone')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'WhatsApp Broadcast & Reminders'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              const SizedBox(height: 20),

              const Text('Select Student / Guardian', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              _buildStudentDropdown(),
              const SizedBox(height: 20),

              const Text('Choose Message Template', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.keys.map((k) {
                  return ActionChip(
                    label: Text(k, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD8E8D5)),
                    onPressed: () => setState(() => _msgCtrl.text = _templates[k]!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              const Text('Message Body', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _msgCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E8D5))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF004D40))),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sendWhatsApp,
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Open WhatsApp & Send', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.shade800,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.chat_rounded, color: Colors.white, size: 34),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parent Communication', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Send direct WhatsApp updates to guardians', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openBulkBatchMessaging,
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Bulk Batch Fee Messages', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF004D40),
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDropdown() {
    if (_isLoading) return const CircularProgressIndicator();
    return DropdownButtonFormField<Student>(
      initialValue: _selectedStudent,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: _students.map((s) {
        return DropdownMenuItem<Student>(
          value: s,
          child: Text('${s.name} (${s.phone ?? 'No phone'})', style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedStudent = val),
    );
  }
}
