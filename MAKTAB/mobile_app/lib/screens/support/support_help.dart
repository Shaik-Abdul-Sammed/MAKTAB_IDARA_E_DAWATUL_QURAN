import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class SupportHelpScreen extends StatefulWidget {
  const SupportHelpScreen({super.key});

  @override
  State<SupportHelpScreen> createState() => _SupportHelpScreenState();
}

class _SupportHelpScreenState extends State<SupportHelpScreen> {
  Future<void> _openWhatsAppSupport() async {
    final url = Uri.parse('https://wa.me/919876543210?text=Assalamu%20Alaikum,%20I%20need%20help%20with%20Maktab%20App.');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening WhatsApp Support...')));
      }
    } catch (_) {}
  }

  Future<void> _emailSupport() async {
    final url = Uri.parse('mailto:support@maktabapp.org?subject=Maktab%20App%20Support%20Enquiry');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Email app...')));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {'q': 'How do I mark daily student attendance?', 'a': 'Navigate to Attendance Register, select your class batch and date, then tap Mark Now.'},
      {'q': 'How do I generate fee payment reminders?', 'a': 'Go to Fee Management under Tools, where you can send instant WhatsApp messages or local device notifications.'},
      {'q': 'How to backup Maktab database?', 'a': 'Go to Settings > Backup Database to export an encrypted ZIP backup file.'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Support & Help Desk'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsAppSupport,
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('WhatsApp Help'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _emailSupport,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email Support'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF004D40),
                        side: const BorderSide(color: Color(0xFF004D40)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Frequently Asked Questions (FAQ)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
              const SizedBox(height: 12),

              ...faqs.map((f) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                        const SizedBox(height: 6),
                        Text(f['a']!, style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.7), height: 1.4)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF004D40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.help_center_rounded, color: Color(0xFFFFD700), size: 40),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maktab Support Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 4),
              Text('We are here to assist your institution', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
