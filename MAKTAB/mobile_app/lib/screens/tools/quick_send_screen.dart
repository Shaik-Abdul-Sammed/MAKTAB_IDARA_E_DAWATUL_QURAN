import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/user_repository.dart';
import '../../utils/language_resolver.dart';
import '../../utils/receipt_templates.dart';
import '../../utils/receipt_pdf_generator.dart';
import '../../utils/whatsapp_utility.dart';
import '../../widgets/molecules/custom_app_bar.dart';

enum QuickSendDocType {
  feeReceipt,
  salaryReceipt,
  attendanceReport,
  sabaqUpdate,
  announcement,
}

enum RecipientRole {
  student,
  teacher,
  manager,
}

class QuickSendScreen extends StatefulWidget {
  const QuickSendScreen({super.key});

  @override
  State<QuickSendScreen> createState() => _QuickSendScreenState();
}

class _QuickSendScreenState extends State<QuickSendScreen> {
  final _formKey = GlobalKey<FormState>();

  QuickSendDocType _docType = QuickSendDocType.feeReceipt;
  RecipientRole _recipientRole = RecipientRole.student;

  List<Student> _students = [];
  List<User> _teachers = [];
  User? _manager;

  Student? _selectedStudent;
  User? _selectedTeacher;

  bool _isLoading = true;

  // Language state (Phase 6)
  String _selectedLanguage = 'en';

  // Fee receipt fields
  final _amountCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _feePaymentMode = 'Cash';

  // Salary fields
  final _salaryAmountCtrl = TextEditingController();
  final _salaryMonthCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  String _salaryPaymentMode = 'Cash';

  // Attendance fields
  final _batchNameCtrl = TextEditingController();
  final _attDateCtrl = TextEditingController();
  final _presentListCtrl = TextEditingController();
  final _absentListCtrl = TextEditingController();

  // Sabaq fields
  final _surahCtrl = TextEditingController();
  final _ayahFromCtrl = TextEditingController(text: '1');
  final _ayahToCtrl = TextEditingController(text: '10');
  String _recitationType = 'Nazra';
  String _sabaqGrade = 'A';
  final _sabaqRemarksCtrl = TextEditingController();

  // Announcement fields
  final _announcementTitleCtrl = TextEditingController();
  final _announcementBodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthCtrl.text = DateFormat('MMMM yyyy').format(now);
    _salaryMonthCtrl.text = DateFormat('MMMM yyyy').format(now);
    _attDateCtrl.text = DateFormat('dd MMM yyyy').format(now);
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _monthCtrl.dispose();
    _notesCtrl.dispose();
    _salaryAmountCtrl.dispose();
    _salaryMonthCtrl.dispose();
    _upiCtrl.dispose();
    _batchNameCtrl.dispose();
    _attDateCtrl.dispose();
    _presentListCtrl.dispose();
    _absentListCtrl.dispose();
    _surahCtrl.dispose();
    _ayahFromCtrl.dispose();
    _ayahToCtrl.dispose();
    _sabaqRemarksCtrl.dispose();
    _announcementTitleCtrl.dispose();
    _announcementBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final sRepo = StudentRepository();
      final uRepo = UserRepository();

      final students = await sRepo.getAllStudents();
      final teachers = await uRepo.getAllTeachers();
      final manager = await uRepo.getAdminUser();

      if (mounted) {
        setState(() {
          _students = students;
          _teachers = teachers;
          _manager = manager;

          if (_students.isNotEmpty) {
            _onSelectStudent(_students.first);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSelectStudent(Student? s) {
    _selectedStudent = s;
    if (s != null) {
      _selectedLanguage = LanguageResolver.forStudent(s);
    }
    setState(() {});
  }

  void _onSelectTeacher(User? t) {
    _selectedTeacher = t;
    if (t != null) {
      _selectedLanguage = LanguageResolver.forUser(t);
      if (t.monthlySalary != null && t.monthlySalary! > 0) {
        _salaryAmountCtrl.text = t.monthlySalary!.toInt().toString();
      }
      if (t.upiId != null) {
        _upiCtrl.text = t.upiId!;
      }
    }
    setState(() {});
  }

  String _getRecipientPhone() {
    switch (_recipientRole) {
      case RecipientRole.student:
        return _selectedStudent?.guardianPhone ?? _selectedStudent?.phone ?? '';
      case RecipientRole.teacher:
        return _selectedTeacher?.mobile ?? '';
      case RecipientRole.manager:
        return _manager?.mobile ?? '';
    }
  }

  String _getRecipientName() {
    switch (_recipientRole) {
      case RecipientRole.student:
        return _selectedStudent?.name ?? 'Student';
      case RecipientRole.teacher:
        return _selectedTeacher?.name ?? 'Teacher';
      case RecipientRole.manager:
        return _manager?.name ?? 'Manager';
    }
  }

  String _buildFormattedMessage() {
    final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
    final t = ReceiptTemplates.get(_selectedLanguage);

    switch (_docType) {
      case QuickSendDocType.feeReceipt:
        final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
        final studentName = _selectedStudent?.name ?? _getRecipientName();
        final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
        final buf = StringBuffer();
        buf.writeln('*${t['feeHeader'] ?? t['header']}*');
        buf.writeln('${t['date']}: $nowStr');
        buf.writeln('${t['feeReceivedBy'] ?? t['receivedBy']}: $sender');
        buf.writeln();
        buf.writeln('*${t['student']}:* $studentName');
        buf.writeln('${t['feeAmount'] ?? t['amount']}: ₹${amt.toInt() == amt ? amt.toInt() : amt}');
        buf.writeln('${t['feeMode'] ?? t['mode']}: $_feePaymentMode');
        if (_notesCtrl.text.trim().isNotEmpty) {
          buf.writeln('${t['notes']}: ${_notesCtrl.text.trim()}');
        }
        buf.writeln();
        buf.writeln(t['feeThankYou'] ?? t['footer']);
        buf.writeln('\n${t['commonRegards'] ?? 'Regards,'}\n*$sender*');
        return buf.toString();

      case QuickSendDocType.salaryReceipt:
        final amt = double.tryParse(_salaryAmountCtrl.text.trim()) ?? 0;
        final teacherName = _selectedTeacher?.name ?? _getRecipientName();
        final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
        final buf = StringBuffer();
        buf.writeln('*${t['salaryHeader']}*');
        buf.writeln('${t['date']}: $nowStr');
        buf.writeln('${t['salaryMonth']}: ${_salaryMonthCtrl.text.trim()}');
        buf.writeln('${t['salaryPaidTo']}: $teacherName');
        buf.writeln('${t['salaryAmount'] ?? t['amount']}: ₹${amt.toInt() == amt ? amt.toInt() : amt}');
        buf.writeln('${t['salaryMode'] ?? t['mode']}: $_salaryPaymentMode');
        buf.writeln('${t['salaryIssuedBy']}: $sender');
        if (_upiCtrl.text.trim().isNotEmpty) {
          buf.writeln('UPI ID: ${_upiCtrl.text.trim()}');
        }
        buf.writeln();
        buf.writeln(t['salaryThankYou'] ?? t['footer']);
        buf.writeln('\n${t['commonRegards'] ?? 'Regards,'}\n*$sender*');
        return buf.toString();

      case QuickSendDocType.attendanceReport:
        final prList = _presentListCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final abList = _absentListCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        return WhatsAppUtility.buildAttendanceReportText(
          date: _attDateCtrl.text.trim(),
          present: prList.isNotEmpty ? prList : [_getRecipientName()],
          absent: abList,
          batch: _batchNameCtrl.text.trim().isNotEmpty ? _batchNameCtrl.text.trim() : null,
          markedBy: sender,
          languageCode: _selectedLanguage,
        );

      case QuickSendDocType.sabaqUpdate:
        final studentName = _selectedStudent?.name ?? _getRecipientName();
        final admNo = _selectedStudent?.admissionNumber ?? '—';
        final nowStr = DateFormat('dd MMM yyyy').format(DateTime.now());
        final note = _sabaqRemarksCtrl.text.trim().isNotEmpty
            ? _sabaqRemarksCtrl.text.trim()
            : (t['sabaqDefaultNote'] ?? 'Alhamdulillah, completed with care.');

        final buf = StringBuffer();
        buf.writeln(t['sabaqBismillah'] ?? 'بسم الله الرحمن الرحيم');
        buf.writeln();
        buf.writeln(t['sabaqSalam'] ?? 'السلام عليكم ورحمة الله وبركاته');
        buf.writeln();
        buf.writeln(t['sabaqGreeting'] ?? 'Respected Parent/Guardian,');
        buf.writeln();
        buf.writeln("${t['sabaqIntro'] ?? "We are pleased to share today's Sabaq progress for your child,"} *$studentName* (Adm. No. $admNo).");
        buf.writeln();
        buf.writeln('━━━━━━━━━━━━━━━━━━━━');
        buf.writeln('📖 *${t['sabaqDetailsHeader'] ?? 'Sabaq Details'}*');
        buf.writeln('━━━━━━━━━━━━━━━━━━━━');
        buf.writeln('• *${t['sabaqSurahLabel'] ?? 'Surah'}:* ${_surahCtrl.text.trim()}');
        buf.writeln('• *${t['sabaqAyahLabel'] ?? 'Ayah'}:* ${_ayahFromCtrl.text.trim()}–${_ayahToCtrl.text.trim()}');
        buf.writeln('• *${t['sabaqTypeLabel'] ?? 'Type'}:* $_recitationType');
        buf.writeln('• *${t['sabaqGradeLabel'] ?? 'Grade'}:* $_sabaqGrade');
        buf.writeln('• *${t['sabaqDateLabel'] ?? 'Date'}:* $nowStr');
        buf.writeln();
        buf.writeln('━━━━━━━━━━━━━━━━━━━━');
        buf.writeln('📝 *${t['sabaqNoteHeader'] ?? "Teacher's Note"}*');
        buf.writeln('━━━━━━━━━━━━━━━━━━━━');
        buf.writeln(note);
        buf.writeln();
        buf.writeln(t['sabaqEncouragement'] ?? 'We encourage daily revision at home.');
        buf.writeln();
        buf.writeln(t['sabaqDua'] ?? "May Allah bless your child in learning the Qur'an.");
        buf.writeln();
        buf.writeln(t['sabaqJazak'] ?? 'جزاك الله خيرًا');
        buf.writeln();
        buf.writeln(t['sabaqRegards'] ?? 'Warm regards,');
        buf.writeln('*$sender*');
        buf.writeln('MAKTAB IDARA E DAWATUL QURAN');
        return buf.toString();

      case QuickSendDocType.announcement:
        final buf = StringBuffer();
        buf.writeln(t['announcementHeader'] ?? 'Maktab Management — Announcement');
        buf.writeln();
        buf.writeln('📢 *${_announcementTitleCtrl.text.trim()}*');
        buf.writeln();
        buf.writeln(_announcementBodyCtrl.text.trim());
        buf.writeln();
        buf.writeln(t['commonThanks'] ?? 'Jazak Allah Khair.');
        buf.writeln('\n${t['commonRegards'] ?? 'Regards,'}\n*$sender*');
        return buf.toString();
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final sender = context.read<AuthProvider>().currentUser?.name ?? 'Maktab Management';
    final labels = ReceiptTemplates.get(_selectedLanguage);

    switch (_docType) {
      case QuickSendDocType.feeReceipt:
        final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
        final studentName = _selectedStudent?.name ?? _getRecipientName();
        final admNo = _selectedStudent?.admissionNumber ?? '—';
        return ReceiptPdfGenerator.buildFeeReceiptPdf(
          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
          collectorName: sender,
          recordedAt: DateTime.now(),
          children: [
            {
              'name': studentName,
              'admissionNumber': admNo,
              'amount': amt,
              'mode': _feePaymentMode,
              'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
            }
          ],
          labels: labels,
          languageCode: _selectedLanguage,
          senderName: sender,
        );

      case QuickSendDocType.salaryReceipt:
        final amt = int.tryParse(_salaryAmountCtrl.text.trim()) ?? 0;
        final teacherName = _selectedTeacher?.name ?? _getRecipientName();
        return ReceiptPdfGenerator.buildSalaryReceiptPdf(
          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
          teacherName: teacherName,
          salaryMonth: _salaryMonthCtrl.text.trim(),
          amount: amt,
          paymentMode: _salaryPaymentMode,
          paymentDate: DateTime.now(),
          issuedBy: sender,
          labels: labels,
          languageCode: _selectedLanguage,
          senderName: sender,
          transactionReference: _upiCtrl.text.trim().isNotEmpty ? _upiCtrl.text.trim() : null,
        );

      case QuickSendDocType.attendanceReport:
        final prList = _presentListCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final abList = _absentListCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        return ReceiptPdfGenerator.buildAttendanceSummaryPdf(
          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
          batch: _batchNameCtrl.text.trim().isNotEmpty ? _batchNameCtrl.text.trim() : 'General',
          date: _attDateCtrl.text.trim(),
          markedBy: sender,
          present: prList.isNotEmpty ? prList : [_getRecipientName()],
          absent: abList,
          labels: labels,
          languageCode: _selectedLanguage,
          senderName: sender,
        );

      case QuickSendDocType.sabaqUpdate:
        final studentName = _selectedStudent?.name ?? _getRecipientName();
        final admNo = _selectedStudent?.admissionNumber ?? '—';
        return ReceiptPdfGenerator.buildSabaqReceiptPdf(
          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
          studentName: studentName,
          admissionNumber: admNo,
          surah: _surahCtrl.text.trim(),
          ayahFrom: _ayahFromCtrl.text.trim(),
          ayahTo: _ayahToCtrl.text.trim(),
          recitationType: _recitationType,
          grade: _sabaqGrade,
          date: DateFormat('dd MMM yyyy').format(DateTime.now()),
          remarks: _sabaqRemarksCtrl.text.trim().isNotEmpty ? _sabaqRemarksCtrl.text.trim() : null,
          labels: labels,
          languageCode: _selectedLanguage,
          senderName: sender,
        );

      case QuickSendDocType.announcement:
        return ReceiptPdfGenerator.buildAttendanceSummaryPdf(
          maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
          batch: _announcementTitleCtrl.text.trim().isNotEmpty ? _announcementTitleCtrl.text.trim() : 'Announcement',
          date: DateFormat('dd MMM yyyy').format(DateTime.now()),
          markedBy: sender,
          present: [_announcementBodyCtrl.text.trim()],
          absent: [],
          labels: labels,
          languageCode: _selectedLanguage,
          senderName: sender,
        );
    }
  }

  void _showPreviewSheet() {
    final msg = _buildFormattedMessage();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (sheetCtx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Message & PDF Preview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  msg,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Share PDF'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _sharePdf();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Send WhatsApp', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendWhatsApp();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    final phone = _getRecipientPhone();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient phone number is missing.')),
      );
      return;
    }

    final msg = _buildFormattedMessage();
    await WhatsAppUtility.launchWhatsApp(phone, msg, context: context);
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await _generatePdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: 'quick_send_${_docType.name}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Send to Anyone'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Document Type
                      _buildSectionHeader('1. Select Document Type'),
                      _buildDocTypeSelector(),
                      const SizedBox(height: 16),

                      // Section 2: Recipient
                      _buildSectionHeader('2. Recipient'),
                      _buildRecipientSection(),
                      const SizedBox(height: 16),

                      // Section 3: Document Fields
                      _buildSectionHeader('3. Document Details'),
                      _buildDocSpecificFields(),
                      const SizedBox(height: 16),

                      // Section 4: Preferred Language
                      _buildSectionHeader('4. Message & Document Language'),
                      _buildLanguageSection(),
                      const SizedBox(height: 24),

                      // Section 5: Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showPreviewSheet,
                              icon: const Icon(Icons.preview_rounded),
                              label: const Text('Preview'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sendWhatsApp,
                              icon: const Icon(Icons.send_rounded, color: Colors.white),
                              label: const Text('Send WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _sharePdf,
                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF004D40)),
                          label: const Text('Export / Share PDF', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF004D40)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
      ),
    );
  }

  Widget _buildDocTypeSelector() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _docTypeChip(QuickSendDocType.feeReceipt, 'Fee Receipt', Icons.receipt_long),
            _docTypeChip(QuickSendDocType.salaryReceipt, 'Salary Receipt', Icons.payments),
            _docTypeChip(QuickSendDocType.attendanceReport, 'Attendance Report', Icons.calendar_month),
            _docTypeChip(QuickSendDocType.sabaqUpdate, 'Sabaq Update', Icons.menu_book),
            _docTypeChip(QuickSendDocType.announcement, 'Announcement', Icons.campaign),
          ],
        ),
      ),
    );
  }

  Widget _docTypeChip(QuickSendDocType type, String label, IconData icon) {
    final isSelected = _docType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF004D40)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: const Color(0xFF004D40),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF004D40),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _docType = type;
            if (type == QuickSendDocType.salaryReceipt) {
              _recipientRole = RecipientRole.teacher;
              if (_teachers.isNotEmpty) _onSelectTeacher(_teachers.first);
            } else if (type == QuickSendDocType.feeReceipt || type == QuickSendDocType.sabaqUpdate) {
              _recipientRole = RecipientRole.student;
              if (_students.isNotEmpty) _onSelectStudent(_students.first);
            }
          });
        }
      },
    );
  }

  Widget _buildRecipientSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _roleChip(RecipientRole.student, 'Student / Parent'),
                  const SizedBox(width: 8),
                  _roleChip(RecipientRole.teacher, 'Teacher'),
                  const SizedBox(width: 8),
                  _roleChip(RecipientRole.manager, 'Manager'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_recipientRole == RecipientRole.student) ...[
              DropdownButtonFormField<Student>(
                key: ValueKey('student_${_selectedStudent?.id}'),
                initialValue: _selectedStudent,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Student',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _students.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s.name} (${s.admissionNumber}) — ${s.guardianPhone ?? s.phone ?? 'No Phone'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: _onSelectStudent,
              ),
            ] else if (_recipientRole == RecipientRole.teacher) ...[
              DropdownButtonFormField<User>(
                key: ValueKey('teacher_${_selectedTeacher?.id}'),
                initialValue: _selectedTeacher,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Teacher',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _teachers.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(
                    '${t.name} (ID: ${t.teacherId ?? t.id}) — ${t.mobile ?? 'No Mobile'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: _onSelectTeacher,
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Color(0xFF004D40), child: Icon(Icons.admin_panel_settings, color: Colors.white)),
                title: Text(_manager?.name ?? 'Maktab Manager'),
                subtitle: Text(_manager?.mobile ?? 'No Mobile'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleChip(RecipientRole role, String label) {
    final isSelected = _recipientRole == role;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: const Color(0xFF004D40),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF004D40),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _recipientRole = role;
            if (role == RecipientRole.student && _students.isNotEmpty) {
              _onSelectStudent(_students.first);
            } else if (role == RecipientRole.teacher && _teachers.isNotEmpty) {
              _onSelectTeacher(_teachers.first);
            } else if (role == RecipientRole.manager && _manager != null) {
              _selectedLanguage = LanguageResolver.forUser(_manager!);
            }
          });
        }
      },
    );
  }

  Widget _buildDocSpecificFields() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_docType == QuickSendDocType.feeReceipt) ...[
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fee Amount (₹)', prefixIcon: Icon(Icons.currency_rupee), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monthCtrl,
                decoration: const InputDecoration(labelText: 'Fee Month (e.g. October 2026)', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _feePaymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setState(() => _feePaymentMode = v ?? 'Cash'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.note), border: OutlineInputBorder()),
              ),
            ] else if (_docType == QuickSendDocType.salaryReceipt) ...[
              TextFormField(
                controller: _salaryAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Salary Amount (₹)', prefixIcon: Icon(Icons.currency_rupee), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryMonthCtrl,
                decoration: const InputDecoration(labelText: 'Salary Month (e.g. October 2026)', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _salaryPaymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', prefixIcon: Icon(Icons.payment), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setState(() => _salaryPaymentMode = v ?? 'Cash'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _upiCtrl,
                decoration: const InputDecoration(labelText: 'UPI ID / Reference (Optional)', prefixIcon: Icon(Icons.fingerprint), border: OutlineInputBorder()),
              ),
            ] else if (_docType == QuickSendDocType.attendanceReport) ...[
              TextFormField(
                controller: _batchNameCtrl,
                decoration: const InputDecoration(labelText: 'Batch Name (e.g. Morning Hifz)', prefixIcon: Icon(Icons.groups), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _attDateCtrl,
                decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _presentListCtrl,
                decoration: const InputDecoration(labelText: 'Present Students (comma separated)', prefixIcon: Icon(Icons.check_circle_outline), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _absentListCtrl,
                decoration: const InputDecoration(labelText: 'Absent Students (comma separated)', prefixIcon: Icon(Icons.highlight_off), border: OutlineInputBorder()),
              ),
            ] else if (_docType == QuickSendDocType.sabaqUpdate) ...[
              TextFormField(
                controller: _surahCtrl,
                decoration: const InputDecoration(labelText: 'Surah / Lesson Name', prefixIcon: Icon(Icons.menu_book), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ayahFromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ayah / Page From', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ayahToCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ayah / Page To', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _recitationType,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Nazra', child: Text('Nazra')),
                        DropdownMenuItem(value: 'Hifz', child: Text('Hifz')),
                        DropdownMenuItem(value: 'Noorani Qaida', child: Text('Noorani Qaida')),
                        DropdownMenuItem(value: 'Revision', child: Text('Revision')),
                      ],
                      onChanged: (v) => setState(() => _recitationType = v ?? 'Nazra'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sabaqGrade,
                      decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'A+', child: Text('A+ (Mumtaz)')),
                        DropdownMenuItem(value: 'A', child: Text('A (Jayyid Jiddan)')),
                        DropdownMenuItem(value: 'B', child: Text('B (Jayyid)')),
                        DropdownMenuItem(value: 'C', child: Text('C (Maqbool)')),
                      ],
                      onChanged: (v) => setState(() => _sabaqGrade = v ?? 'A'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sabaqRemarksCtrl,
                decoration: const InputDecoration(labelText: "Teacher's Note / Remarks", prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder()),
              ),
            ] else if (_docType == QuickSendDocType.announcement) ...[
              TextFormField(
                controller: _announcementTitleCtrl,
                decoration: const InputDecoration(labelText: 'Announcement Title', prefixIcon: Icon(Icons.title), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _announcementBodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message Body', prefixIcon: Icon(Icons.message), border: OutlineInputBorder()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language auto-selected from recipient preferences. You may change it below for this send:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('lang_$_selectedLanguage'),
              initialValue: _selectedLanguage,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.translate, color: Color(0xFF004D40)),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'en', child: SizedBox(width: 200, child: Text('🇬🇧 English', maxLines: 1, overflow: TextOverflow.ellipsis))),
                DropdownMenuItem(value: 'ur', child: SizedBox(width: 200, child: Text('🇵🇰 اردو (Urdu)', maxLines: 1, overflow: TextOverflow.ellipsis))),
                DropdownMenuItem(value: 'hi', child: SizedBox(width: 200, child: Text('🇮🇳 हिंदी (Hindi)', maxLines: 1, overflow: TextOverflow.ellipsis))),
                DropdownMenuItem(value: 'te', child: SizedBox(width: 200, child: Text('🇮🇳 తెలుగు (Telugu)', maxLines: 1, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedLanguage = v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
