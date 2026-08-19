import 'package:flutter/material.dart';
import 'package:maktab_app/widgets/empty_state_widget.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/quran_progress_repository.dart';
import 'package:maktab_app/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsDashboard extends StatefulWidget {
  const ReportsDashboard({super.key});

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> {
  final BatchRepository _batchRepository = BatchRepository();
  final StudentRepository _studentRepository = StudentRepository();
  final QuranProgressRepository _quranProgressRepository = QuranProgressRepository();
  final AiService _aiService = AiService();

  List<Batch> _batches = [];
  Batch? _selectedBatch;
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    final batches = await _batchRepository.getAllBatches();
    setState(() {
      _batches = batches;
      if (_batches.isNotEmpty) {
        _selectedBatch = _batches.first;
        _fetchStudents();
      } else {
        _isLoading = false;
      }
    });
  }

  Future<void> _fetchStudents() async {
    if (_selectedBatch == null) return;
    setState(() => _isLoading = true);
    final students = await _studentRepository.getStudentsByBatch(_selectedBatch!.id!);
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  Future<void> _showAiSummaryDialog(Student student) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating AI Insights...'),
            ],
          ),
        );
      },
    );

    final progress = await _quranProgressRepository.getProgressByStudent(student.id!);

    Map<String, dynamic> data = {
      'total_progress_records': progress.length,
      'recent_surahs': progress.take(3).map((e) => e.surah).toList(),
      'average_grade': 'A',
    };

    final summary = await _aiService.generateStudentReportSummary(student.name, data);

    if (!mounted) return;

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple),
            const SizedBox(width: 10),
            Text('AI Summary - ${student.name}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(summary, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MAKTAB - Idara-e-Dawatul Qur\'an',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Batch Performance Report: ${_selectedBatch?.name ?? 'All'}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['Adm No', 'Student Name', 'Guardian Phone'],
                data: _students.map((s) => [s.admissionNumber, s.name, s.phone ?? 'N/A']).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
              ),
              pw.SizedBox(height: 24),
              pw.Text('Generated by Maktab Quran Management App', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _generatePdfReport() async {
    if (_selectedBatch == null || _students.isEmpty) return;
    final pdf = await _buildPdfDocument();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _sharePdfReport() async {
    if (_selectedBatch == null || _students.isEmpty) return;
    final pdf = await _buildPdfDocument();
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Maktab_Batch_${_selectedBatch!.name.replaceAll(' ', '_')}_Report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Reports & Analysis'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _sharePdfReport,
            tooltip: 'Share PDF Report',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
            tooltip: 'Print PDF Report',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE9F1E9),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Color(0xFF004D40)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<Batch>(
                    isExpanded: true,
                    value: _selectedBatch,
                    underline: const SizedBox(),
                    items: _batches.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBatch = val;
                        _fetchStudents();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.search_off,
                        title: 'No Students Found',
                        message: 'No students found matching your criteria in this batch.',
                      )
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Adm No: ${student.admissionNumber}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                                onPressed: () => _showAiSummaryDialog(student),
                                tooltip: 'AI Summary',
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
