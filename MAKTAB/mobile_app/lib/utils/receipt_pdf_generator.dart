import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'receipt_templates.dart';
import 'pdf_font_helper.dart';

class ReceiptPdfGenerator {
  /// Builds a single PDF for a fee receipt (single or combined siblings).
  /// Returns the raw bytes; caller is responsible for sharing.
  static Future<Uint8List> buildFeeReceiptPdf({
    required String maktabName,
    required String collectorName,
    required DateTime recordedAt,
    required List<Map<String, dynamic>> children, // {name, admissionNumber, amount, mode, notes}
    Map<String, String>? labels,
    String languageCode = 'en',
    required String senderName,
  }) async {
    final effectiveLabels = labels ?? ReceiptTemplates.get(languageCode);
    final theme = await PdfFontHelper.getTheme(languageCode: languageCode);
    final doc = pw.Document(theme: theme);
    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(recordedAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          final total = children.fold<int>(
            0,
            (sum, c) => sum + (c['amount'] as num).toInt(),
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                maktabName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                effectiveLabels['feeHeader'] ?? effectiveLabels['header'] ?? 'Payment Receipt',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text('${effectiveLabels['date'] ?? 'Date'}: $whenStr'),
              pw.Text('${effectiveLabels['feeReceivedBy'] ?? effectiveLabels['receivedBy'] ?? 'Received by'}: $collectorName'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: [
                  effectiveLabels['student'] ?? 'Student',
                  effectiveLabels['feeAmount'] ?? effectiveLabels['amount'] ?? 'Amount',
                  effectiveLabels['feeMode'] ?? effectiveLabels['mode'] ?? 'Mode',
                ],
                data: children
                    .map((c) => [
                          '${c['name']} (${c['admissionNumber']})',
                          '₹${(c['amount'] as num).toInt()}',
                          c['mode'] ?? '',
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              if (children.length > 1) ...[
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${effectiveLabels['feeSiblingTotal'] ?? effectiveLabels['total'] ?? 'Total'}: ₹$total',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                effectiveLabels['feeThankYou'] ?? effectiveLabels['footer'] ?? 'Jazak Allah Khair.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${effectiveLabels['commonRegards'] ?? 'Regards,'}\n$senderName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Builds a single PDF for a salary receipt.
  static Future<Uint8List> buildSalaryReceiptPdf({
    required String maktabName,
    required String teacherName,
    required String salaryMonth,
    required int amount,
    required String paymentMode,
    required DateTime paymentDate,
    required String issuedBy,
    Map<String, String>? labels,
    String languageCode = 'en',
    required String senderName,
    String? notes,
    String? transactionReference,
  }) async {
    final effectiveLabels = labels ?? ReceiptTemplates.get(languageCode);
    final theme = await PdfFontHelper.getTheme(languageCode: languageCode);
    final doc = pw.Document(theme: theme);
    final whenStr = DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                maktabName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                effectiveLabels['salaryHeader'] ?? 'Salary Receipt',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text('${effectiveLabels['date'] ?? 'Date'}: $whenStr'),
              pw.Text('${effectiveLabels['salaryMonth'] ?? 'Month'}: $salaryMonth'),
              pw.Text('${effectiveLabels['salaryPaidTo'] ?? 'Paid to'}: $teacherName'),
              pw.SizedBox(height: 12),
              pw.Text(
                '${effectiveLabels['salaryAmount'] ?? effectiveLabels['amount'] ?? 'Amount'}: ₹$amount',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('${effectiveLabels['salaryMode'] ?? effectiveLabels['mode'] ?? 'Mode'}: $paymentMode'),
              if (notes != null && notes.isNotEmpty)
                pw.Text('${effectiveLabels['notes'] ?? 'Notes'}: $notes'),
              if (transactionReference != null && transactionReference.isNotEmpty)
                pw.Text('Ref: $transactionReference'),
              pw.SizedBox(height: 12),
              pw.Text('${effectiveLabels['salaryIssuedBy'] ?? 'Issued by'}: $issuedBy'),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                effectiveLabels['salaryThankYou'] ?? effectiveLabels['footer'] ?? 'Jazak Allah Khair.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${effectiveLabels['commonRegards'] ?? 'Regards,'}\n$senderName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Builds a single PDF for an attendance summary.
  static Future<Uint8List> buildAttendanceSummaryPdf({
    required String maktabName,
    required String batch,
    required String date,
    required String markedBy,
    required List<String> present,
    required List<String> absent,
    List<String>? late,
    List<String>? leave,
    Map<String, String>? labels,
    String languageCode = 'en',
    required String senderName,
  }) async {
    final effectiveLabels = labels ?? ReceiptTemplates.get(languageCode);
    final theme = await PdfFontHelper.getTheme(languageCode: languageCode);
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            maktabName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            effectiveLabels['attHeader'] ?? effectiveLabels['attendanceHeader'] ?? 'Attendance Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Text('${effectiveLabels['attBatch'] ?? effectiveLabels['batch'] ?? 'Batch'}: $batch'),
          pw.Text('${effectiveLabels['date'] ?? 'Date'}: $date'),
          pw.Text('${effectiveLabels['attMarkedBy'] ?? effectiveLabels['markedBy'] ?? 'Marked by'}: $markedBy'),
          pw.SizedBox(height: 16),
          _studentSection(effectiveLabels['attPresent'] ?? effectiveLabels['present'] ?? 'Present', present),
          _studentSection(effectiveLabels['attAbsent'] ?? effectiveLabels['absent'] ?? 'Absent', absent),
          if (late != null && late.isNotEmpty)
            _studentSection(effectiveLabels['attLate'] ?? effectiveLabels['late'] ?? 'Late', late),
          if (leave != null && leave.isNotEmpty)
            _studentSection(effectiveLabels['attLeave'] ?? effectiveLabels['leave'] ?? 'Leave', leave),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Text(
            '${effectiveLabels['commonRegards'] ?? 'Regards,'}\n$senderName',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Builds a single PDF for a Sabaq report.
  static Future<Uint8List> buildSabaqReceiptPdf({
    required String maktabName,
    required String studentName,
    required String admissionNumber,
    required String surah,
    required String ayahFrom,
    required String ayahTo,
    required String recitationType,
    required String grade,
    required String date,
    String? remarks,
    Map<String, String>? labels,
    String languageCode = 'en',
    required String senderName,
  }) async {
    final effectiveLabels = labels ?? ReceiptTemplates.get(languageCode);
    final theme = await PdfFontHelper.getTheme(languageCode: languageCode);
    final doc = pw.Document(theme: theme);
    final note = (remarks != null && remarks.trim().isNotEmpty)
        ? remarks.trim()
        : (effectiveLabels['sabaqDefaultNote'] ?? 'Alhamdulillah, completed with care.');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                maktabName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                effectiveLabels['sabaqDetailsHeader'] ?? 'Sabaq Details',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text('${effectiveLabels['student'] ?? 'Student'}: $studentName ($admissionNumber)'),
              pw.Text('${effectiveLabels['sabaqDateLabel'] ?? 'Date'}: $date'),
              pw.SizedBox(height: 12),
              pw.Text('${effectiveLabels['sabaqSurahLabel'] ?? 'Surah'}: $surah'),
              pw.Text('${effectiveLabels['sabaqAyahLabel'] ?? 'Ayah'}: $ayahFrom–$ayahTo'),
              pw.Text('${effectiveLabels['sabaqTypeLabel'] ?? 'Type'}: $recitationType'),
              pw.Text('${effectiveLabels['sabaqGradeLabel'] ?? 'Grade'}: $grade'),
              pw.SizedBox(height: 12),
              pw.Text('${effectiveLabels['sabaqNoteHeader'] ?? "Teacher's Note"}:'),
              pw.Text(note, style: const pw.TextStyle(fontSize: 11)),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                effectiveLabels['sabaqJazak'] ?? 'Jazak Allah Khair.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${effectiveLabels['sabaqRegards'] ?? 'Warm regards,'}\n$senderName',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _studentSection(String title, List<String> names) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          '$title (${names.length})',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        ...names.map((n) => pw.Text('• $n', style: const pw.TextStyle(fontSize: 11))),
      ],
    );
  }
}
