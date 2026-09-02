import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _BatchStat {
  final int total;
  final int present;
  final int absent;
  final int marked;
  const _BatchStat({required this.total, required this.present, required this.absent, required this.marked});
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Batch> _batches = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<int, String> _teachers = {};
  Map<int, _BatchStat> _batchStats = {};
  bool _isTeacher = false;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = CloudSyncService.instance.onDataSynced.listen((collection) {
      if (mounted && (collection == 'attendance' || collection == 'students' || collection == 'batches')) {
        _loadBatches();
      }
    });
    _loadBatches();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      _isTeacher = user?.role == 'teacher';
      // Trigger background sync for latest data from cloud
      final maktabId = await CloudSyncService.instance.getMaktabId();
      CloudSyncService.instance.pullAllDataForMaktab(maktabId).catchError((_) => false);

      List<Batch> list;
      if (user?.role == 'teacher' && user?.id != null) {
        list = await BatchRepository().fetchTeacherBatches(user!.id!);
        if (list.isEmpty) {
          list = await BatchRepository().getAllBatches();
        }
      } else {
        list = await BatchRepository().getAllBatches();
      }

      final teachersList = await UserRepository().getAllTeachers();
      final Map<int, String> teacherMap = {for (var t in teachersList) t.id!: t.name};

      // Load stats for each batch
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final repo = AttendanceRepository();
      final Map<int, _BatchStat> stats = {};
      for (final b in list) {
        if (b.id != null) {
          final raw = await repo.getAttendanceCountsForBatchDate(dateStr, b.id!);
          stats[b.id!] = _BatchStat(
            total: raw['total'] ?? 0,
            present: raw['present'] ?? 0,
            absent: raw['absent'] ?? 0,
            marked: raw['marked'] ?? 0,
          );
        }
      }

      if (mounted) {
        setState(() {
          _batches = list;
          _teachers = teacherMap;
          _batchStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load batches.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004D40),
              onPrimary: Colors.white,
              onSurface: Color(0xFF004D40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadBatches();
    }
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _loadBatches();
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadBatches();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final displayDate = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

    // Summary counts
    final totalBatches = _batches.length;
    final markedBatches = _batchStats.values.where((s) => s.marked > 0).length;
    final pendingBatches = totalBatches - markedBatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Attendance Register',
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _pickDate,
            tooltip: 'Change Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBatches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date Banner with arrow navigation (#3, #4)
              _buildDateBanner(displayDate),
              const SizedBox(height: 12),

              // ── Summary Header (#5)
              if (!_isLoading && _errorMessage == null && totalBatches > 0)
                _buildSummaryHeader(totalBatches, markedBatches, pendingBatches),

              const SizedBox(height: 16),
              const Text('Select Batch to Mark Attendance',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 10),

              if (_isLoading) ...[
                ShimmerLoader(height: 110),
                const SizedBox(height: 10),
                ShimmerLoader(height: 110),
                const SizedBox(height: 10),
                ShimmerLoader(height: 110),
              ] else if (_errorMessage != null) ...[
                Center(
                  child: Column(
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadBatches, child: const Text('Retry')),
                    ],
                  ),
                ),
              ] else if (_batches.isEmpty) ...[
                _buildNoBatchesState(),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    final stat = _batchStats[batch.id];
                    return _BatchAttendanceCard(
                      batch: batch,
                      dateStr: formattedDate,
                      teacherName: _teachers[batch.teacherId],
                      stat: stat,
                      isToday: _isToday,
                      onRefresh: _loadBatches,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(int total, int marked, int pending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryChip(label: 'Total Batches', value: '$total', color: const Color(0xFF004D40))),
          Container(width: 1, height: 28, color: Colors.black12),
          Expanded(child: _SummaryChip(label: 'Marked ✅', value: '$marked', color: Colors.green.shade700)),
          Container(width: 1, height: 28, color: Colors.black12),
          Expanded(child: _SummaryChip(label: 'Pending ⏳', value: '$pending', color: Colors.orange.shade700)),
        ],
      ),
    );
  }

  Widget _buildDateBanner(String displayDate) {
    final isNextDisabled = _isToday;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_rounded, color: Color(0xFFFFD700), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Register Date', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.2)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        displayDate,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isToday)
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Today', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Color(0xFFFFD700), size: 20),
                onPressed: _pickDate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _changeDay(-1),
                  icon: const Icon(Icons.chevron_left, size: 16, color: Colors.white70),
                  label: const Text('Prev Day', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isNextDisabled ? null : () => _changeDay(1),
                  icon: const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
                  label: const Text('Next Day', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isNextDisabled ? Colors.white12 : Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Role-aware No Batches empty state ────────────────────────────────────────
extension _NoBatchState on _AttendanceScreenState {
  Widget _buildNoBatchesState() {
    if (_isTeacher) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_off_rounded, size: 56, color: Colors.orange.shade400),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Batch Assigned',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
              const SizedBox(height: 8),
              const Text(
                'You have not been assigned to any batch yet.\n\nPlease contact your Admin to assign you a batch before you can take attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.2)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF004D40), size: 18),
                  SizedBox(width: 8),
                  Text('Ask your Admin to assign\nyou to a batch.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF004D40), fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadBatches,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check Again'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF004D40),
                    side: const BorderSide(color: Color(0xFF004D40))),
              ),
            ],
          ),
        ),
      );
    }
    // Admin view
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_remove, size: 64, color: Colors.black26),
            const SizedBox(height: 16),
            const Text('No Batches Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black45)),
            const SizedBox(height: 8),
            const Text('Create a batch first to start taking attendance.',
                style: TextStyle(color: Colors.black38), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBatches,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _BatchAttendanceCard extends StatelessWidget {
  final Batch batch;
  final String dateStr;
  final String? teacherName;
  final _BatchStat? stat;
  final bool isToday;
  final VoidCallback? onRefresh;

  const _BatchAttendanceCard({
    required this.batch,
    required this.dateStr,
    this.teacherName,
    this.stat,
    required this.isToday,
    this.onRefresh,
  });

  Color get _statusColor {
    if (stat == null || stat!.total == 0) return Colors.grey;
    if (stat!.marked == 0) return isToday ? Colors.orange : Colors.red;
    if (stat!.marked >= stat!.total) return Colors.green;
    return Colors.orange;
  }

  String get _statusLabel {
    if (stat == null || stat!.total == 0) return 'No Students';
    if (stat!.marked == 0) return isToday ? '⏳ Pending' : '❌ Not Marked';
    if (stat!.marked >= stat!.total) return '✅ Complete';
    return '⚠️ Partial';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.groups_rounded, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
                          Text('🕐 ${batch.timing}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          Text('👤 ${teacherName ?? 'Unassigned'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
                if (stat != null && stat!.total > 0) ...[
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stat!.total > 0 ? stat!.marked / stat!.total : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatDot(color: Colors.green, label: '✅ ${stat!.present} Present'),
                      const SizedBox(width: 12),
                      _StatDot(color: Colors.red, label: '❌ ${stat!.absent} Absent'),
                      const Spacer(),
                      Text('${stat!.marked}/${stat!.total} marked', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final isTeacherRoute = GoRouterState.of(context).uri.toString().startsWith('/teacher');
                          final target = isTeacherRoute
                              ? '/teacher/attendance/attendance-calendar?batchId=${batch.id}'
                              : '/admin/batches/${batch.id}/attendance-calendar';
                          context.push(target);
                        },
                        icon: const Icon(Icons.bar_chart_rounded, size: 16),
                        label: const Text('History', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF004D40),
                          side: const BorderSide(color: Color(0xFF004D40)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final isTeacherRoute = GoRouterState.of(context).uri.toString().startsWith('/teacher');
                          final target = isTeacherRoute
                              ? '/teacher/attendance/entry?batchId=${batch.id}&date=$dateStr'
                              : '/admin/attendance/entry?batchId=${batch.id}&date=$dateStr';
                          await context.push(target);
                          onRefresh?.call();
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          stat != null && stat!.marked > 0 ? 'Edit Attendance' : 'Mark Now',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatDot extends StatelessWidget {
  final Color color;
  final String label;
  const _StatDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ]);
  }
}
