import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudentAttendanceLogScreen extends StatefulWidget {
  const StudentAttendanceLogScreen({super.key});

  @override
  State<StudentAttendanceLogScreen> createState() => _StudentAttendanceLogScreenState();
}

class _StudentAttendanceLogScreenState extends State<StudentAttendanceLogScreen> {
  List<Student> _students = [];
  Student? _selectedStudent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Monthly Attendance Log'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Student', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                DropdownButtonFormField<Student>(
                  initialValue: _selectedStudent,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _students.map((s) {
                    return DropdownMenuItem<Student>(
                      value: s,
                      child: Text(s.name, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStudent = val),
                ),
              const SizedBox(height: 24),

              if (_selectedStudent != null) ...[
                _buildAttendanceSummaryCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummaryCard() {
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
          Text('Attendance Log: ${_selectedStudent!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Present', '22 Days', Colors.green.shade700),
              _buildMetric('Absent', '2 Days', Colors.red.shade700),
              _buildMetric('Leave', '1 Day', Colors.orange.shade700),
            ],
          ),
          const Divider(height: 24),
          const Text('Recent Log Entries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          _buildDayRow('2026-08-05', 'Present', Colors.green),
          _buildDayRow('2026-08-04', 'Present', Colors.green),
          _buildDayRow('2026-08-03', 'Absent', Colors.red),
          _buildDayRow('2026-08-02', 'Present', Colors.green),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _buildDayRow(String date, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
