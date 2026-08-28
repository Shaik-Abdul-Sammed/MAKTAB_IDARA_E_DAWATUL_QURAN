import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/widgets/teacher/teacher_quick_actions.dart';
import 'package:table_calendar/table_calendar.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final _batchRepo = BatchRepository();
  final _studentRepo = StudentRepository();
  final _teacherAttRepo = TeacherAttendanceRepository();
  final _attRepo = AttendanceRepository();
  StreamSubscription<String>? _syncSub;

  List<Batch> _myBatches = [];
  List<Student> _myStudents = [];
  List<TeacherAttendance> _recentAttendance = [];
  Map<String, int> _monthSummary = {};
  final Map<int, int> _batchPresentCount = {}; // batchId → present today

  bool _isLoading = true;
  int _teacherId = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _syncSub = CloudSyncService.instance.onDataSynced.listen((collection) {
      if (mounted &&
          (collection == 'attendance' ||
              collection == 'students' ||
              collection == 'batches' ||
              collection == 'teacher_attendance' ||
              collection == 'quran_progress')) {
        _load();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _teacherId = auth.currentUser?.id ?? 0;
    if (_teacherId == 0) return;

    setState(() => _isLoading = true);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yearMonth = DateFormat('yyyy-MM').format(DateTime.now());

    final results = await Future.wait([
      _batchRepo.fetchTeacherBatches(_teacherId),
      _studentRepo.getStudentsByTeacher(_teacherId),
      _teacherAttRepo.getAttendanceByTeacher(_teacherId, from: _monthStart(), to: today),
      _teacherAttRepo.getMonthSummary(_teacherId, yearMonth),
    ]);

    final batches = results[0] as List<Batch>;
    final students = results[1] as List<Student>;
    final attendances = results[2] as List<TeacherAttendance>;
    final summary = results[3] as Map<String, int>;

    // Count presents for each batch today
    final Map<int, int> presentCounts = {};
    for (final b in batches) {
      if (b.id == null) continue;
      final recs = await _attRepo.getAttendanceByDateAndBatch(today, b.id!);
      presentCounts[b.id!] =
          recs.where((a) => a.status == 'Present').length;
    }

    if (!mounted) return;
    setState(() {
      _myBatches = batches;
      _myStudents = students;
      _recentAttendance = attendances.take(10).toList();
      _monthSummary = summary;
      _batchPresentCount.clear();
      _batchPresentCount.addAll(presentCounts);
      _isLoading = false;
    });
  }

  String _monthStart() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-01').format(now);
  }

  Future<void> _markAllPresent(Batch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark All Present'),
        content: Text(
          'Mark all students in "${batch.name}" as Present for today?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || batch.id == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final students = await _batchRepo.getStudentsForBatch(batch.id!);
    final existing =
        await _attRepo.getAttendanceByDateAndBatch(today, batch.id!);
    final existingIds =
        existing.map((a) => a.studentId).toSet();

    final toInsert = students
        .where((s) => s.id != null && !existingIds.contains(s.id))
        .map((s) => Attendance(
              studentId: s.id!,
              date: today,
              status: 'Present',
            ))
        .toList();

    if (toInsert.isNotEmpty) {
      await _attRepo.insertAttendances(toInsert);
    }

    if (!mounted) return;
    setState(() {
      _batchPresentCount[batch.id!] = students.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${students.length} students marked Present'),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final teacherName = auth.currentUser?.name ?? 'Teacher';
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
    final yearMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryTeal,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── App bar ─────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 130,
                    floating: true,
                    snap: true,
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00695C), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Assalamu Alaikum,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Ustad $teacherName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              today,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.mail_outline),
                        tooltip: 'Messages',
                        onPressed: () => context.push('/teacher/messages'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline),
                        tooltip: 'Support & Help',
                        onPressed: () => context.push('/teacher/support'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () =>
                            context.push('/teacher/notifications'),
                        tooltip: 'Notifications',
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded),
                        onPressed: () => context.push('/teacher/profile'),
                        tooltip: 'My Profile',
                      ),
                    ],
                  ),

                  // ── Quick Actions ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Quick Actions'),
                          const SizedBox(height: 12),
                          TeacherQuickActions(
                            teacherId: _teacherId,
                            students: _myStudents,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Today's Batches ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _sectionLabel('Today\'s Batches'),
                    ),
                  ),
                  _myBatches.isEmpty
                      ? SliverToBoxAdapter(
                          child: _emptyCard(
                            'No batches assigned yet.\nContact Admin to assign your batches.',
                            Icons.class_outlined,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _BatchTimelineCard(
                              batch: _myBatches[i],
                              presentCount:
                                  _batchPresentCount[_myBatches[i].id] ?? 0,
                              totalCount: _myStudents
                                  .where(
                                      (s) => s.batchId == _myBatches[i].id)
                                  .length,
                              onMarkAllPresent: () =>
                                  _markAllPresent(_myBatches[i]),
                              onTap: () => context.push(
                                '/teacher/attendance',
                              ),
                            ),
                            childCount: _myBatches.length,
                          ),
                        ),

                  // ── My Attendance Submissions ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('My Attendance Submissions'),
                          TextButton(
                            onPressed: () =>
                                context.push('/teacher/my-attendance'),
                            child: const Text(
                              'View All',
                              style: TextStyle(color: AppColors.primaryTeal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _AttendanceSummaryCard(
                        summary: _monthSummary,
                        yearMonth: yearMonth,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 10, 16),
                          lastDay: DateTime.utc(2030, 3, 14),
                          focusedDay: _focusedDay,
                          calendarFormat: CalendarFormat.month,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarStyle: const CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: AppColors.goldAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _recentAttendance.isEmpty
                      ? SliverToBoxAdapter(
                          child: _emptyCard(
                            'No attendance records yet for this month.',
                            Icons.event_busy_rounded,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _AttendanceLogTile(
                              record: _recentAttendance[i],
                            ),
                            childCount: _recentAttendance.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryTeal,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _emptyCard(String message, IconData icon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Batch Timeline Card ──────────────────────────────────────────────────────

class _BatchTimelineCard extends StatelessWidget {
  final Batch batch;
  final int presentCount;
  final int totalCount;
  final VoidCallback onMarkAllPresent;
  final VoidCallback onTap;

  const _BatchTimelineCard({
    required this.batch,
    required this.presentCount,
    required this.totalCount,
    required this.onMarkAllPresent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rate =
        totalCount == 0 ? 0.0 : presentCount / totalCount;
    final ratePercent = (rate * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.05),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryTeal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.class_rounded,
                          color: AppColors.primaryTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryTeal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            batch.timing,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    // Attendance chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: rate >= 0.75
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$presentCount/$totalCount · $ratePercent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: rate >= 0.75
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Thin progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor:
                        AppColors.primaryTeal.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 0.75
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onMarkAllPresent,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark All Present',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Monthly Summary Card ─────────────────────────────────────────────────────

class _AttendanceSummaryCard extends StatelessWidget {
  final Map<String, int> summary;
  final String yearMonth;

  const _AttendanceSummaryCard({
    required this.summary,
    required this.yearMonth,
  });

  @override
  Widget build(BuildContext context) {
    final total = summary['total'] ?? 0;
    final present = summary['present'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$yearMonth Summary',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'No attendance recorded yet'
                : 'You marked attendance on $present of $total days',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip('Present', summary['present'] ?? 0,
                  const Color(0xFF81C784)),
              const SizedBox(width: 8),
              _SummaryChip('Absent', summary['absent'] ?? 0,
                  const Color(0xFFEF9A9A)),
              const SizedBox(width: 8),
              _SummaryChip(
                  'Late', summary['late'] ?? 0, const Color(0xFFFFCC80)),
              const SizedBox(width: 8),
              _SummaryChip(
                  'Leave', summary['leave'] ?? 0, const Color(0xFF90CAF9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Attendance Log Tile ──────────────────────────────────────────────────────

class _AttendanceLogTile extends StatelessWidget {
  final TeacherAttendance record;

  const _AttendanceLogTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_statusIcon(record.status), color: statusColor, size: 18),
        ),
        title: Text(
          record.status,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          record.date,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: record.remarks?.isNotEmpty == true
            ? Tooltip(
                message: record.remarks!,
                child:
                    const Icon(Icons.info_outline_rounded, size: 16, color: Colors.black38),
              )
            : null,
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'present':
        return const Color(0xFF2E7D32);
      case 'absent':
        return const Color(0xFFC62828);
      case 'late':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF1565C0);
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.schedule_rounded;
      default:
        return Icons.beach_access_rounded;
    }
  }
}
