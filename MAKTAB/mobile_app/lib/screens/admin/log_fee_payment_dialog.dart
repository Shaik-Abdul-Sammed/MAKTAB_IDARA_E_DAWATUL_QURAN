import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/fee_payment.dart';
import '../../providers/student_detail_provider.dart';

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
      await provider.addPayment(payment);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment logged successfully!'), backgroundColor: Color(0xFF004D40)),
        );
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
                  initialValue: _selectedMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _modes.map((mode) {
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
