import 'package:flutter/material.dart';

class ReadingTargetsScreen extends StatelessWidget {
  const ReadingTargetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Set Reading Targets',
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
              // Profile Card Header
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFF004D40),
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Sample Profile Subject',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                            ),
                            SizedBox(height: 4),
                            Text('ID: M-48202 | Status: Enrolled', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              
              // Metadata Grid
              const Text('Biographical & System Meta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 12),
              
              _buildMetaRow('Assigned Batch/Class', 'Morning Islamic Studies (Class A)'),
              _buildMetaRow('Primary Contact', '+91 98765 43210'),
              _buildMetaRow('Syllabus Completion', 'Grade 4 (82%)'),
              _buildMetaRow('Audit Compliance', '98.5% Checked'),
              _buildMetaRow('Registration Date', 'October 24, 2023'),
              
              const SizedBox(height: 36),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF004D40),
                        side: const BorderSide(color: Color(0xFF004D40)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trigger action flow')),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Modify Info'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700), // Gold
                        foregroundColor: const Color(0xFF004D40),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
        ],
      ),
    );
  }
}
