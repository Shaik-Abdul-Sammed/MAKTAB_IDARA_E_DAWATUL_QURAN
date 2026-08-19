import 'package:flutter/material.dart';

class QuranProgressSummaryScreen extends StatelessWidget {
  const QuranProgressSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Quran Progress Rate Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40), // Dark green
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistical Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
              const SizedBox(height: 6),
              const Text(
                'View aggregated statistics of memorized chapters and pages.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              
              // Big stat cards grid
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Count', '420', Icons.people, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Performance Rate', '94.2%', Icons.trending_up, Colors.green)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Checklist Compliance', '98.6%', Icons.fact_check, Colors.teal)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('System Errors', '0', Icons.report_problem, Colors.orange)),
                ],
              ),
              const SizedBox(height: 28),
              
              // Progress visualizers
              const Text('Grade Progress Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 16),
              _buildProgressBar('Level 1 Quran Recitation', 0.85, '85% Target Achieved'),
              _buildProgressBar('Level 2 Tajweed Errors', 0.12, '12% Low Error Rates'),
              _buildProgressBar('Level 3 Memorization Target', 0.68, '68% Milestones Logged'),
              
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reports compiled successfully! Exporting file to documents.'),
                      backgroundColor: Color(0xFF004D40),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Export Excel/PDF Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700), // Gold
                  foregroundColor: const Color(0xFF004D40),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String title, double percentage, String caption) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              Text(caption, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFF9FBE7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
