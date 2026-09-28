import 'package:flutter/material.dart';

class UpiAppPickerDialog extends StatefulWidget {
  final String rawPhone;
  final String title;

  const UpiAppPickerDialog({
    super.key,
    required this.rawPhone,
    required this.title,
  });

  static Future<String?> show(
    BuildContext context, {
    required String rawPhone,
    required String title,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpiAppPickerDialog(rawPhone: rawPhone, title: title),
    );
  }

  @override
  State<UpiAppPickerDialog> createState() => _UpiAppPickerDialogState();
}

class _UpiAppPickerDialogState extends State<UpiAppPickerDialog> {
  final TextEditingController _otherCtrl = TextEditingController();
  bool _showOtherField = false;

  String get _cleanPhone {
    final digits = widget.rawPhone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = _cleanPhone;
    final options = [
      {'app': 'PhonePe', 'handle': '$phone@ybl', 'icon': Icons.account_balance_wallet_outlined},
      {'app': 'Google Pay (GPay)', 'handle': '$phone@okaxis', 'icon': Icons.payment_outlined},
      {'app': 'Paytm', 'handle': '$phone@paytm', 'icon': Icons.account_balance_outlined},
      {'app': 'BHIM', 'handle': '$phone@upi', 'icon': Icons.qr_code},
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)), maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registered Phone: +91 $phone', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...options.map((opt) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(opt['icon'] as IconData, color: const Color(0xFF004D40)),
                title: Text(opt['app'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(opt['handle'] as String, style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, opt['handle'] as String),
              );
            }),
            const Divider(),
            if (!_showOtherField)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF004D40)),
                title: const Text('Other UPI ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Enter custom UPI handle', style: TextStyle(fontSize: 12)),
                onTap: () => setState(() => _showOtherField = true),
              )
            else ...[
              const SizedBox(height: 6),
              TextFormField(
                controller: _otherCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Custom UPI ID (e.g. name@upi)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                    onPressed: () {
                      final val = _otherCtrl.text.trim();
                      if (val.isNotEmpty && val.contains('@')) {
                        Navigator.pop(context, val);
                      }
                    },
                    child: const Text('Use UPI ID'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
