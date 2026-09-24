import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'receipt_templates.dart';

enum Language { english, urdu, hindi, telugu }

class WhatsAppUtility {
  static Future<void> launchWhatsApp(String phone, String message, {BuildContext? context}) async {
    // Remove all non-numeric characters from phone
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number for WhatsApp message.')),
        );
      }
      return;
    }
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone'; // Default to India +91 if not specified
    }

    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      } else if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch WhatsApp for $phone");
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp app.')),
          );
        }
      }
    } catch (e) {
      debugPrint("WhatsApp launch error: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp launch error: $e')),
        );
      }
    }
  }

  static String _formatSignature(String? senderName) {
    final sender = (senderName != null && senderName.trim().isNotEmpty)
        ? senderName.trim()
        : 'Maktab Management';
    return '\n\n—\nRegards,\n$sender';
  }

  static Future<void> sendTeacherCredentials(
    BuildContext context,
    String phone,
    String name,
    String pin, {
    required int teacherId,
    required String mobile,
    String? senderName,
  }) async {
    final msg = '''
Assalamu Alaikum $name,

Your Maktab Teacher Portal login:
• Teacher ID: $teacherId
• Mobile: $mobile
• PIN: $pin

You can log in using either the Teacher ID or the mobile number, with the PIN above.

Jazak Allah Khair.
''';
    await launchWhatsApp(phone, msg + _formatSignature(senderName), context: context);
  }

  static Future<void> sendFeeReceipt(
    BuildContext context,
    String phone,
    String studentName,
    double amount,
    String month, {
    String? paymentMode,
    String? dateTime,
    String? collectorName,
    String? notes,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);
    final modeText = (paymentMode != null && paymentMode.isNotEmpty) ? paymentMode : 'Cash';
    final timeText = (dateTime != null && dateTime.isNotEmpty)
        ? dateTime
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final collector = (collectorName != null && collectorName.isNotEmpty) ? collectorName : 'Management';

    final buf = StringBuffer();
    buf.writeln('*${t['header']}*');
    buf.writeln('${t['date']}: $timeText');
    buf.writeln('${t['receivedBy']}: $collector');
    buf.writeln();
    buf.writeln('*${t['student']}:* $studentName');
    buf.writeln('${t['amount']}: ₹${amount.toInt() == amount ? amount.toInt() : amount}');
    buf.writeln('${t['mode']}: $modeText');
    if (notes != null && notes.trim().isNotEmpty) {
      buf.writeln('${t['notes']}: $notes');
    }
    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(phone, buf.toString(), context: context);
  }

  static Future<void> sendCombinedFeeReceipt(
    BuildContext context, {
    required String parentPhone,
    required List<Map<String, dynamic>> children, // each: {name, admissionNumber, amount, mode, notes}
    String? maktabName,
    required String collectorName,
    DateTime? recordedAt,
    String? dateTime,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);
    final when = recordedAt ?? DateTime.now();
    final timeStr = dateTime ?? DateFormat('dd MMM yyyy, hh:mm a').format(when);
    final headerTitle = maktabName ?? t['header']!;

    final buf = StringBuffer();
    buf.writeln('*$headerTitle*');
    buf.writeln('${t['date']}: $timeStr');
    buf.writeln('${t['receivedBy']}: $collectorName');
    buf.writeln();

    int grandTotal = 0;
    for (final c in children) {
      final amt = (c['amount'] as num).toInt();
      grandTotal += amt;
      buf.writeln('*${c['name']}* (${c['admissionNumber']}) — ₹$amt ${t['mode']}: ${c['mode']}');
      final notes = c['notes'] as String?;
      if (notes != null && notes.trim().isNotEmpty) {
        buf.writeln('  _${t['notes']}: ${notes}_');
      }
    }

    if (children.length > 1) {
      buf.writeln();
      buf.writeln('*${t['total']}: ₹$grandTotal*');
    }

    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(parentPhone, buf.toString(), context: context);
  }

  /// Send official Teacher Salary Slip via WhatsApp in selected language.
  static Future<void> sendSalarySlip(
    BuildContext context,
    String phone,
    String teacherName,
    double monthlySalary,
    double paidAmount,
    String month, {
    String? paymentMode,
    String? upiId,
    String? issuedBy,
    String? dateTime,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);
    final modeText = (paymentMode != null && paymentMode.isNotEmpty) ? paymentMode : 'Cash';
    final timeText = (dateTime != null && dateTime.isNotEmpty)
        ? dateTime
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final issuer = (issuedBy != null && issuedBy.isNotEmpty) ? issuedBy : 'Management';

    final buf = StringBuffer();
    buf.writeln('*${t['salaryHeader']}*');
    buf.writeln('${t['date']}: $timeText');
    buf.writeln('${t['salaryMonth']}: $month');
    buf.writeln('${t['salaryPaidTo']}: $teacherName');
    buf.writeln('${t['amount']}: ₹${paidAmount.toInt() == paidAmount ? paidAmount.toInt() : paidAmount}');
    buf.writeln('${t['mode']}: $modeText');
    buf.writeln('${t['salaryIssuedBy']}: $issuer');
    if (upiId != null && upiId.isNotEmpty) {
      buf.writeln('UPI ID: $upiId');
    }
    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(phone, buf.toString(), context: context);
  }

  /// Send attendance absence alert with date.
  static Future<void> sendAttendanceAlert(
    BuildContext context,
    String phone,
    String studentName, {
    String? date,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);
    final dateStr = date ?? DateFormat('dd MMM yyyy').format(DateTime.now());

    final buf = StringBuffer();
    buf.writeln(t['absentHeader']);
    buf.writeln();
    buf.writeln('${t['student']}: $studentName');
    buf.writeln('${t['date']}: $dateStr');
    buf.writeln();
    buf.writeln(t['absentBody']);
    buf.writeln(t['pleaseContact']);
    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(phone, buf.toString(), context: context);
  }

  /// Send Batch Notice via WhatsApp with language prompt.
  static Future<void> sendBatchNotice(
    BuildContext context, {
    required String batchName,
    required String timing,
    String? phone,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);

    final buf = StringBuffer();
    buf.writeln(t['batchNoticeHeader']);
    buf.writeln();
    buf.writeln('${t['batch']}: $batchName');
    buf.writeln('${t['timing']}: $timing');
    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(phone ?? '', buf.toString(), context: context);
  }

  /// Send custom Notice or Announcement with language selection prompt.
  static Future<void> sendNoticeMessage(
    BuildContext context, {
    required String title,
    required String content,
    String? recipientPhone,
    String? targetName,
    String languageCode = 'en',
    String? senderName,
  }) async {
    final t = ReceiptTemplates.get(languageCode);

    final buf = StringBuffer();
    buf.writeln(t['announcementHeader']);
    buf.writeln();
    buf.writeln('📢 $title');
    buf.writeln(content);
    buf.writeln();
    buf.writeln(t['footer']);
    buf.write(_formatSignature(senderName));

    await launchWhatsApp(recipientPhone ?? '', buf.toString(), context: context);
  }

  /// Build and share a plain-text attendance report (no language selection needed).
  static String buildAttendanceReportText({
    required String date,
    required List<String> present,
    required List<String> absent,
    List<String>? late,
    List<String>? leave,
    String? batch,
    String? markedBy,
    String languageCode = 'en',
  }) {
    final t = ReceiptTemplates.get(languageCode);
    final buffer = StringBuffer();
    buffer.writeln('*${t['attendanceHeader']}*');
    if (batch != null && batch.isNotEmpty) {
      buffer.writeln('${t['batch']}: $batch');
    }
    buffer.writeln('${t['date']}: $date');
    if (markedBy != null && markedBy.isNotEmpty) {
      buffer.writeln('${t['markedBy']}: $markedBy');
    }
    buffer.writeln('─────────────────────────');
    buffer.writeln('✅ ${t['present']} (${present.length}):');
    for (final name in present) {
      buffer.writeln('  • $name');
    }
    buffer.writeln();
    buffer.writeln('❌ ${t['absent']} (${absent.length}):');
    for (final name in absent) {
      buffer.writeln('  • $name');
    }
    if (late != null && late.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🟡 ${t['late']} (${late.length}):');
      for (final name in late) {
        buffer.writeln('  • $name');
      }
    }
    if (leave != null && leave.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🔵 ${t['leave']} (${leave.length}):');
      for (final name in leave) {
        buffer.writeln('  • $name');
      }
    }
    buffer.writeln();
    buffer.writeln(t['footer']);
    return buffer.toString();
  }

  static Future<Language?> promptLanguageSelection(BuildContext context) async {
    return showDialog<Language>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Select Message Language',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageTile(label: '🇬🇧  English', value: Language.english),
              const Divider(height: 1),
              _LanguageTile(label: '🇵🇰  اردو (Urdu)', value: Language.urdu),
              const Divider(height: 1),
              _LanguageTile(label: '🇮🇳  हिंदी (Hindi)', value: Language.hindi),
              const Divider(height: 1),
              _LanguageTile(label: '🇮🇳  తెలుగు (Telugu)', value: Language.telugu),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final Language value;
  const _LanguageTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF004D40)),
      onTap: () => Navigator.pop(context, value),
    );
  }
}
