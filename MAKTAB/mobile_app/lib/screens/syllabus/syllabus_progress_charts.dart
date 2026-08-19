import 'package:flutter/material.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class SyllabusProgressChartsScreen extends StatelessWidget {
  const SyllabusProgressChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Syllabus Progress Analytics'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maktab Overall Progress Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
              const SizedBox(height: 16),

              _buildProgressBar('Noorani Qaida Track', 1.0, '100% Completed (120 Students)', Colors.green.shade700),
              const SizedBox(height: 16),
              _buildProgressBar('Nazira Quran Reading', 0.75, '75% Completed (90 Students)', Colors.teal.shade700),
              const SizedBox(height: 16),
              _buildProgressBar('Hifz-ul-Quran (Juz 1-30)', 0.40, '40% Completed (48 Students)', const Color(0xFFFFD700)),
              const SizedBox(height: 16),
              _buildProgressBar('Daily Supplications & Tajweed', 0.85, '85% Completed (102 Students)', Colors.orange.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(String title, double progress, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}
