import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../providers/student_detail_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/whatsapp_utility.dart';
import '../../utils/receipt_templates.dart';
import '../../utils/receipt_pdf_generator.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/fee_payment_repository.dart';
import '../../widgets/receipt_preview_dialog.dart';

class LogFeePaymentDialog extends StatefulWidget {
  final Student student;

  const LogFeePaymentDialog({super.key, required this.student});

  @override
  State<LogFeePaymentDialog> createState() => _LogFeePaymentDialogState();
}

class _LogFeePaymentDialogState extends State<LogFeePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  String _selectedMode = 'Cash';
  final List<String> _modes = ['Cash', 'Online', 'UPI', 'Cheque', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.student.feesAmount?.toString() ?? '');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final amount = int.parse(_amountCtrl.text.trim());
      
      // Capture precise current date and time
      final now = DateTime.now();
      final timestamp = now.toIso8601String();

      final payment = FeePayment(
        studentId: widget.student.id!,
        amount: amount,
        mode: _selectedMode,
        timestamp: timestamp,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      final provider = Provider.of<StudentDetailProvider>(context, listen: false);
      final insertedId = await provider.addPayment(payment);
      
      if (mounted) {
        final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
        final collectorName = currentUser?.name ?? 'Management';
        final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(now);
        final month = DateFormat('MMMM yyyy').format(now);

        final primaryStudent = await StudentRepository().getStudentById(payment.studentId) ?? widget.student;
        final siblings = await StudentRepository().findSiblings(primaryStudent);

        final parentPhone = (primaryStudent.guardianPhone != null && primaryStudent.guardianPhone!.trim().isNotEmpty)
            ? primaryStudent.guardianPhone!.trim()
            : (primaryStudent.phone?.trim() ?? '');

        final todayStr = now.toIso8601String().substring(0, 10);
        final List<Map<String, dynamic>> includedChildren = [];
        final List<int> includedPaymentIds = [];

        if (siblings.length > 1) {
          for (final s in siblings) {
            final payments = await FeePaymentRepository().getPaymentsForStudent(s.id!);
            final matching = payments.where((p) =>
                p.timestamp.startsWith(todayStr) &&
                p.mode == _selectedMode
            ).toList();
            for (final mp in matching) {
              if (mp.id != null) {
                includedPaymentIds.add(mp.id!);
              }
              includedChildren.add({
                'name': s.name,
                'admissionNumber': s.admissionNumber,
                'amount': mp.amount,
                'mode': mp.mode,
                'notes': mp.notes,
              });
            }
          }
        }

        final bool isCombined = siblings.length > 1 && includedChildren.length > 1;

        String receiptText = '';
        if (!isCombined) {
          final buf = StringBuffer();
          buf.writeln('*MAKTAB IDARA E DAWATUL QURAN — Payment Receipt*');
          buf.writeln('Date: $formattedTime');
          buf.writeln('Received by: $collectorName');
          buf.writeln();
          buf.writeln('*Student:* ${primaryStudent.name} (${primaryStudent.admissionNumber})');
          buf.writeln('Amount: ₹$amount');
          buf.writeln('Mode: $_selectedMode');
          if (payment.notes != null && payment.notes!.trim().isNotEmpty) {
            buf.writeln('Note: ${payment.notes}');
          }
          buf.writeln();
          buf.writeln('Jazak Allah Khair.');
          receiptText = buf.toString();
        } else {
          final buf = StringBuffer();
          buf.writeln('*MAKTAB IDARA E DAWATUL QURAN — Payment Receipt*');
          buf.writeln('Date: $formattedTime');
          buf.writeln('Received by: $collectorName');
          buf.writeln();

          int grandTotal = 0;
          for (final c in includedChildren) {
            final amt = (c['amount'] as num).toInt();
            grandTotal += amt;
            buf.writeln('*${c['name']}* (${c['admissionNumber']}) — ₹$amt via ${c['mode']}');
            final notes = c['notes'] as String?;
            if (notes != null && notes.trim().isNotEmpty) {
              buf.writeln('  _Note: ${notes}_');
            }
          }

          buf.writeln();
          buf.writeln('*Total: ₹$grandTotal*');
          buf.writeln();
          buf.writeln('Jazak Allah Khair.');
          receiptText = buf.toString();
        }

        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (dialogCtx) => ReceiptPreviewDialog(
            title: 'Payment Saved',
            receiptText: receiptText,
            recipientPhone: parentPhone,
            onBuildPdf: () async {
              final labels = ReceiptTemplates.get(widget.student.preferredLanguage);
              return ReceiptPdfGenerator.buildFeeReceiptPdf(
                maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
                collectorName: collectorName,
                recordedAt: now,
                children: isCombined
                    ? includedChildren
                    : [
                        {
                          'name': primaryStudent.name,
                          'admissionNumber': primaryStudent.admissionNumber,
                          'amount': amount,
                          'mode': _selectedMode,
                          'notes': payment.notes,
                        }
                      ],
                labels: labels,
                senderName: collectorName,
              );
            },
            onSend: () async {
              Navigator.pop(dialogCtx);
              if (!isCombined) {
                await WhatsAppUtility.sendFeeReceipt(
                  context,
                  parentPhone,
                  primaryStudent.name,
                  amount.toDouble(),
                  month,
                  paymentMode: _selectedMode,
                  dateTime: formattedTime,
                  collectorName: collectorName,
                  languageCode: widget.student.preferredLanguage,
                  senderName: collectorName,
                );
                await FeePaymentRepository().markReceiptSent(insertedId);
              } else {
                await WhatsAppUtility.sendCombinedFeeReceipt(
                  context,
                  parentPhone: parentPhone,
                  children: includedChildren,
                  maktabName: 'MAKTAB IDARA E DAWATUL QURAN',
                  collectorName: collectorName,
                  recordedAt: now,
                  languageCode: widget.student.preferredLanguage,
                  senderName: collectorName,
                );
                for (final pid in includedPaymentIds) {
                  await FeePaymentRepository().markReceiptSent(pid);
                }
              }
            },
          ),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payment, color: Color(0xFF004D40)),
                    SizedBox(width: 8),
                    Text('Log Fee Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Amount Field
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter amount';
                    if (int.tryParse(value.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Mode Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _modes.contains(_selectedMode) ? _selectedMode : _modes.first,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _modes.toSet().map((mode) {
                    return DropdownMenuItem(value: mode, child: Text(mode));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMode = val);
                  },
                ),
                const SizedBox(height: 16),
                
                // Notes Field
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                      child: const Text('Save Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
