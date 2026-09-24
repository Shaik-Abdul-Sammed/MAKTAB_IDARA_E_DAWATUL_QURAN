import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/student.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../utils/attendance_report_generator.dart';
import '../../utils/whatsapp_utility.dart';
import '../../utils/receipt_templates.dart';
import '../../utils/receipt_pdf_generator.dart';
import '../../utils/language_resolver.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/voice_attendance_dialog.dart';
import '../../widgets/language_picker_dialog.dart';
import '../../l10n/app_localizations.dart';

class AttendanceEntryScreen extends StatefulWidget {
  final int batchId;
  final String date;

  const AttendanceEntryScreen({
    super.key,
    required this.batchId,
    required this.date,
  });

  @override
  State<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends State<AttendanceEntryScreen>
    with SingleTickerProviderStateMixin {
  late final AttendanceProvider _provider;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _batchName = '';
  String _teacherName = '';
  String? _batchTiming; // e.g. 'Morning', 'Afternoon', 'Evening'
  bool _isToolbarExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _provider = AttendanceProvider(AttendanceRepository(), StudentRepository());
    _provider.setEntryScreenActive(true);
    _provider.setDate(widget.date);
    _provider.setBatchId(widget.batchId);
    _provider.addListener(_autoSaveDraft);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final batch = await BatchRepository().getBatchById(widget.batchId);
      if (batch != null) {
        _batchName = batch.name;
        // Pre-populate time period from batch timing field (if present)
        final timing = batch.timing;
        if (timing.isNotEmpty) {
          _batchTiming = timing;
          _provider.setTimePeriod(timing);
        }
        if (batch.teacherId != null) {
          final teacher = await UserRepository().getUserById(batch.teacherId!);
          if (teacher != null) {
            _teacherName = teacher.name;
          }
        }
      }
      if (_teacherName.isEmpty && mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.currentUser != null) {
          _teacherName = auth.currentUser!.name;
        }
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('[AttendanceEntry] _initData error: $e\n$st');
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_autoSaveDraft);
    _tabController.dispose();
    _searchController.dispose();
    _provider.setEntryScreenActive(false);
    _provider.dispose();
    super.dispose();
  }

  // ── #13: Draft auto-save
  DateTime _lastSave = DateTime.now();
  void _autoSaveDraft() {
    final now = DateTime.now();
    if (now.difference(_lastSave).inSeconds >= 5) {
      _lastSave = now;
      _persistDraft();
    }
  }

  Future<void> _persistDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'draft_attendance_${widget.batchId}_${widget.date}';
      final map = _provider.studentStatuses.entries.map((e) => '${e.key}:${e.value}').join(',');
      await prefs.setString(key, map);
    } catch (e, st) {
      debugPrint('[AttendanceEntry] _persistDraft error: $e\n$st');
    }
  }

  Future<void> _save() async {
    try {
      await _provider.saveAttendance();
      CloudSyncService.instance.notifyDataChanged('attendance');
      // Clear draft
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_attendance_${widget.batchId}_${widget.date}');
      if (!mounted) return;
      _showPostAttendanceSummary();
    } catch (e, st) {
      debugPrint('[AttendanceEntry] _save error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── #11: Status cycle color
  static Color statusColor(String status) {
    switch (status) {
      case 'Present': return Colors.green;
      case 'Absent':  return Colors.red;
      case 'Late':    return Colors.amber.shade700;
      case 'Leave':   return Colors.orange;
      default:        return Colors.grey;
    }
  }
  static IconData statusIcon(String status) {
    switch (status) {
      case 'Present': return Icons.check_circle_rounded;
      case 'Absent':  return Icons.cancel_rounded;
      case 'Late':    return Icons.watch_later_rounded;
      case 'Leave':   return Icons.beach_access_rounded;
      default:        return Icons.help_outline;
    }
  }

  // ── Post-save summary
  void _showPostAttendanceSummary() {
    final present = _provider.students.where((s) => _provider.studentStatuses[s.id] == 'Present').toList();
    final absent  = _provider.students.where((s) => _provider.studentStatuses[s.id] == 'Absent').toList();
    final late    = _provider.students.where((s) => _provider.studentStatuses[s.id] == 'Late').toList();
    final leave   = _provider.students.where((s) => _provider.studentStatuses[s.id] == 'Leave').toList();
    final nonPresent = [...absent, ...late, ...leave];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFFF9FBE7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF004D40),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 28),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Attendance Saved!', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: 'Share Report',
                    onPressed: () => _shareAttendanceReport(present, nonPresent),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    tooltip: 'Export PDF',
                    onPressed: () => _exportPdf(present, absent, late, leave),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () { Navigator.pop(ctx); },
                  ),
                ]),
              ),
              // Stats row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatPill(label: 'Present', count: present.length, color: Colors.green),
                    _StatPill(label: 'Absent',  count: absent.length,  color: Colors.red),
                    _StatPill(label: 'Late',    count: late.length,    color: Colors.amber.shade700),
                    _StatPill(label: 'Leave',   count: leave.length,   color: Colors.orange),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (nonPresent.isNotEmpty) ...[
                      _SectionHeader(label: 'Not Present (${nonPresent.length})', color: Colors.red),
                      ...nonPresent.map((s) {
                        final st = _provider.studentStatuses[s.id!] ?? 'Absent';
                        return _SummaryTile(student: s, status: st, isAbsent: true, date: widget.date);
                      }),
                      const SizedBox(height: 16),
                    ],
                    // ── #14: Bulk notify
                    if (nonPresent.isNotEmpty) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.message_rounded, size: 18),
                        label: const Text('Notify ALL Absent Parents via WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _bulkNotifyAbsent(ctx, nonPresent),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (present.isNotEmpty) ...[
                      _SectionHeader(label: 'Present (${present.length})', color: Colors.green),
                      ...present.map((s) => _SummaryTile(student: s, status: 'Present', isAbsent: false, date: widget.date)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('View Daily & Monthly Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF004D40),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final isTeacherRoute = GoRouterState.of(context).uri.toString().startsWith('/teacher');
                    final target = isTeacherRoute
                        ? '/teacher/attendance/attendance-calendar?batchId=${widget.batchId}'
                        : '/admin/batches/${widget.batchId}/attendance-calendar';
                    context.push(target);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── #14: Bulk notify absent parents
  Future<void> _bulkNotifyAbsent(BuildContext ctx, List<Student> students) async {
    for (final s in students) {
      final phone = s.phone ?? s.guardianPhone ?? '';
      final studentLang = LanguageResolver.forStudent(s);
      if (phone.isNotEmpty && ctx.mounted) {
        await WhatsAppUtility.sendAttendanceAlert(
          ctx,
          phone,
          s.name,
          date: widget.date,
          languageCode: studentLang,
          senderName: _teacherName.isNotEmpty ? _teacherName : 'Maktab Management',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  // ── #15: Share report
  void _shareAttendanceReport(List<Student> present, List<Student> absent) {
    final batchLang = _provider.students.isNotEmpty
        ? LanguageResolver.forStudent(_provider.students.first)
        : 'en';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Share Attendance Report'),
        actions: [
          TextButton(
            child: const Text('WhatsApp Text'),
            onPressed: () {
              Navigator.pop(ctx);
              final text = WhatsAppUtility.buildAttendanceReportText(
                date: widget.date,
                batch: _batchName,
                markedBy: _teacherName,
                present: present.map((s) => s.name).toList(),
                absent: absent.map((s) => s.name).toList(),
                languageCode: batchLang,
              );
              SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          TextButton(
            child: const Text('PDF'),
            onPressed: () async {
              Navigator.pop(ctx);
              final labels = ReceiptTemplates.get(batchLang);
              final bytes = await ReceiptPdfGenerator.buildAttendanceSummaryPdf(
                maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
                batch: _batchName,
                date: widget.date,
                markedBy: _teacherName,
                present: present.map((s) => s.name).toList(),
                absent: absent.map((s) => s.name).toList(),
                labels: labels,
                senderName: _teacherName.isNotEmpty ? _teacherName : 'Maktab Management',
              );
              await Printing.sharePdf(
                bytes: bytes,
                filename: 'attendance_${widget.date}.pdf',
              );
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ── #15: PDF Export
  Future<void> _exportPdf(
      List<Student> present, List<Student> absent, List<Student> late, List<Student> leave) async {
    final doc = await AttendanceReportGenerator.generatePdfReport(
      rawDate: widget.date,
      batchName: _batchName,
      teacherName: _teacherName,
      students: _provider.students,
      studentStatuses: _provider.studentStatuses,
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'attendance_${widget.date}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: '${loc?.translate('attendance') ?? 'Mark Attendance'} (${widget.date})',
          actions: [
            Consumer<AttendanceProvider>(
              builder: (context, p, _) => TextButton(
                onPressed: p.isSaving ? null : _save,
                child: Text((loc?.translate('save') ?? 'SAVE').toUpperCase(), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        body: Consumer<AttendanceProvider>(
          builder: (context, p, _) {
            if (p.status == AttendanceStatus.loading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerListLoader(count: 8, height: 74),
              );
            }
            if (p.status == AttendanceStatus.error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.errorMessage, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => p.loadBatchAttendance(widget.batchId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                // ── #10: Progress bar
                _buildProgressBar(p),
                // ── Compact Expandable Toolbar (replaces Action Bar, Summary Bar, Search)
                _buildExpandableToolbar(p),
                // ── #8: Tabs
                _buildTabs(p),
                // ── Student list
                Expanded(child: _buildStudentList(p)),
              ],
            );
          },
        ),
        bottomNavigationBar: Consumer<AttendanceProvider>(
          builder: (context, p, _) => Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: p.isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF004D40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: p.isSaving
                    ? const CircularProgressIndicator(color: Color(0xFF004D40))
                    : Text(loc?.translate('save_attendance') ?? 'Save Attendance Records', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── #10: Progress bar
  Widget _buildProgressBar(AttendanceProvider p) {
    final total = p.totalCount;
    final confirmed = total; // All are confirmed once loaded (default Present)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF004D40).withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$confirmed / $total students confirmed',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF004D40), fontWeight: FontWeight.w600, height: 1.2)),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text('${p.presentCount} ✅  ${p.absentCount} ❌  ${p.lateCount} 🕒  ${p.leaveCount} 🏖️',
                    style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? confirmed / total : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  void _openVoiceAttendance(AttendanceProvider p) {
    final items = p.students.where((s) => s.id != null).map((s) => VoiceAttendanceItem(
      id: s.id!,
      name: s.name,
      currentStatus: p.studentStatuses[s.id!] ?? 'Present',
    )).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoiceAttendanceDialog(
        title: 'Voice Attendance Assistant',
        items: items,
        onComplete: (updated) {
          updated.forEach((studentId, status) {
            p.setStatus(studentId, status);
          });
        },
      ),
    );
  }

  Widget _buildExpandableToolbar(AttendanceProvider p) {
    final loc = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Time Period selector ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Color(0xFF004D40)),
                const SizedBox(width: 6),
                Text(loc?.translate('period') ?? 'Period:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: Builder(
                      builder: (context) {
                        final validPeriods = [
                          if (_batchTiming != null && _batchTiming!.isNotEmpty) _batchTiming!,
                          ...['Morning', 'Afternoon', 'Evening'].where((t) => t != _batchTiming),
                        ];
                        final effectivePeriod = validPeriods.contains(p.timePeriod) ? p.timePeriod : null;
                        return DropdownButton<String>(
                          value: effectivePeriod,
                          isDense: true,
                          hint: Text(loc?.translate('search') ?? 'Select', style: const TextStyle(fontSize: 12)),
                          items: [
                            if (_batchTiming != null && _batchTiming!.isNotEmpty)
                              DropdownMenuItem(value: _batchTiming!, child: Text('$_batchTiming (${loc?.translate('batches') ?? 'Batch'})', style: const TextStyle(fontSize: 12))),
                            ...['Morning', 'Afternoon', 'Evening']
                                .where((t) => t != _batchTiming)
                                .map((t) => DropdownMenuItem(value: t, child: Text(loc?.translate(t.toLowerCase()) ?? t, style: const TextStyle(fontSize: 12)))),
                          ],
                          onChanged: (val) => p.setTimePeriod(val),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Default: [Mark All Present] [⋮ more] [Search]
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: p.markAllPresent,
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: Text(loc?.translate('mark_all_present') ?? 'Mark All Present', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              IconButton(
                icon: Icon(_isToolbarExpanded ? Icons.expand_less : Icons.more_vert, color: const Color(0xFF004D40), size: 20),
                tooltip: _isToolbarExpanded ? 'Collapse' : 'More options',
                onPressed: () => setState(() => _isToolbarExpanded = !_isToolbarExpanded),
              ),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: p.setSearch,
                    decoration: InputDecoration(
                      hintText: loc?.translate('search') ?? 'Search...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF004D40)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                p.setSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isToolbarExpanded) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Expanded: Clear All, Voice Input, Share WhatsApp
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: p.markAllAbsent,
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: Text(loc?.translate('mark_all_absent') ?? 'Clear All', style: const TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openVoiceAttendance(p),
                    icon: const Icon(Icons.mic_rounded, size: 14),
                    label: Text(loc?.translate('voice_attendance') ?? 'Voice Input', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final present = p.students.where((s) => (p.studentStatuses[s.id] ?? 'Present') == 'Present').toList();
                      final absent = p.students.where((s) => (p.studentStatuses[s.id] ?? 'Present') != 'Present').toList();
                      _shareAttendanceReport(present, absent);
                    },
                    icon: const Icon(Icons.share, size: 14),
                    label: Text(loc?.translate('send_whatsapp') ?? 'Share WhatsApp', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Summary Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: loc?.translate('present') ?? 'Present', value: p.presentCount.toString(), color: Colors.green.shade700),
                  _StatItem(label: loc?.translate('absent') ?? 'Absent',  value: p.absentCount.toString(),  color: Colors.red.shade700),
                  _StatItem(label: loc?.translate('late') ?? 'Late',    value: p.lateCount.toString(),    color: Colors.amber.shade700),
                  _StatItem(label: loc?.translate('leave') ?? 'Leave',   value: p.leaveCount.toString(),   color: Colors.orange.shade700),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── #8: Tabs (All / Present / Absent / Late+Leave)
  Widget _buildTabs(AttendanceProvider p) {
    final loc = AppLocalizations.of(context);
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        onTap: (i) {
          switch (i) {
            case 0: p.setFilterStatus(null); break;
            case 1: p.setFilterStatus('Present'); break;
            case 2: p.setFilterStatus('Absent'); break;
            case 3: p.setFilterStatus('Late'); break;
          }
        },
        labelColor: const Color(0xFF004D40),
        unselectedLabelColor: Colors.black38,
        indicatorColor: const Color(0xFFFFD700),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(text: '${loc?.translate('all_students') ?? 'All'} (${p.totalCount})'),
          Tab(text: '✅ ${p.presentCount}'),
          Tab(text: '❌ ${p.absentCount}'),
          Tab(text: '🕒 ${p.lateCount + p.leaveCount}'),
        ],
      ),
    );
  }

  Widget _buildStudentList(AttendanceProvider p) {
    final students = p.filteredStudents;
    if (students.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search, size: 48, color: Colors.black26),
          const SizedBox(height: 8),
          Text(
            p.searchQuery.isNotEmpty ? 'No students match "${p.searchQuery}"' : 'No students in this category.',
            style: const TextStyle(color: Colors.black45),
          ),
        ]),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index];
        final currentStatus = p.studentStatuses[s.id] ?? 'Present';
        // ── #6: Swipe gestures + #11: 4 status options + #12: Photo avatar
        return _StudentAttendanceTile(
          student: s,
          status: currentStatus,
          index: index + 1,
          onStatusChanged: (ns) { if (s.id != null) p.markStatus(s.id!, ns); },
          onSwipePresent: () { if (s.id != null) p.markStatus(s.id!, 'Present'); },
          onSwipeAbsent: () { if (s.id != null) p.markStatus(s.id!, 'Absent'); },
          onTap: () { if (s.id != null) p.cycleStatus(s.id!); },
        );
      },
    );
  }
}

// ── #6, #11, #12: Student Tile with swipe + photo + 4-status cycle
class _StudentAttendanceTile extends StatelessWidget {
  final Student student;
  final String status;
  final int index;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSwipePresent;
  final VoidCallback onSwipeAbsent;
  final VoidCallback onTap;

  const _StudentAttendanceTile({
    required this.student,
    required this.status,
    required this.index,
    required this.onStatusChanged,
    required this.onSwipePresent,
    required this.onSwipeAbsent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _AttendanceEntryScreenState.statusColor(status);
    final icon  = _AttendanceEntryScreenState.statusIcon(status);
    final photoFile = student.photoPath != null && student.photoPath!.isNotEmpty ? File(student.photoPath!) : null;
    final hasPhoto = photoFile != null && photoFile.existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(student.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onSwipePresent(),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.check_circle_rounded,
              label: 'Present',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => onSwipeAbsent(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.cancel_rounded,
              label: 'Absent',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(children: [
              // ── #12: Photo avatar
              CircleAvatar(
                radius: 22,
                backgroundImage: hasPhoto ? FileImage(photoFile) : null,
                backgroundColor: color.withValues(alpha: 0.2),
                child: hasPhoto
                    ? null
                    : Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('#${student.admissionNumber}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ]),
              ),
              // ── #11: Status badge (tap = cycle through Present→Absent→Late→Leave)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  const Text('tap to cycle', style: TextStyle(fontSize: 9, color: Colors.black38)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    ]);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatPill({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 4, height: 16, color: color, margin: const EdgeInsets.only(right: 8)),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final Student student;
  final String status;
  final bool isAbsent;
  final String date;

  const _SummaryTile({required this.student, required this.status, required this.isAbsent, required this.date});

  @override
  Widget build(BuildContext context) {
    final parentMobile = student.phone ?? student.guardianPhone ?? '';
    final color = _AttendanceEntryScreenState.statusColor(status);
    final photoFile = student.photoPath != null && student.photoPath!.isNotEmpty ? File(student.photoPath!) : null;
    final hasPhoto = photoFile != null && photoFile.existsSync();
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
          backgroundImage: hasPhoto ? FileImage(photoFile) : null,
          backgroundColor: color.withValues(alpha: 0.15),
          child: hasPhoto
              ? null
              : Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (isAbsent && parentMobile.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.call, color: Colors.blue, size: 20),
            tooltip: 'Call Parent',
            onPressed: () async {
              final url = Uri.parse('tel:$parentMobile');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green, size: 20),
            tooltip: 'WhatsApp Parent',
            onPressed: () {
              final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
              WhatsAppUtility.sendAttendanceAlert(
                context,
                parentMobile,
                student.name,
                date: date,
                languageCode: LanguageResolver.forStudent(student),
                senderName: sender,
              );
            },
          ),
        ]
      ]),
    );
  }
}
