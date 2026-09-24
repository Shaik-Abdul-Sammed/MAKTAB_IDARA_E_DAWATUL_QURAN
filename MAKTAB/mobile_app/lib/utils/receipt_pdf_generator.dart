import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ReceiptPdfGenerator {
  /// Builds a single PDF for a fee receipt (single or combined siblings).
  /// Returns the raw bytes; caller is responsible for sharing.
  static Future<Uint8List> buildFeeReceiptPdf({
    required String maktabName,
    required String collectorName,
    required DateTime recordedAt,
    required List<Map<String, dynamic>> children, // {name, admissionNumber, amount, mode, notes}
    required Map<String, String> labels,           // from ReceiptTemplates.get(languageCode)
    required String senderName,
  }) async {
    final doc = pw.Document();
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
                labels['header'] ?? 'Payment Receipt',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text('${labels['date'] ?? 'Date'}: $whenStr'),
              pw.Text('${labels['receivedBy'] ?? 'Received by'}: $collectorName'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: [
                  labels['student'] ?? 'Student',
                  labels['amount'] ?? 'Amount',
                  labels['mode'] ?? 'Mode',
                ],
                data: children
                    .map((c) => [
                          '${c['name']} (${c['admissionNumber']})',
                          'Rs. ${(c['amount'] as num).toInt()}',
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
                    '${labels['total'] ?? 'Total'}: Rs. $total',
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
                labels['footer'] ?? 'Jazak Allah Khair.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Regards,\n$senderName',
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
    required Map<String, String> labels,
    required String senderName,
    String? notes,
    String? transactionReference,
  }) async {
    final doc = pw.Document();
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
                labels['salaryHeader'] ?? 'Salary Receipt',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text('${labels['date'] ?? 'Date'}: $whenStr'),
              pw.Text('${labels['salaryMonth'] ?? 'Month'}: $salaryMonth'),
              pw.Text('${labels['salaryPaidTo'] ?? 'Paid to'}: $teacherName'),
              pw.SizedBox(height: 12),
              pw.Text(
                '${labels['amount'] ?? 'Amount'}: Rs. $amount',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('${labels['mode'] ?? 'Mode'}: $paymentMode'),
              if (notes != null && notes.isNotEmpty)
                pw.Text('${labels['notes'] ?? 'Notes'}: $notes'),
              if (transactionReference != null && transactionReference.isNotEmpty)
                pw.Text('Ref: $transactionReference'),
              pw.SizedBox(height: 12),
              pw.Text('${labels['salaryIssuedBy'] ?? 'Issued by'}: $issuedBy'),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                labels['footer'] ?? 'Jazak Allah Khair.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Regards,\n$senderName',
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
    required Map<String, String> labels,
    required String senderName,
  }) async {
    final doc = pw.Document();

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
            labels['attendanceHeader'] ?? 'Attendance Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Text('${labels['batch'] ?? 'Batch'}: $batch'),
          pw.Text('${labels['date'] ?? 'Date'}: $date'),
          pw.Text('${labels['markedBy'] ?? 'Marked by'}: $markedBy'),
          pw.SizedBox(height: 16),
          _studentSection(labels['present'] ?? 'Present', present),
          _studentSection(labels['absent'] ?? 'Absent', absent),
          if (late != null && late.isNotEmpty)
            _studentSection(labels['late'] ?? 'Late', late),
          if (leave != null && leave.isNotEmpty)
            _studentSection(labels['leave'] ?? 'Leave', leave),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Text(
            'Regards,\n$senderName',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
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
