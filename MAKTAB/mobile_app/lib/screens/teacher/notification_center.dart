import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/app_message.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/models/salary_payment.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/message_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';
import 'package:maktab_app/repositories/salary_repository.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  final MessageRepository _messageRepo = MessageRepository();
  final TeacherAttendanceRepository _attendanceRepo =
      TeacherAttendanceRepository();
  final SalaryRepository _salaryRepo = SalaryRepository();

  late TabController _tabController;
  bool _isLoading = true;

  List<AppMessage> _messages = [];
  List<TeacherAttendance> _attendance = [];
  List<SalaryPayment> _salaryPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tid =
          auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;

      final allMsgs = await _messageRepo.getMessagesForUser(tid);
      // Incoming messages (from manager/broadcast)
      final incomingMsgs =
          allMsgs.where((m) => m.senderId != tid).toList();

      final attRecords = await _attendanceRepo.getAttendanceByTeacher(tid);
      final salaryList = await _salaryRepo.getPaymentsForTeacher(tid);

      // Mark bell opened in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final nowStr = DateTime.now().toIso8601String();
      await prefs.setString('teacher_bell_last_seen_$tid', nowStr);
      await prefs.setString('teacher_last_attendance_bell_seen', nowStr);
      await prefs.setString('teacher_last_salary_bell_seen', nowStr);

      if (mounted) {
        setState(() {
          _messages = incomingMsgs;
          _attendance = attRecords;
          _salaryPayments = salaryList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NotificationCenter] Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text(
          'Notification Center',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldAccent,
          indicatorWeight: 3,
          labelColor: AppColors.goldAccent,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              text: 'Messages (${_messages.where((m) => !m.isRead).length})',
            ),
            Tab(
              icon: const Icon(Icons.how_to_reg_outlined, size: 20),
              text: 'Attendance (${_attendance.length})',
            ),
            Tab(
              icon: const Icon(Icons.payments_outlined, size: 20),
              text: 'Salary (${_salaryPayments.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesTab(),
                _buildAttendanceTab(),
                _buildSalaryTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Messages ──────────────────────────────────────────────────────────

  Widget _buildMessagesTab() {
    if (_messages.isEmpty) {
      return _buildEmptyState('No messages received from manager.');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (ctx, i) {
          final m = _messages[i];
          final timeStr =
              DateFormat('dd MMM yyyy, hh:mm a').format(m.timestamp);
          return Card(
            color: m.isRead ? Colors.white : const Color(0xFFE8F5E9),
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: m.isRead
                    ? Colors.grey.shade300
                    : AppColors.primaryTeal.withValues(alpha: 0.15),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: m.isRead ? Colors.grey : AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              title: Text(
                'Manager Message',
                style: TextStyle(
                  fontWeight:
                      m.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(m.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(timeStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
              trailing: m.isRead
                  ? null
                  : const CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.redAccent,
                    ),
              onTap: () async {
                if (!m.isRead && m.id != null) {
                  await _messageRepo.markAsRead(m.id!);
                  setState(() {
                    _messages[i] = m.copyWith(isRead: true);
                  });
                }
                if (mounted) {
                  context.push('/teacher/messages');
                }
              },
            ),
          );
        },
      ),
    );
  }

  // ── Tab 2: Attendance ────────────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return _buildEmptyState('No attendance marks recorded yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _attendance.length,
        itemBuilder: (ctx, i) {
          final a = _attendance[i];
          final color = _statusColor(a.status);
          final timeLabel = a.time?.isNotEmpty == true
              ? '${a.date} (${a.time})'
              : a.date;
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.how_to_reg_rounded, color: color, size: 20),
              ),
              title: Text(
                'Attendance: ${a.status}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    a.remarks?.isNotEmpty == true
                        ? 'Remarks: ${a.remarks}'
                        : 'Recorded for: ${a.date}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(timeLabel,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {
                context.push('/teacher/my-attendance');
              },
            ),
          );
        },
      ),
    );
  }

  // ── Tab 3: Salary ────────────────────────────────────────────────────────────

  Widget _buildSalaryTab() {
    if (_salaryPayments.isEmpty) {
      return _buildEmptyState('No salary payments recorded yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _salaryPayments.length,
        itemBuilder: (ctx, i) {
          final p = _salaryPayments[i];
          final timeStr = p.paymentDate;
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.payments_rounded,
                    color: Color(0xFF2E7D32), size: 20),
              ),
              title: Text(
                'Salary Paid: ₹${p.amount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2E7D32),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Month: ${p.salaryMonth} • Mode: ${p.paymentMode} • ${p.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (p.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(timeStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {
                context.push('/teacher/salary');
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.black45, fontSize: 14)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green.shade700;
      case 'absent':
        return Colors.red.shade700;
      case 'late':
        return Colors.orange.shade800;
      case 'leave':
        return Colors.blue.shade700;
      default:
        return Colors.black87;
    }
  }
}
