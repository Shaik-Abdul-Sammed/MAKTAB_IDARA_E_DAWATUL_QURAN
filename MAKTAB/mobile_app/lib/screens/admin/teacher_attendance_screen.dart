import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';
import 'package:maktab_app/widgets/voice_attendance_dialog.dart';

/// Admin screen: Mark attendance for ALL teachers for a given date.
/// Features:
/// - Day navigation arrows (← Prev / Next →)
/// - Live Present/Absent/Late/Leave count summary bar
/// - Remarks field per teacher (expandable)
/// - Post-save bottom sheet with WhatsApp notify per absent teacher
/// - Share/export text report
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final UserRepository _userRepository = UserRepository();
  final TeacherAttendanceRepository _attendanceRepository =
      TeacherAttendanceRepository();

  DateTime _selectedDate = DateTime.now();
  List<User> _teachers = [];
  // teacherId → status
  Map<int, String> _attendanceMap = {};
  // teacherId → remarks controller
  final Map<int, TextEditingController> _remarksControllers = {};
  // teacherId → expanded state
  final Map<int, bool> _expanded = {};

  bool _isLoading = true;
  bool _isSaving = false;
  /// teacherId → face-verified flag (optional step)
  final Map<int, bool> _faceVerified = {};
  /// Teachers without a photo (admin notification)
  List<User> get _teachersWithoutPhoto =>
      _teachers.where((t) => t.photoPath == null || t.photoPath!.isEmpty).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _userRepository.getAllTeachers();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendanceList =
          await _attendanceRepository.getAttendanceByDate(dateStr);

      final Map<int, String> loadedAttendance = {};
      final Map<int, String> loadedRemarks = {};

      // Default everyone to Present
      for (final t in teachers) {
        if (t.id != null) loadedAttendance[t.id!] = 'Present';
      }

      for (final record in attendanceList) {
        loadedAttendance[record.teacherId] = record.status;
        if (record.remarks != null && record.remarks!.isNotEmpty) {
          loadedRemarks[record.teacherId] = record.remarks!;
        }
      }

      // Sync controllers
      for (final t in teachers) {
        if (t.id == null) continue;
        if (!_remarksControllers.containsKey(t.id)) {
          _remarksControllers[t.id!] = TextEditingController();
        }
        _remarksControllers[t.id!]!.text = loadedRemarks[t.id!] ?? '';
      }

      if (mounted) {
        setState(() {
          _teachers = teachers;
          _attendanceMap = loadedAttendance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading teachers: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryTeal,
            onPrimary: Colors.white,
            onSurface: AppColors.primaryTeal,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _changeDay(int delta) {
    final next = _selectedDate.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = next);
    _loadData();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day == n.day;
  }

  // Counts
  int get _presentCount =>
      _attendanceMap.values.where((s) => s == 'Present').length;
  int get _absentCount =>
      _attendanceMap.values.where((s) => s == 'Absent').length;
  int get _lateCount => _attendanceMap.values.where((s) => s == 'Late').length;
  int get _leaveCount =>
      _attendanceMap.values.where((s) => s == 'Leave').length;

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final nowTime = DateFormat('hh:mm a').format(DateTime.now());
      for (final teacher in _teachers) {
        if (teacher.id == null) continue;
        final status = _attendanceMap[teacher.id!] ?? 'Present';
        final remarks = _remarksControllers[teacher.id!]?.text.trim();
        await _attendanceRepository.upsertAttendance(TeacherAttendance(
          teacherId: teacher.id!,
          date: dateStr,
          status: status,
          remarks: remarks?.isEmpty == true ? null : remarks,
          time: nowTime,
        ));
      }
      if (mounted) {
        setState(() => _isSaving = false);
        _showPostSaveSummary(dateStr);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving attendance: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPostSaveSummary(String dateStr) {
    final present =
        _teachers.where((t) => t.id != null && _attendanceMap[t.id] == 'Present').toList();
    final absent =
        _teachers.where((t) => t.id != null && _attendanceMap[t.id] == 'Absent').toList();
    final late =
        _teachers.where((t) => t.id != null && _attendanceMap[t.id] == 'Late').toList();
    final leave =
        _teachers.where((t) => t.id != null && _attendanceMap[t.id] == 'Leave').toList();
    final nonPresent = [...absent, ...late, ...leave];

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
              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.goldAccent, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Teacher Attendance Saved — $dateStr',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: 'Share Report',
                      onPressed: () => _shareReport(
                          dateStr, present, absent, late, leave),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(label: 'Present', value: '${present.length}', color: Colors.greenAccent),
                        _MiniStat(label: 'Absent',  value: '${absent.length}',  color: Colors.redAccent),
                        _MiniStat(label: 'Late',    value: '${late.length}',    color: Colors.orangeAccent),
                        _MiniStat(label: 'Leave',   value: '${leave.length}',   color: Colors.blueAccent),
                      ]),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (nonPresent.isNotEmpty) ...[
                      _SectionLabel(label: '❌ Not Present (${nonPresent.length})', color: Colors.red),
                      ...nonPresent.map((t) => _SummaryTeacherTile(
                          teacher: t,
                          status: _attendanceMap[t.id] ?? 'Absent',
                          dateStr: dateStr)),
                      const SizedBox(height: 16),
                    ],
                    if (present.isNotEmpty) ...[
                      _SectionLabel(label: '✅ Present (${present.length})', color: Colors.green),
                      ...present.map((t) => _SummaryTeacherTile(
                          teacher: t, status: 'Present', dateStr: dateStr)),
                    ],
                  ],
                ),
              ),
              // View History Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Full Attendance History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldAccent,
                    foregroundColor: AppColors.primaryTeal,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/admin/teacher-attendance/history');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareReport(String dateStr, List<User> present, List<User> absent,
      List<User> late, List<User> leave) {
    final buf = StringBuffer();
    buf.writeln('📋 Teacher Attendance — $dateStr');
    buf.writeln('─────────────────────');
    buf.writeln('✅ Present (${present.length}): ${present.map((t) => t.name).join(', ')}');
    buf.writeln('❌ Absent (${absent.length}): ${absent.map((t) => t.name).join(', ')}');
    if (late.isNotEmpty) {
      buf.writeln('🕒 Late (${late.length}): ${late.map((t) => t.name).join(', ')}');
    }
    if (leave.isNotEmpty) {
      buf.writeln('🏖️ Leave (${leave.length}): ${leave.map((t) => t.name).join(', ')}');
    }
    buf.writeln('\nFrom: MAKTAB IDARA E DAWATUL QURAN');
    SharePlus.instance.share(ShareParams(text: buf.toString()));
  }

  void _openVoiceAttendance() {
    final items = _teachers.where((t) => t.id != null).map((t) => VoiceAttendanceItem(
      id: t.id!,
      name: t.name,
      currentStatus: _attendanceMap[t.id!] ?? 'Present',
    )).toList();

    showDialog(
      context: context,
      builder: (context) => VoiceAttendanceDialog(
        title: 'Voice Attendance for Teachers',
        items: items,
        onComplete: (updated) {
          setState(() {
            _attendanceMap.addAll(updated);
          });
        },
      ),
    );
  }

  // ── Status toggle buttons ───────────────────────────────────────────────────

  Widget _buildStatusButton(int teacherId, String status, String label, Color color) {
    final isSelected = _attendanceMap[teacherId] == status;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? color : Colors.white,
              foregroundColor: isSelected ? Colors.white : Colors.black54,
              elevation: isSelected ? 3 : 0,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.black12,
                ),
              ),
            ),
            onPressed: () => setState(() => _attendanceMap[teacherId] = status),
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStrFormatted =
        DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Teacher Attendance',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: _openVoiceAttendance,
            tooltip: 'Voice Attendance',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/admin/teacher-attendance/history'),
            tooltip: 'View History',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryTeal))
            : Column(
                children: [
                  // ── Date Banner with arrows ──────────────────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00695C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFF004D40).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.event_note_rounded,
                            color: AppColors.goldAccent, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Register Date',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              Text(dateStrFormatted,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                        if (!_isToday)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = DateTime.now());
                              _loadData();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.goldAccent,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Today',
                                  style: TextStyle(
                                      color: AppColors.primaryTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar,
                              color: AppColors.goldAccent, size: 20),
                          onPressed: () => _selectDate(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _changeDay(-1),
                            icon: const Icon(Icons.chevron_left,
                                size: 18, color: Colors.white70),
                            label: const Text('Prev Day',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isToday ? null : () => _changeDay(1),
                            icon: const Icon(Icons.chevron_right,
                                size: 18, color: Colors.white70),
                            label: const Text('Next Day',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: _isToday
                                        ? Colors.white12
                                        : Colors.white30),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4)),
                          ),
                        ),
                      ]),
                    ]),
                  ),

                  // ── Live summary bar ────────────────────────────────────
                  if (_teachers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatChip(label: 'Present', value: _presentCount, color: Colors.green),
                            _StatChip(label: 'Absent',  value: _absentCount,  color: Colors.red),
                            _StatChip(label: 'Late',    value: _lateCount,    color: Colors.orange),
                            _StatChip(label: 'Leave',   value: _leaveCount,   color: Colors.blue),
                          ],
                        ),
                      ),
                    ),

                  // ── ⚠️ No-Photo Warning Banner ─────────────────────────
                  if (_teachersWithoutPhoto.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_teachersWithoutPhoto.length} teacher(s) missing profile photo — Face Verification disabled for them.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8D4E00)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/admin/teachers'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 28)),
                            child: const Text('Fix', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ),

                  // ── Bulk actions ─────────────────────────────────────────
                  if (_teachers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              for (final t in _teachers) {
                                if (t.id != null) {
                                  _attendanceMap[t.id!] = 'Present';
                                }
                              }
                            }),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('All Present', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade700,
                                side: BorderSide(color: Colors.green.shade700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              for (final t in _teachers) {
                                if (t.id != null) {
                                  _attendanceMap[t.id!] = 'Absent';
                                }
                              }
                            }),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('All Absent', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade700)),
                          ),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 8),

                  // ── Teachers List ──────────────────────────────────────
                  Expanded(
                    child: _teachers.isEmpty
                        ? const Center(
                            child: Text(
                              'No teachers registered in the system.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 15),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _teachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _teachers[index];
                              if (teacher.id == null) {
                                return const SizedBox.shrink();
                              }
                              final id = teacher.id!;
                              final hasPhoto = teacher.photoPath != null &&
                                  teacher.photoPath!.isNotEmpty &&
                                  File(teacher.photoPath!).existsSync();
                              final status = _attendanceMap[id] ?? 'Present';
                              final statusColor = _statusColor(status);
                              final isExpanded = _expanded[id] ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border(
                                      left: BorderSide(
                                          color: statusColor, width: 4)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Teacher info row
                                          Row(children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundImage: hasPhoto
                                                  ? FileImage(
                                                      File(teacher.photoPath!))
                                                  : null,
                                              backgroundColor: statusColor
                                                  .withValues(alpha: 0.18),
                                              child: !hasPhoto
                                                  ? Text(
                                                      teacher.name.isNotEmpty
                                                          ? teacher.name[0]
                                                              .toUpperCase()
                                                          : 'T',
                                                      style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(teacher.name,
                                                        style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                                0xFF1A1A1A))),
                                                    Text(
                                                        teacher.mobile ??
                                                            'No Mobile',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .textMuted)),
                                                  ]),
                                            ),
                                            // Status badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: statusColor
                                                          .withValues(
                                                              alpha: 0.4))),
                                              child: Text(status,
                                                  style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                          ]),
                                          const SizedBox(height: 10),
                                          // 4 status buttons
                                          Row(children: [
                                            _buildStatusButton(id, 'Present', 'Present', Colors.green),
                                            _buildStatusButton(id, 'Absent',  'Absent',  Colors.red),
                                            _buildStatusButton(id, 'Late',    'Late',    Colors.orange),
                                            _buildStatusButton(id, 'Leave',   'Leave',   Colors.blue),
                                          ]),
                                          // ── Optional Face Verification ──
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  if (!hasPhoto) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(children: [
                                                          const Icon(Icons.warning_amber, color: Colors.white, size: 18),
                                                          const SizedBox(width: 8),
                                                          Expanded(child: Text('${teacher.name} has no profile photo. Please add one to enable Face Verification.')),
                                                        ]),
                                                        backgroundColor: Colors.orange.shade700,
                                                        duration: const Duration(seconds: 4),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  final result = await context.push<bool>(
                                                    '/admin/teacher-attendance/face',
                                                  );
                                                  if (result == true) {
                                                    setState(() => _faceVerified[id] = true);
                                                  }
                                                },
                                                icon: Icon(
                                                  (_faceVerified[id] ?? false)
                                                    ? Icons.verified_user_rounded
                                                    : (hasPhoto ? Icons.face_retouching_natural : Icons.no_photography_rounded),
                                                  size: 15,
                                                  color: (_faceVerified[id] ?? false)
                                                    ? Colors.green.shade700
                                                    : (hasPhoto ? const Color(0xFF004D40) : Colors.grey),
                                                ),
                                                label: Text(
                                                  (_faceVerified[id] ?? false)
                                                    ? 'Face Verified ✓'
                                                    : (hasPhoto ? 'Face Verify (Optional)' : 'No Photo — Skip'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: (_faceVerified[id] ?? false)
                                                      ? Colors.green.shade700
                                                      : (hasPhoto ? const Color(0xFF004D40) : Colors.grey),
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: (_faceVerified[id] ?? false)
                                                      ? Colors.green.shade400
                                                      : (hasPhoto ? const Color(0xFF004D40).withValues(alpha: 0.4) : Colors.grey.shade300),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  backgroundColor: (_faceVerified[id] ?? false)
                                                    ? Colors.green.withValues(alpha: 0.05)
                                                    : null,
                                                ),
                                              ),
                                            ),
                                          ]),
                                          // Remarks toggle
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => _expanded[id] = !isExpanded),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8),
                                              child: Row(children: [
                                                Icon(
                                                    isExpanded
                                                        ? Icons.keyboard_arrow_up
                                                        : Icons
                                                            .keyboard_arrow_down,
                                                    size: 18,
                                                    color: Colors.black38),
                                                const Text('Add Remarks',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black38)),
                                              ]),
                                            ),
                                          ),
                                          if (isExpanded)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: TextField(
                                                controller:
                                                    _remarksControllers[id],
                                                maxLines: 2,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Optional remarks (e.g. sick leave, permission)',
                                                  filled: true,
                                                  fillColor: Colors.grey
                                                      .shade50,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 8),
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      borderSide:
                                                          BorderSide.none),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // ── Save Button ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4)),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed:
                            _teachers.isEmpty || _isSaving ? null : _saveAttendance,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Save Daily Attendance',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'Present': return Colors.green;
      case 'Absent':  return Colors.red;
      case 'Late':    return Colors.orange;
      default:        return Colors.blue;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
  ]);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
  ]);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 4, height: 16, color: color, margin: const EdgeInsets.only(right: 8)),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]),
  );
}

class _SummaryTeacherTile extends StatelessWidget {
  final User teacher;
  final String status;
  final String dateStr;
  const _SummaryTeacherTile({required this.teacher, required this.status, required this.dateStr});

  static Color _statusColor(String s) {
    switch (s) {
      case 'Present': return Colors.green;
      case 'Absent':  return Colors.red;
      case 'Late':    return Colors.orange;
      default:        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final isAbsent = status != 'Present';
    final phone = teacher.mobile ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'T',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (isAbsent && phone.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.call, color: Colors.blue, size: 20),
            tooltip: 'Call Teacher',
            onPressed: () async {
              final url = Uri.parse('tel:$phone');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.green, size: 20),
            tooltip: 'WhatsApp Teacher',
            onPressed: () async {
              final msg = Uri.encodeComponent(
                  'السلام عليكم! آپ کی حاضری ($dateStr) غیر حاضر درج کی گئی ہے۔\n\nFrom: MAKTAB IDARA E DAWATUL QURAN');
              final url = Uri.parse('https://wa.me/$phone?text=$msg');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ]),
    );
  }
}
