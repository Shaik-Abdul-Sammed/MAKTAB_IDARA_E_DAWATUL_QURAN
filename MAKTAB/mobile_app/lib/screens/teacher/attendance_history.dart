import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maktab_app/config/app_colors.dart';
import '../../../models/attendance.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/student_repository.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Attendance> _items = [];
  Map<int, String> _studentNames = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await AttendanceRepository().getAllAttendance();
      final students = await StudentRepository().getAllStudents();
      final names = <int, String>{};
      for (final s in students) {
        if (s.id != null) {
          names[s.id!] = s.name;
        }
      }
      records.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _items = records;
          _studentNames = names;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green.shade700;
      case 'absent':
        return Colors.red.shade700;
      case 'late':
        return Colors.amber.shade800;
      case 'leave':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green.shade50;
      case 'absent':
        return Colors.red.shade50;
      case 'late':
        return Colors.amber.shade50;
      case 'leave':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  String _formatDateHeader(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  void _showDetailSheet(Attendance item) {
    final studentName = _studentNames[item.studentId] ?? 'Unknown (ID ${item.studentId})';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            Text('Date: ${item.date} | Status: ${item.status}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const Divider(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  () {
                    try {
                      return item.toMap().entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                    } catch (_) {
                      return item.toString();
                    }
                  }(), 
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase().trim();
    final filteredItems = _items.where((item) {
      if (q.isEmpty) return true;
      final name = _studentNames[item.studentId]?.toLowerCase() ?? '';
      return item.studentId.toString().contains(q) || name.contains(q);
    }).toList();

    // Group filtered records by date descending
    final Map<String, List<Attendance>> grouped = {};
    for (final item in filteredItems) {
      grouped.putIfAbsent(item.date, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Review Batch Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, overflow: TextOverflow.ellipsis),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by student name or ID...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ),
            
            // List view content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                color: const Color(0xFF004D40),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : filteredItems.isEmpty
                        ? const Center(child: Text('No matching records found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: grouped.length,
                            itemBuilder: (context, groupIndex) {
                              final entry = grouped.entries.elementAt(groupIndex);
                              final date = entry.key;
                              final records = entry.value;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 15, color: Color(0xFF004D40)),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDateHeader(date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF004D40),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF004D40).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${records.length} records',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...records.map((item) {
                                    final studentName = _studentNames[item.studentId] ?? 'Unknown (ID ${item.studentId})';
                                    final statusColor = _statusColor(item.status);
                                    final statusBg = _statusBgColor(item.status);
                                    return Card(
                                      color: Colors.white,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 1,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF004D40),
                                          foregroundColor: Colors.white,
                                          child: Text(
                                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('ID: ${item.studentId}${item.time != null && item.time!.isNotEmpty ? " • ${item.time}" : ""}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                item.status,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
                                          ],
                                        ),
                                        onTap: () => _showDetailSheet(item),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

