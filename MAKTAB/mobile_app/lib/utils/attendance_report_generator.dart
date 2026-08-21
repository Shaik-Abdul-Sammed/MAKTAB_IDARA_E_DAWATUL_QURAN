import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/student.dart';

class AttendanceReportGenerator {
  /// Formats raw date string (e.g. 2026-08-21) to "21 August 2026"
  static String formatDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('dd MMMM yyyy').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  /// Formats current date and time as "21 August 2026, 06:30 PM"
  static String formatTimestamp([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    return DateFormat('dd MMMM yyyy, hh:mm a').format(now);
  }

  /// Generates a clean, aligned, professional plain-text / WhatsApp report
  static String generateTextReport({
    required String rawDate,
    required String batchName,
    required String teacherName,
    required List<Student> students,
    required Map<int, String> studentStatuses,
    String? generatedAt,
  }) {
    final dateFormatted = formatDate(rawDate);
    final genTime = generatedAt ?? formatTimestamp();
    final bName = batchName.isNotEmpty ? batchName : 'General Batch';
    final tName = teacherName.isNotEmpty ? teacherName : 'Assigned Teacher';

    final buf = StringBuffer();
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('     MAKTAB IDARA E DAWATUL QURAN');
    buf.writeln('          ATTENDANCE REPORT');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    buf.writeln('Date             : $dateFormatted');
    buf.writeln('Batch            : $bName');
    buf.writeln('Teacher          : $tName');
    buf.writeln('Report Generated : $genTime');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    if (students.isEmpty) {
      buf.writeln('ATTENDANCE NOT RECORDED');
      buf.writeln('No student attendance records available for this batch/date.');
      buf.writeln('\n──────────────────────────────────');
      buf.writeln('Prepared by: Maktab Management System');
      buf.writeln('MAKTAB IDARA E DAWATUL QURAN');
      return buf.toString();
    }

    final presentList = <Student>[];
    final absentList = <Student>[];
    final lateList = <Student>[];
    final leaveList = <Student>[];

    for (final s in students) {
      final st = (s.id != null ? studentStatuses[s.id] : null) ?? 'Present';
      switch (st) {
        case 'Present':
          presentList.add(s);
          break;
        case 'Absent':
          absentList.add(s);
          break;
        case 'Late':
          lateList.add(s);
          break;
        case 'Leave':
          leaveList.add(s);
          break;
        default:
          presentList.add(s);
          break;
      }
    }

    final totalCount = students.length;
    final presentCount = presentList.length;
    final absentCount = absentList.length;
    final lateCount = lateList.length;
    final leaveCount = leaveList.length;
    final rate = totalCount > 0 ? ((presentCount / totalCount) * 100) : 0.0;

    buf.writeln('ATTENDANCE SUMMARY');
    buf.writeln('──────────────────────────────────');
    buf.writeln('Total Students   : $totalCount');
    buf.writeln('Present          : $presentCount');
    buf.writeln('Absent           : $absentCount');
    buf.writeln('Late             : $lateCount');
    buf.writeln('Leave            : $leaveCount');
    buf.writeln('Attendance Rate  : ${rate.toStringAsFixed(1)}%\n');

    // Visual bar breakdown for text/WhatsApp
    buf.writeln('STATUS BREAKDOWN');
    buf.writeln('──────────────────────────────────');
    buf.writeln('Present  : ${_buildBar(presentCount, totalCount)} $presentCount (${rate.toStringAsFixed(1)}%)');
    final pAbs = totalCount > 0 ? ((absentCount / totalCount) * 100).toStringAsFixed(1) : '0.0';
    buf.writeln('Absent   : ${_buildBar(absentCount, totalCount)} $absentCount ($pAbs%)');
    if (lateCount > 0) {
      final pLate = ((lateCount / totalCount) * 100).toStringAsFixed(1);
      buf.writeln('Late     : ${_buildBar(lateCount, totalCount)} $lateCount ($pLate%)');
    }
    if (leaveCount > 0) {
      final pLeave = ((leaveCount / totalCount) * 100).toStringAsFixed(1);
      buf.writeln('Leave    : ${_buildBar(leaveCount, totalCount)} $leaveCount ($pLeave%)');
    }
    buf.writeln();

    // Absent Students Section
    buf.writeln('ABSENT STUDENTS (${absentList.length})');
    buf.writeln('──────────────────────────────────');
    if (absentList.isEmpty) {
      buf.writeln('None');
    } else {
      for (int i = 0; i < absentList.length; i++) {
        final s = absentList[i];
        final adm = s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A';
        buf.writeln('${i + 1}. [$adm] ${s.name}');
      }
    }
    buf.writeln();

    // Leave Students Section
    if (leaveList.isNotEmpty) {
      buf.writeln('LEAVE STUDENTS (${leaveList.length})');
      buf.writeln('──────────────────────────────────');
      for (int i = 0; i < leaveList.length; i++) {
        final s = leaveList[i];
        final adm = s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A';
        buf.writeln('${i + 1}. [$adm] ${s.name}');
      }
      buf.writeln();
    }

    // Master Table
    buf.writeln('MASTER ATTENDANCE LIST');
    buf.writeln('──────────────────────────────────');
    buf.writeln('No. | Adm No.    | Student Name         | Status');
    buf.writeln('────┼────────────┼──────────────────────┼──────────');
    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final noStr = (i + 1).toString().padRight(3);
      final admStr = (s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A').padRight(10);
      final truncatedName = s.name.length > 20 ? '${s.name.substring(0, 18)}..' : s.name;
      final nameStr = truncatedName.padRight(20);
      final st = (s.id != null ? studentStatuses[s.id] : null) ?? 'Present';
      final statusStr = st.toUpperCase();
      buf.writeln('$noStr| $admStr | $nameStr | $statusStr');
    }

    buf.writeln('\n──────────────────────────────────');
    buf.writeln('Prepared by: Maktab Management System');
    buf.writeln('MAKTAB IDARA E DAWATUL QURAN\n');
    buf.writeln('Teacher Signature: _________________');
    buf.writeln('Manager Signature: _________________');

    return buf.toString();
  }

  static String _buildBar(int count, int total) {
    if (total == 0 || count == 0) return '';
    final len = ((count / total) * 15).round().clamp(1, 15);
    return '█' * len;
  }

  /// Generates a highly professional multi-page institutional PDF document
  static Future<pw.Document> generatePdfReport({
    required String rawDate,
    required String batchName,
    required String teacherName,
    required List<Student> students,
    required Map<int, String> studentStatuses,
    String? generatedAt,
  }) async {
    final pdf = pw.Document();
    final dateFormatted = formatDate(rawDate);
    final genTime = generatedAt ?? formatTimestamp();
    final bName = batchName.isNotEmpty ? batchName : 'General Batch';
    final tName = teacherName.isNotEmpty ? teacherName : 'Assigned Teacher';

    final presentList = students.where((s) => (studentStatuses[s.id] ?? 'Present') == 'Present').toList();
    final absentList = students.where((s) => (studentStatuses[s.id] ?? 'Present') == 'Absent').toList();
    final lateList = students.where((s) => (studentStatuses[s.id] ?? 'Present') == 'Late').toList();
    final leaveList = students.where((s) => (studentStatuses[s.id] ?? 'Present') == 'Leave').toList();

    final totalCount = students.length;
    final presentCount = presentList.length;
    final absentCount = absentList.length;
    final lateCount = lateList.length;
    final leaveCount = leaveList.length;
    final rate = totalCount > 0 ? ((presentCount / totalCount) * 100).toStringAsFixed(1) : '0.0';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal900, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MAKTAB IDARA E DAWATUL QURAN',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('OFFICIAL STUDENT ATTENDANCE REPORT',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(dateFormatted, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Prepared by Maktab Management System - Confidential Institutional Record',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          if (students.isEmpty) {
            return [
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('ATTENDANCE NOT RECORDED', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.SizedBox(height: 8),
                      pw.Text('No student attendance records exist for $bName on $dateFormatted.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                    ],
                  ),
                ),
              ),
            ];
          }

          return [
            pw.SizedBox(height: 12),

            // Metadata Card Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.teal200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.TextSpan(text: dateFormatted, style: const pw.TextStyle(fontSize: 10)),
                      ])),
                      pw.SizedBox(height: 4),
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Class/Batch: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.TextSpan(text: bName, style: const pw.TextStyle(fontSize: 10)),
                      ])),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Teacher: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.TextSpan(text: tName, style: const pw.TextStyle(fontSize: 10)),
                      ])),
                      pw.SizedBox(height: 4),
                      pw.RichText(text: pw.TextSpan(children: [
                        pw.TextSpan(text: 'Generated: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.TextSpan(text: genTime, style: const pw.TextStyle(fontSize: 10)),
                      ])),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Attendance Summary Grid Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatBox('TOTAL', '$totalCount', PdfColors.blue800, PdfColors.blue50),
                _pdfStatBox('PRESENT', '$presentCount', PdfColors.green800, PdfColors.green50),
                _pdfStatBox('ABSENT', '$absentCount', PdfColors.red800, PdfColors.red50),
                _pdfStatBox('LATE', '$lateCount', PdfColors.amber800, PdfColors.amber50),
                _pdfStatBox('LEAVE', '$leaveCount', PdfColors.orange800, PdfColors.orange50),
                _pdfStatBox('RATE', '$rate%', PdfColors.teal900, PdfColors.teal100),
              ],
            ),

            pw.SizedBox(height: 20),

            // Master Attendance Table Header
            pw.Text('MASTER ATTENDANCE RECORD', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['No.', 'Admission No.', 'Student Name', 'Status'],
              data: students.asMap().entries.map((e) {
                final s = e.value;
                final st = (s.id != null ? studentStatuses[s.id] : null) ?? 'Present';
                return [(e.key + 1).toString(), s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A', s.name, st.toUpperCase()];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(35),
                1: const pw.FixedColumnWidth(110),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(90),
              },
              cellAlignment: pw.Alignment.centerLeft,
            ),

            pw.SizedBox(height: 20),

            // Separate Absent & Leave Tables
            if (absentList.isNotEmpty) ...[
              pw.Text('ABSENT STUDENTS DETAILS (${absentList.length})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['S.No', 'Admission No.', 'Student Name'],
                data: absentList.asMap().entries.map((e) {
                  final s = e.value;
                  return [(e.key + 1).toString(), s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A', s.name];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                border: pw.TableBorder.all(color: PdfColors.red200, width: 0.5),
              ),
              pw.SizedBox(height: 16),
            ],

            if (leaveList.isNotEmpty) ...[
              pw.Text('LEAVE STUDENTS DETAILS (${leaveList.length})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['S.No', 'Admission No.', 'Student Name'],
                data: leaveList.asMap().entries.map((e) {
                  final s = e.value;
                  return [(e.key + 1).toString(), s.admissionNumber.isNotEmpty ? s.admissionNumber : 'N/A', s.name];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                border: pw.TableBorder.all(color: PdfColors.orange200, width: 0.5),
              ),
              pw.SizedBox(height: 16),
            ],

            pw.SizedBox(height: 30),

            // Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('____________________________________', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('Teacher Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('____________________________________', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('Manager / Principal Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _pdfStatBox(String label, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      width: 72,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: textColor, width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textColor)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}
