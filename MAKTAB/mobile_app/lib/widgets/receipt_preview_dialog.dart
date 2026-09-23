import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final String title;           // "Payment Saved" or "Salary Recorded"
  final String receiptText;
  final String recipientPhone; // may be empty
  final VoidCallback onSend;    // called when user taps Send
  final VoidCallback? onSkip;
  final Future<Uint8List> Function()? onBuildPdf;

  const ReceiptPreviewDialog({
    super.key,
    required this.title,
    required this.receiptText,
    required this.recipientPhone,
    required this.onSend,
    this.onSkip,
    this.onBuildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipientPhone.isEmpty)
              const Text(
                'No phone number on record. Use Copy to share manually.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                receiptText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: receiptText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt copied')),
            );
          },
          child: const Text('Copy'),
        ),
        if (recipientPhone.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('WhatsApp'),
            onPressed: onSend,
          ),
        if (onBuildPdf != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('PDF'),
            onPressed: () async {
              try {
                final bytes = await onBuildPdf!();
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF error: $e')),
                  );
                }
              }
            },
          ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onSkip?.call();
          },
          child: const Text('Skip'),
        ),
      ],
    );
  }
}
