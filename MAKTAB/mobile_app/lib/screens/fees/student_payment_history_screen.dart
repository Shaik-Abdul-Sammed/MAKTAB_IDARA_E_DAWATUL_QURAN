import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../models/fee_payment.dart';
import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../repositories/student_repository.dart';
import '../../utils/whatsapp_utility.dart';

class PaymentTransaction {
  final FeePayment payment;
  final Student student;

  PaymentTransaction({
    required this.payment,
    required this.student,
  });
}

class StudentPaymentHistoryScreen extends StatefulWidget {
  const StudentPaymentHistoryScreen({super.key});

  @override
  State<StudentPaymentHistoryScreen> createState() => _StudentPaymentHistoryScreenState();
}

class _StudentPaymentHistoryScreenState extends State<StudentPaymentHistoryScreen> {
  List<PaymentTransaction> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final payments = await FeePaymentRepository().getAllPayments();
    final students = await StudentRepository().getAllStudents();
    
    final studentMap = {for (var s in students) s.id: s};
    
    final List<PaymentTransaction> txs = [];
    for (var p in payments) {
      if (studentMap.containsKey(p.studentId)) {
        txs.add(PaymentTransaction(payment: p, student: studentMap[p.studentId]!));
      }
    }
    
    if (mounted) {
      setState(() {
        _history = txs;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deletePayment(int paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      await FeePaymentRepository().deleteFeePayment(paymentId);
      _loadHistory();
    }
  }

  Future<void> _printReceipt(PaymentTransaction tx) async {
    final pdf = pw.Document();
    
    final dateTime = DateTime.tryParse(tx.payment.timestamp) ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);
    final timeStr = DateFormat('hh:mm a').format(dateTime);
    final receiptNo = 'RCP-${tx.payment.id?.toString().padLeft(4, '0')}';
    
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final collectorName = currentUser != null && currentUser.name.isNotEmpty ? currentUser.name : 'Teacher / Manager';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('MAKTAB - Idara-e-Dawatul Qur\'an',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                ),
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('FEE PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Receipt No: $receiptNo'),
                  pw.Text('Date & Time: $dateStr $timeStr'),
                ]),
                pw.SizedBox(height: 8),
                pw.Text('Student Name: ${tx.student.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Admission No: ${tx.student.admissionNumber}'),
                pw.Text('Payment Method: ${tx.payment.mode}'),
                pw.Text('Collected By (Teacher/Manager): $collectorName'),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Amount Received:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('INR ${tx.payment.amount}.00', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Text('Status: SUCCESSFUL / PAID', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                pw.Spacer(),
                pw.Center(child: pw.Text('Thank you! JazakAllah Khair.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'receipt_$receiptNo.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Fee Payment History'),
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
            : _history.isEmpty 
                ? const Center(child: Text('No fee payments found.'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final tx = _history[index];
                      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(tx.payment.timestamp));
                      final receiptNo = 'RCP-${tx.payment.id?.toString().padLeft(4, '0')}';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(receiptNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 13)),
                                Row(
                                  children: [
                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _deletePayment(tx.payment.id!),
                                      child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFF004D40),
                                  child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tx.student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('ADM: ${tx.student.admissionNumber} · ${tx.payment.mode}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                Text('₹${tx.payment.amount}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final phone = tx.student.phone ?? '';
                                    final parsed = DateTime.tryParse(tx.payment.timestamp);
                                    final formattedTime = parsed != null ? DateFormat('dd MMM yyyy, hh:mm a').format(parsed) : tx.payment.timestamp;
                                    final month = parsed != null ? DateFormat('MMMM yyyy').format(parsed) : tx.payment.timestamp.split('T')[0];
                                    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                                    final collectorName = currentUser?.name ?? 'Management';

                                    await WhatsAppUtility.sendFeeReceipt(
                                      context,
                                      phone,
                                      tx.student.name,
                                      tx.payment.amount.toDouble(),
                                      month,
                                      paymentMode: tx.payment.mode,
                                      dateTime: formattedTime,
                                      collectorName: collectorName,
                                    );
                                  },
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: const Text('WhatsApp Receipt', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF004D40),
                                    side: const BorderSide(color: Color(0xFF004D40)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _printReceipt(tx),
                                  icon: const Icon(Icons.print_rounded, size: 14),
                                  label: const Text('Print Receipt PDF', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF004D40),
                                    side: const BorderSide(color: Color(0xFF004D40)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
