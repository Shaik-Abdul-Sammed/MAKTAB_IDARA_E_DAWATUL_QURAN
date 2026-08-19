import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudentAcademicHistoryScreen extends StatefulWidget {
  const StudentAcademicHistoryScreen({super.key});

  @override
  State<StudentAcademicHistoryScreen> createState() => _StudentAcademicHistoryScreenState();
}

class _StudentAcademicHistoryScreenState extends State<StudentAcademicHistoryScreen> {
  List<Student> _students = [];
  Student? _selectedStudent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final list = await StudentRepository().getAllStudents();
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
          if (list.isNotEmpty) _selectedStudent = list.first;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printTranscript() async {
    if (_selectedStudent == null) return;
    final s = _selectedStudent!;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('MAKTAB - Idara-e-Dawatul Qur\'an',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                ),
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('STUDENT ACADEMIC TRANSCRIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Student Name: ${s.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Admission Number: ${s.admissionNumber}'),
                pw.Text('Father Name: ${s.fatherName ?? 'N/A'}'),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['Evaluation Date', 'Surah & Juz', 'Score / Grade', 'Remarks'],
                  data: [
                    ['2026-07-15', 'Surah Al-Baqarah (1-50)', 'Grade A+ (Mumtaz)', 'Excellent pronunciation'],
                    ['2026-06-10', 'Surah Yasin (Full)', 'Grade A', 'Fluent recitation'],
                    ['2026-05-05', 'Surah Al-Mulk', 'Grade A', 'Good makhraj'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                ),
                pw.Spacer(),
                pw.Center(child: pw.Text('Certified by Maktab Administration', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Academic History & Transcript',
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _printTranscript,
            tooltip: 'Print Transcript PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Student Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                DropdownButtonFormField<Student>(
                  initialValue: _selectedStudent,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _students.map((s) {
                    return DropdownMenuItem<Student>(
                      value: s,
                      child: Text(s.name, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStudent = val),
                ),
              const SizedBox(height: 24),

              if (_selectedStudent != null) ...[
                _buildTranscriptCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Academic History: ${_selectedStudent!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
          const Divider(height: 20),
          _buildRecordRow('15 Jul 2026', 'Surah Al-Baqarah (1-50)', 'Grade A+ (Mumtaz)'),
          const Divider(),
          _buildRecordRow('10 Jun 2026', 'Surah Yasin (Full)', 'Grade A (Jayyid)'),
          const Divider(),
          _buildRecordRow('05 May 2026', 'Surah Al-Mulk', 'Grade A (Jayyid)'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _printTranscript,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export Official Transcript PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(String date, String surah, String grade) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(surah, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(date, style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF004D40).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(grade, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          ),
        ],
      ),
    );
  }
}
