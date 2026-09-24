import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/batch.dart';
import '../../models/student.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/teacher_attendance_repository.dart';
import '../../repositories/user_repository.dart';
import '../../utils/attendance_pdf_generator.dart';
import '../../widgets/molecules/custom_app_bar.dart';

enum ReportType { allBatches, singleBatch, singleStudent, singleTeacher }
enum DateRangePreset { today, thisWeek, thisMonth, custom }

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  ReportType _reportType = ReportType.allBatches;
  DateRangePreset _datePreset = DateRangePreset.thisMonth;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  bool _isLoadingInitial = true;
  bool _isGeneratingPdf = false;

  List<Batch> _batches = [];
  List<Student> _students = [];
  List<User> _teachers = [];

  Batch? _selectedBatch;
  Student? _selectedStudent;
  User? _selectedTeacher;

  @override
  void initState() {
    super.initState();
    _applyPreset(DateRangePreset.thisMonth);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoadingInitial = true);
    try {
      final batches = await BatchRepository().getAllBatches();
      final students = await StudentRepository().getAllStudents();
      final teachers = await UserRepository().getAllTeachers();

      if (mounted) {
        setState(() {
          _batches = batches;
          _students = students;
          _teachers = teachers;

          if (_batches.isNotEmpty) _selectedBatch = _batches.first;
          if (_students.isNotEmpty) _selectedStudent = _students.first;
          if (_teachers.isNotEmpty) _selectedTeacher = _teachers.first;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  void _applyPreset(DateRangePreset preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      switch (preset) {
        case DateRangePreset.today:
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DateRangePreset.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          _fromDate = DateTime(monday.year, monday.month, monday.day);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DateRangePreset.thisMonth:
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case DateRangePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004D40),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _datePreset = DateRangePreset.custom;
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final senderName = auth.currentUser?.name ?? 'Maktab Management';
      const maktabName = 'MAKTAB IDARA E DAWATUL QURAN';

      final attRepo = AttendanceRepository();
      final teacherAttRepo = TeacherAttendanceRepository();

      final df = DateFormat('yyyy-MM-dd');
      final filenamePrefix = 'attendance_report_${df.format(_fromDate)}_to_${df.format(_toDate)}';

      switch (_reportType) {
        case ReportType.allBatches:
          final summaryData = await attRepo.getAttendanceSummaryByBatch(
            fromDate: _fromDate,
            toDate: _toDate,
          );
          final bytes = await AttendancePdfGenerator.buildAllBatchesReport(
            maktabName: maktabName,
            fromDate: _fromDate,
            toDate: _toDate,
            batches: _batches,
            dataByBatch: summaryData,
            senderName: senderName,
          );
          await Printing.sharePdf(bytes: bytes, filename: '${filenamePrefix}_all_batches.pdf');
          break;

        case ReportType.singleBatch:
          if (_selectedBatch == null || _selectedBatch!.id == null) {
            throw Exception('Please select a batch.');
          }
          final rows = await attRepo.getStudentAttendanceSummary(
            batchId: _selectedBatch!.id!,
            fromDate: _fromDate,
            toDate: _toDate,
          );
          final bytes = await AttendancePdfGenerator.buildBatchReport(
            maktabName: maktabName,
            batch: _selectedBatch!,
            fromDate: _fromDate,
            toDate: _toDate,
            rows: rows,
            senderName: senderName,
          );
          await Printing.sharePdf(
            bytes: bytes,
            filename: '${filenamePrefix}_batch_${_selectedBatch!.name.replaceAll(' ', '_')}.pdf',
          );
          break;

        case ReportType.singleStudent:
          if (_selectedStudent == null || _selectedStudent!.id == null) {
            throw Exception('Please select a student.');
          }
          final dailyRows = await attRepo.getStudentDailyAttendance(
            studentId: _selectedStudent!.id!,
            fromDate: _fromDate,
            toDate: _toDate,
          );
          final batchName = _batches
              .firstWhere(
                (b) => b.id == _selectedStudent!.batchId,
                orElse: () => Batch(name: 'Unassigned', timing: ''),
              )
              .name;

          final bytes = await AttendancePdfGenerator.buildStudentReport(
            maktabName: maktabName,
            student: _selectedStudent!,
            batchName: batchName,
            fromDate: _fromDate,
            toDate: _toDate,
            dailyRows: dailyRows,
            senderName: senderName,
          );
          await Printing.sharePdf(
            bytes: bytes,
            filename: '${filenamePrefix}_student_${_selectedStudent!.name.replaceAll(' ', '_')}.pdf',
          );
          break;

        case ReportType.singleTeacher:
          if (_selectedTeacher == null) {
            throw Exception('Please select a teacher.');
          }
          final teacherId = _selectedTeacher!.teacherId ?? _selectedTeacher!.id ?? 0;
          final dailyRows = await teacherAttRepo.getTeacherDailyAttendance(
            teacherId: teacherId,
            fromDate: _fromDate,
            toDate: _toDate,
          );
          final bytes = await AttendancePdfGenerator.buildTeacherReport(
            maktabName: maktabName,
            teacher: _selectedTeacher!,
            fromDate: _fromDate,
            toDate: _toDate,
            dailyRows: dailyRows,
            senderName: senderName,
          );
          await Printing.sharePdf(
            bytes: bytes,
            filename: '${filenamePrefix}_teacher_${_selectedTeacher!.name.replaceAll(' ', '_')}.pdf',
          );
          break;
      }
    } catch (e) {
      debugPrint('[AttendanceReportsScreen] PDF Generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate PDF. Try a smaller range.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Attendance Reports'),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8E8D5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF004D40), size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generate PDF Reports',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Export comprehensive attendance records for batches, students, or teachers.',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Report Type Selector
                    const Text('Report Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All Batches'),
                          selected: _reportType == ReportType.allBatches,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _reportType == ReportType.allBatches ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _reportType = ReportType.allBatches),
                        ),
                        ChoiceChip(
                          label: const Text('Single Batch'),
                          selected: _reportType == ReportType.singleBatch,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _reportType == ReportType.singleBatch ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _reportType = ReportType.singleBatch),
                        ),
                        ChoiceChip(
                          label: const Text('Single Student'),
                          selected: _reportType == ReportType.singleStudent,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _reportType == ReportType.singleStudent ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _reportType = ReportType.singleStudent),
                        ),
                        ChoiceChip(
                          label: const Text('Single Teacher'),
                          selected: _reportType == ReportType.singleTeacher,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _reportType == ReportType.singleTeacher ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _reportType = ReportType.singleTeacher),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Contextual Selector Dropdown
                    if (_reportType == ReportType.singleBatch) ...[
                      const Text('Select Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Batch>(
                        initialValue: _selectedBatch,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E8D5))),
                        ),
                        items: _batches.map((b) => DropdownMenuItem(value: b, child: Text('${b.name} (${b.timing})'))).toList(),
                        onChanged: (val) => setState(() => _selectedBatch = val),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_reportType == ReportType.singleStudent) ...[
                      const Text('Select Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Student>(
                        initialValue: _selectedStudent,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E8D5))),
                        ),
                        items: _students.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.admissionNumber})'))).toList(),
                        onChanged: (val) => setState(() => _selectedStudent = val),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_reportType == ReportType.singleTeacher) ...[
                      const Text('Select Teacher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<User>(
                        initialValue: _selectedTeacher,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8E8D5))),
                        ),
                        items: _teachers.map((t) => DropdownMenuItem(value: t, child: Text('${t.name} (${t.mobile ?? 'No Mobile'})'))).toList(),
                        onChanged: (val) => setState(() => _selectedTeacher = val),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Date Range Selector
                    const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _datePreset == DateRangePreset.today,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _datePreset == DateRangePreset.today ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _applyPreset(DateRangePreset.today),
                        ),
                        ChoiceChip(
                          label: const Text('This Week'),
                          selected: _datePreset == DateRangePreset.thisWeek,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _datePreset == DateRangePreset.thisWeek ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _applyPreset(DateRangePreset.thisWeek),
                        ),
                        ChoiceChip(
                          label: const Text('This Month'),
                          selected: _datePreset == DateRangePreset.thisMonth,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _datePreset == DateRangePreset.thisMonth ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _applyPreset(DateRangePreset.thisMonth),
                        ),
                        ChoiceChip(
                          label: const Text('Custom Range'),
                          selected: _datePreset == DateRangePreset.custom,
                          selectedColor: const Color(0xFF004D40),
                          labelStyle: TextStyle(
                            color: _datePreset == DateRangePreset.custom ? Colors.white : const Color(0xFF004D40),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _pickCustomRange(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Display active date range
                    InkWell(
                      onTap: _pickCustomRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD8E8D5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_rounded, color: Color(0xFF004D40), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${df.format(_fromDate)} — ${df.format(_toDate)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40)),
                              ),
                            ),
                            const Text('Change', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Generate PDF Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPdf ? null : _generatePdf,
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Color(0xFF004D40), strokeWidth: 2.5),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(
                          _isGeneratingPdf ? 'Generating PDF...' : 'Generate & Share PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
