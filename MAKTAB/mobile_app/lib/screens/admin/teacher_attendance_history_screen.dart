import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';

/// Screen for displaying full attendance history of a teacher.
/// Features:
/// - Dropdown selector for teacher
/// - Auto-selects teacher if [initialTeacherId] is passed via route query parameter
/// - Period/Month Filter (e.g. Current Month, Previous Month, All Time)
/// - Attendance Stats Summary Card (Present %, Late, Leave, Absent)
/// - Live search filter (filter by remarks or status)
/// - Export report to WhatsApp / Share sheet
class TeacherAttendanceHistoryScreen extends StatefulWidget {
  final int? initialTeacherId;
  const TeacherAttendanceHistoryScreen({super.key, this.initialTeacherId});

  @override
  State<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends State<TeacherAttendanceHistoryScreen> {
  final UserRepository _userRepository = UserRepository();
  final TeacherAttendanceRepository _attendanceRepository =
      TeacherAttendanceRepository();

  List<User> _teachers = [];
  User? _selectedTeacher;
  List<TeacherAttendance> _history = [];
  List<TeacherAttendance> _filteredHistory = [];

  bool _isLoading = true;

  // Filters
  String _selectedPeriod = 'Current Month'; // 'Current Month', 'Last Month', 'All'
  final TextEditingController _searchController = TextEditingController();

  // Summary counts
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _leaveCount = 0;
  double _attendanceRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _userRepository.getAllTeachers();
      User? defaultTeacher;
      if (widget.initialTeacherId != null) {
        final matches = teachers.where((t) => t.id == widget.initialTeacherId);
        if (matches.isNotEmpty) {
          defaultTeacher = matches.first;
        }
      }
      if (defaultTeacher == null && teachers.isNotEmpty) {
        defaultTeacher = teachers.first;
      }

      setState(() {
        _teachers = teachers;
        _selectedTeacher = defaultTeacher;
      });

      if (defaultTeacher != null) {
        await _loadHistory(defaultTeacher.id!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading teachers: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadHistory(int teacherId) async {
    setState(() => _isLoading = true);
    try {
      // Get all records first
      final allHistory =
          await _attendanceRepository.getAttendanceByTeacher(teacherId);

      setState(() {
        _history = allHistory;
        _applyFiltersAndStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading history: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _onTeacherChanged(User? teacher) {
    if (teacher == null) return;
    setState(() {
      _selectedTeacher = teacher;
    });
    _loadHistory(teacher.id!);
  }

  void _onPeriodChanged(String? newPeriod) {
    if (newPeriod == null) return;
    setState(() {
      _selectedPeriod = newPeriod;
      _applyFiltersAndStats();
    });
  }

  void _onSearchChanged() {
    _applyFiltersAndStats();
  }

  void _applyFiltersAndStats() {
    final now = DateTime.now();
    final currentMonthStr = DateFormat('yyyy-MM').format(now);
    final lastMonthStr =
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1));

    List<TeacherAttendance> filtered = _history;

    // Apply Period Filter
    if (_selectedPeriod == 'Current Month') {
      filtered =
          filtered.where((rec) => rec.date.startsWith(currentMonthStr)).toList();
    } else if (_selectedPeriod == 'Last Month') {
      filtered =
          filtered.where((rec) => rec.date.startsWith(lastMonthStr)).toList();
    }

    // Apply Search Filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((rec) {
        final remarksMatch =
            rec.remarks?.toLowerCase().contains(query) ?? false;
        final statusMatch = rec.status.toLowerCase().contains(query);
        final dateMatch = rec.date.contains(query);
        return remarksMatch || statusMatch || dateMatch;
      }).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    // Calculate Stats
    int p = 0, ab = 0, lt = 0, lv = 0;
    for (final rec in filtered) {
      final status = rec.status.toLowerCase();
      if (status == 'present') p++;
      if (status == 'absent') ab++;
      if (status == 'late') lt++;
      if (status == 'leave') lv++;
    }

    final total = p + ab + lt + lv;
    // Late counts as 0.5 Present, Leave counts as 1.0 Present (standard Maktab policy)
    final double presentEquivalent = p + lv + (lt * 0.5);
    final rate = total > 0 ? (presentEquivalent / total) * 100 : 0.0;

    setState(() {
      _filteredHistory = filtered;
      _presentCount = p;
      _absentCount = ab;
      _lateCount = lt;
      _leaveCount = lv;
      _attendanceRate = rate;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return AppColors.success;
      case 'Absent':
        return AppColors.error;
      case 'Late':
        return Colors.orange;
      case 'Leave':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _exportReport() {
    if (_selectedTeacher == null) return;
    final buf = StringBuffer();
    buf.writeln('📋 Teacher Attendance Report');
    buf.writeln('👤 Name: ${_selectedTeacher!.name}');
    buf.writeln('📅 Period: $_selectedPeriod');
    buf.writeln('────────────────────────');
    buf.writeln('✅ Present: $_presentCount');
    buf.writeln('❌ Absent: $_absentCount');
    buf.writeln('🕒 Late: $_lateCount');
    buf.writeln('🏖️ Leave: $_leaveCount');
    buf.writeln('📈 Attendance Rate: ${_attendanceRate.toStringAsFixed(1)}%');
    buf.writeln('────────────────────────');
    buf.writeln('Detailed log:');
    for (final rec in _filteredHistory) {
      final parsedDate = DateTime.tryParse(rec.date) ?? DateTime.now();
      final dateFormatted = DateFormat('dd MMM yyyy (E)').format(parsedDate);
      buf.writeln('- $dateFormatted: ${rec.status} ${rec.remarks != null ? "(${rec.remarks})" : ""}');
    }
    buf.writeln('\nFrom: MAKTAB IDARA E DAWATUL QURAN');

    SharePlus.instance.share(ShareParams(text: buf.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Attendance History',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedTeacher != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _exportReport,
              tooltip: 'Share Report',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filters & Selectors ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Teacher select row
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF004D40)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<User>(
                            value: _selectedTeacher,
                            hint: const Text('Select a Teacher'),
                            isExpanded: true,
                            icon: const Icon(
                                Icons.arrow_drop_down_circle_outlined,
                                color: Color(0xFF004D40)),
                            items: _teachers.map((User teacher) {
                              return DropdownMenuItem<User>(
                                value: teacher,
                                child: Text(
                                  teacher.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A)),
                                ),
                              );
                            }).toList(),
                            onChanged: _onTeacherChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Period select row
                  Row(
                    children: [
                      const Text('Period: ',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: ['Current Month', 'Last Month', 'All'].map((p) {
                            final isSelected = _selectedPeriod == p;
                            return ChoiceChip(
                              label: Text(p),
                              selected: isSelected,
                              selectedColor: const Color(0xFF004D40),
                              labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontSize: 12),
                              onSelected: (_) => _onPeriodChanged(p),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Stats card ──────────────────────────────────────────────────
            if (_selectedTeacher != null && !_isLoading)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF004D40).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Present rate gauge
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.white12, shape: BoxShape.circle),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_attendanceRate.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: AppColors.goldAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                            const Text(
                              'Rate',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Counter Grid
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_selectedPeriod Summary',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _MiniStat(
                                  label: 'Present',
                                  value: '$_presentCount',
                                  color: Colors.greenAccent),
                              _MiniStat(
                                  label: 'Absent',
                                  value: '$_absentCount',
                                  color: Colors.redAccent),
                              _MiniStat(
                                  label: 'Late',
                                  value: '$_lateCount',
                                  color: Colors.orangeAccent),
                              _MiniStat(
                                  label: 'Leave',
                                  value: '$_leaveCount',
                                  color: Colors.blueAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Live search box ──────────────────────────────────────────────
            if (_selectedTeacher != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search remarks or status...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            // ── History Log List ──────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryTeal))
                  : _filteredHistory.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching attendance records found.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _filteredHistory.length,
                          itemBuilder: (context, index) {
                            final record = _filteredHistory[index];
                            final parsedDate =
                                DateTime.tryParse(record.date) ?? DateTime.now();
                            final dateFormatted =
                                DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);
                            final statusColor = _getStatusColor(record.status);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.calendar_month_rounded,
                                        color: statusColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      dateFormatted,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    subtitle: record.remarks != null &&
                                            record.remarks!.isNotEmpty
                                        ? Text(
                                            record.remarks!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted),
                                          )
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: statusColor.withValues(
                                                alpha: 0.4),
                                            width: 1),
                                      ),
                                      child: Text(
                                        record.status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      );
}
