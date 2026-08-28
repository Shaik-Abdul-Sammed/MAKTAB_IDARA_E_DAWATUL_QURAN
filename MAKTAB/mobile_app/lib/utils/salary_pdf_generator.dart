import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:maktab_app/models/salary_payment.dart';

class SalaryPdfGenerator {
  /// Generates a professional Salary Report PDF
  static Future<Uint8List> generateSalaryReportPdf({
    required String maktabName,
    required String month,
    required List<Map<String, dynamic>> teacherSalaryData,
    required int totalSalary,
    required int totalPaid,
    required int totalPending,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#004D40'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      maktabName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TEACHER SALARY REPORT - $month',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Stats
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBox('Total Salary', 'Rs. $totalSalary', PdfColor.fromHex('#004D40')),
                  _buildStatBox('Total Paid', 'Rs. $totalPaid', PdfColor.fromHex('#2E7D32')),
                  _buildStatBox('Total Pending', 'Rs. $totalPending', PdfColor.fromHex('#C62828')),
                ],
              ),
              pw.SizedBox(height: 20),

              // Table Header
              pw.TableHelper.fromTextArray(
                headers: ['Teacher Name', 'Monthly Salary', 'Paid', 'Due', 'Status'],
                data: teacherSalaryData.map((t) {
                  return [
                    t['name'] ?? '',
                    'Rs. ${t['monthlySalary']}',
                    'Rs. ${t['paid']}',
                    'Rs. ${t['pending']}',
                    t['status'] ?? '',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#004D40')),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              pw.SizedBox(height: 30),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Prepared by: Maktab Management System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStatBox(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, color: color, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Generates clean text receipt for WhatsApp / SMS sharing
  static String generatePaymentReceiptText({
    required SalaryPayment payment,
    required String teacherName,
    required String teacherMobile,
    required String maktabName,
  }) {
    return '''
*${maktabName.toUpperCase()}*
*SALARY PAYMENT RECEIPT*

*Teacher:* $teacherName
*Mobile:* $teacherMobile
*Salary Month:* ${payment.salaryMonth}
*Amount Paid:* ₹${payment.amount}
*Payment Mode:* ${payment.paymentMode}
*Payment Date:* ${payment.paymentDate}
*Reference/Txn ID:* ${payment.transactionReference ?? 'N/A'}
*Status:* ${payment.status}
${payment.notes != null && payment.notes!.isNotEmpty ? '*Notes:* ${payment.notes}\n' : ''}
----------------------------------------
_Prepared by Management_
''';
  }
}
