import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../models/batch.dart';
import '../../models/student.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/shimmer_loader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT — shown after attendance is submitted (or via History button)
// Replaces the old calendar view with a clean, results-focused layout
// ─────────────────────────────────────────────────────────────────────────────

class BatchAttendanceCalendarScreen extends StatefulWidget {
  final int batchId;

  const BatchAttendanceCalendarScreen({super.key, required this.batchId});

  @override
  State<BatchAttendanceCalendarScreen> createState() =>
      _BatchAttendanceCalendarScreenState();
}

class _BatchAttendanceCalendarScreenState
    extends State<BatchAttendanceCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Attendance> _allAttendance = [];
  List<Student> _batchStudents = [];
  Batch? _batch;
  bool _isLoading = true;

  // Selected month for monthly view
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final attRepo = AttendanceRepository();
      final stuRepo = StudentRepository();
      final batchRepo = BatchRepository();

      final batch = await batchRepo.getBatchById(widget.batchId);
      final atts = await attRepo.getAttendanceForBatch(widget.batchId);
      final students = await stuRepo.getStudentsByBatch(widget.batchId);

      if (mounted) {
        setState(() {
          _batch = batch;
          _allAttendance = atts;
          _batchStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns all unique dates that have attendance records, sorted descending.
  List<String> get _attendanceDates {
    final dates = _allAttendance.map((a) => a.date).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  Map<String, int> _getStatsForDate(String dateStr) {
    final records = _allAttendance.where((a) => a.date == dateStr).toList();
    int present = 0, absent = 0, late = 0, leave = 0;
    for (final r in records) {
      switch (r.status.toLowerCase()) {
        case 'present': present++; break;
        case 'absent':  absent++;  break;
        case 'late':    late++;    break;
        default:        leave++;   break;
      }
    }
    return {'present': present, 'absent': absent, 'late': late, 'leave': leave, 'total': records.length};
  }

  Map<String, int> _getMonthlyStats(DateTime month) {
    final monthStr = DateFormat('yyyy-MM').format(month);
    final records = _allAttendance.where((a) => a.date.startsWith(monthStr)).toList();
    int present = 0, absent = 0, late = 0, leave = 0;
    for (final r in records) {
      switch (r.status.toLowerCase()) {
        case 'present': present++; break;
        case 'absent':  absent++;  break;
        case 'late':    late++;    break;
        default:        leave++;   break;
      }
    }
    final days = records.map((r) => r.date).toSet().length;
    return {'present': present, 'absent': absent, 'late': late, 'leave': leave, 'total': records.length, 'days': days};
  }

  List<String> get _datesForSelectedMonth {
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    return _attendanceDates.where((d) => d.startsWith(monthStr)).toList();
  }

  Color _rateColor(int present, int total) {
    if (total == 0) return Colors.grey;
    final rate = present / total;
    if (rate >= 0.85) return Colors.green;
    if (rate >= 0.60) return Colors.orange;
    return Colors.red;
  }

  // ── Day Detail Bottom Sheet ─────────────────────────────────────────────────

  void _showDayDetails(String dateStr) {
    final records = _allAttendance.where((a) => a.date == dateStr).toList();
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance records for this date.')));
      return;
    }

    final stats = _getStatsForDate(dateStr);
    final displayDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dateStr));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FBE7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              // ── Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFF004D40),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    Row(children: [
                      const Icon(Icons.event_note_rounded, color: Color(0xFFFFD700)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(displayDate, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                    ]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _MiniStat(label: 'Present', value: '${stats['present']}', color: Colors.greenAccent),
                      _MiniStat(label: 'Absent',  value: '${stats['absent']}',  color: Colors.redAccent),
                      _MiniStat(label: 'Late',    value: '${stats['late']}',    color: Colors.orangeAccent),
                      _MiniStat(label: 'Leave',   value: '${stats['leave']}',   color: Colors.blueAccent),
                    ]),
                  ],
                ),
              ),
              // ── Student list
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final att = records[i];
                    final student = _batchStudents.firstWhere(
                      (s) => s.id == att.studentId,
                      orElse: () => Student(name: 'Unknown', admissionNumber: '', createdAt: ''),
                    );
                    final color = _statusColor(att.status);
                    final icon  = _statusIcon(att.status);
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('ADM: ${student.admissionNumber}', style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Text(att.status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ── Mark Attendance Again button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Edit Attendance for this Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF004D40),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/admin/attendance/entry?batchId=${widget.batchId}&date=$dateStr');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'present': return Colors.green;
      case 'absent':  return Colors.red;
      case 'late':    return Colors.orange;
      default:        return Colors.blue;
    }
  }

  static IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'present': return Icons.check_circle_rounded;
      case 'absent':  return Icons.cancel_rounded;
      case 'late':    return Icons.watch_later_rounded;
      default:        return Icons.beach_access_rounded;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: Text(
          _batch != null ? '${_batch!.name} — Records' : 'Attendance Records',
          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData, tooltip: 'Refresh'),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Mark Today',
            onPressed: () {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              context.push('/admin/attendance/entry?batchId=${widget.batchId}&date=$today');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFFFD700),
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Daily Results'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Monthly Summary'),
          ],
        ),
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16), child: ShimmerListLoader(count: 6, height: 80))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyResultsTab(),
                _buildMonthlySummaryTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Daily Results — List of days with attendance submitted ───────────

  Widget _buildDailyResultsTab() {
    if (_attendanceDates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_busy_rounded,
        message: 'No attendance records yet.',
        sub: 'Tap "Mark Today" above to start.',
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceDates.length,
      itemBuilder: (context, i) {
        final dateStr = _attendanceDates[i];
        final stats = _getStatsForDate(dateStr);
        final total = stats['total'] ?? 0;
        final present = stats['present'] ?? 0;
        final absent = stats['absent'] ?? 0;
        final late = stats['late'] ?? 0;
        final leave = stats['leave'] ?? 0;
        final rate = total > 0 ? present / total : 0.0;
        final dotColor = _rateColor(present, total);
        final displayDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dateStr));
        final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

        return GestureDetector(
          onTap: () => _showDayDetails(dateStr),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: dotColor, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.event_note_rounded, color: dotColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayDate,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isToday ? const Color(0xFF004D40) : Colors.black87),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      ),
                    const SizedBox(width: 6),
                    Text('$total students', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
                  ]),
                  const SizedBox(height: 10),
                  // Attendance bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? rate : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(dotColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    _DotStat(color: Colors.green, label: '$present Present'),
                    const SizedBox(width: 10),
                    _DotStat(color: Colors.red, label: '$absent Absent'),
                    const SizedBox(width: 10),
                    if (late > 0) _DotStat(color: Colors.orange, label: '$late Late'),
                    if (late > 0) const SizedBox(width: 10),
                    if (leave > 0) _DotStat(color: Colors.blue, label: '$leave Leave'),
                    const Spacer(),
                    Text('${(rate * 100).round()}% present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dotColor)),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab 2: Monthly Summary ──────────────────────────────────────────────────

  Widget _buildMonthlySummaryTab() {
    final monthlyStats = _getMonthlyStats(_selectedMonth);
    final datesInMonth = _datesForSelectedMonth;
    final totalStudents = _batchStudents.length;

    return Column(
      children: [
        // Month selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Color(0xFF004D40)),
              onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                color: _selectedMonth.isBefore(DateTime.now()) ? const Color(0xFF004D40) : Colors.black26),
              onPressed: _selectedMonth.isBefore(DateTime.now())
                  ? () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1))
                  : null,
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monthly stats card
                _buildMonthlyStatsCard(monthlyStats, datesInMonth.length, totalStudents),
                const SizedBox(height: 20),
                // Per-day breakdown
                if (datesInMonth.isEmpty)
                  _buildEmptyState(
                    icon: Icons.calendar_month_rounded,
                    message: 'No records for ${DateFormat("MMMM yyyy").format(_selectedMonth)}.',
                    sub: 'Attendance taken on other months will appear here.',
                  )
                else ...[
                  const Text('Daily Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                  const SizedBox(height: 10),
                  ...datesInMonth.map((dateStr) {
                    final stats = _getStatsForDate(dateStr);
                    final total = stats['total'] ?? 0;
                    final present = stats['present'] ?? 0;
                    final dotColor = _rateColor(present, total);
                    final displayDate = DateFormat('EEE, dd MMM').format(DateTime.parse(dateStr));
                    return GestureDetector(
                      onTap: () => _showDayDetails(dateStr),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: dotColor, width: 3)),
                        ),
                        child: Row(children: [
                          Expanded(child: Text(displayDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          _DotStat(color: Colors.green, label: '$present ✅'),
                          const SizedBox(width: 8),
                          _DotStat(color: Colors.red, label: '${stats['absent']} ❌'),
                          const SizedBox(width: 8),
                          Text('${(total > 0 ? (present / total * 100) : 0).round()}%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dotColor)),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: Colors.black26, size: 16),
                        ]),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyStatsCard(Map<String, int> stats, int activeDays, int totalStudents) {
    final present = stats['present'] ?? 0;
    final total = stats['total'] ?? 0;
    final rate = total > 0 ? (present / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF004D40).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 10),
            Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const SizedBox(height: 4),
          Text('$activeDays class days · $totalStudents enrolled students',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _MiniStat(label: 'Present',  value: '${stats['present']}',  color: Colors.greenAccent),
            _MiniStat(label: 'Absent',   value: '${stats['absent']}',   color: Colors.redAccent),
            _MiniStat(label: 'Late',     value: '${stats['late']}',     color: Colors.orangeAccent),
            _MiniStat(label: 'Leave',    value: '${stats['leave']}',    color: Colors.blueAccent),
          ]),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Overall Presence Rate', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('$rate%', style: TextStyle(color: rate >= 80 ? Colors.greenAccent : rate >= 60 ? Colors.orangeAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 20)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? present / total : 0,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate >= 80 ? Colors.greenAccent : rate >= 60 ? Colors.orangeAccent : Colors.redAccent,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message, required String sub}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black45), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 13, color: Colors.black38), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER-FACING: Attendance Screen with batch restriction + empty state
// ─────────────────────────────────────────────────────────────────────────────

class _DotStat extends StatelessWidget {
  final Color color;
  final String label;
  const _DotStat({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]);
  }
}
