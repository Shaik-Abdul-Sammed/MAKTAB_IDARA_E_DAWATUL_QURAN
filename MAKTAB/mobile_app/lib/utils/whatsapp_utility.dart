import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum Language { english, urdu, hindi, telugu }

class WhatsAppUtility {
  static const String _signature = "\n\nFrom: MAKTAB IDARA E DAWATUL QURAN";

  static Future<void> launchWhatsApp(String phone, String message) async {
    // Remove all non-numeric characters from phone
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone'; // Default to India +91 if not specified
    }

    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp for $phone");
    }
  }

  static Future<void> sendTeacherCredentials(
      BuildContext context, String phone, String name, String pin) async {
    final lang = await _promptLanguageSelection(context);
    if (lang == null) return;

    String msg = '';
    switch (lang) {
      case Language.english:
        msg = "Assalamu Alaikum,\nDear Teacher $name,\nYour Maktab App login PIN is: *$pin*\nPlease keep it confidential and do not share it with anyone.";
        break;
      case Language.urdu:
        msg = "السلام علیکم،\nمحترم استاد $name،\nآپ کے مکتب ایپ کا لاگ ان پن ہے: *$pin*\nبراہ کرم اسے خفیہ رکھیں اور کسی کے ساتھ شیئر نہ کریں۔";
        break;
      case Language.hindi:
        msg = "अस्सलामु अलैकुम,\nप्रिय शिक्षक $name,\nआपके मकतब ऐप का लॉगिन पिन है: *$pin*\nकृपया इसे गोपनीय रखें और किसी के साथ साझा न करें।";
        break;
      case Language.telugu:
        msg = "అస్సలాము అలైకుమ్,\nగౌరవనీయ ఉపాధ్యాయులు $name,\nమీ మక్తబ్ యాప్ లాగిన్ పిన్: *$pin*\nదయచేసి దీనిని రహస్యంగా ఉంచండి మరియు ఎవరితోనూ పంచుకోకండి.";
        break;
    }

    await launchWhatsApp(phone, msg + _signature);
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
  }) async {
    final lang = await _promptLanguageSelection(context);
    if (lang == null) return;

    final modeText = (paymentMode != null && paymentMode.isNotEmpty) ? paymentMode : 'Cash';
    final timeText = (dateTime != null && dateTime.isNotEmpty)
        ? dateTime
        : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final collector = (collectorName != null && collectorName.isNotEmpty) ? collectorName : 'Management';

    String msg = '';
    switch (lang) {
      case Language.english:
        msg = "Assalamu Alaikum,\nDear Parent,\n\n"
            "🧾 *FEE PAYMENT RECEIPT*\n"
            "👤 *Student*: *$studentName*\n"
            "💵 *Amount Received*: ₹$amount\n"
            "💳 *Payment Mode*: $modeText\n"
            "⏰ *Time*: $timeText\n"
            "👨‍💼 *Teacher / Manager*: $collector\n"
            "📅 *Month*: $month\n\n"
            "Jazakallah Khair.";
        break;
      case Language.urdu:
        msg = "السلام علیکم،\nمحترم والدین،\n\n"
            "🧾 *فیس کی رسیپٹ*\n"
            "👤 *طالب علم*: *$studentName*\n"
            "💵 *وصول شدہ رقم*: ₹$amount\n"
            "💳 *ادائیگی کا طریقہ*: $modeText\n"
            "⏰ *وقت*: $timeText\n"
            "👨‍💼 *ٹیچر / منیجر*: $collector\n"
            "📅 *مہینہ*: $month\n\n"
            "جزاک اللہ خیر۔";
        break;
      case Language.hindi:
        msg = "अस्सलामु अलैकुम,\nप्रिय माता-पिता,\n\n"
            "🧾 *शुल्क भुगतान रसीद*\n"
            "👤 *छात्र*: *$studentName*\n"
            "💵 *प्राप्त राशि*: ₹$amount\n"
            "💳 *भुगतान विधि*: $modeText\n"
            "⏰ *समय*: $timeText\n"
            "👨‍💼 *शिक्षक / प्रबंधक*: $collector\n"
            "📅 *महीना*: $month\n\n"
            "जज़ाकल्लाह खैर।";
        break;
      case Language.telugu:
        msg = "అస్సలాము అలైకుమ్,\nప్రియమైన తల్లిదండ్రులారా,\n\n"
            "🧾 *ఫీజు చెల్లింపు రసీదు*\n"
            "👤 *విద్యార్థి*: *$studentName*\n"
            "💵 *స్వీకరించిన మొత్తం*: ₹$amount\n"
            "💳 *చెల్లింపు విధానం*: $modeText\n"
            "⏰ *సమయం*: $timeText\n"
            "👨‍💼 *ఉపాధ్యాయుడు / మేనేజర్*: $collector\n"
            "📅 *నెల*: $month\n\n"
            "జజాకల్లా ఖైర్.";
        break;
    }

    await launchWhatsApp(phone, msg + _signature);
  }

  /// Send attendance absence alert with date.
  static Future<void> sendAttendanceAlert(
      BuildContext context, String phone, String studentName, {String? date}) async {
    final lang = await _promptLanguageSelection(context);
    if (lang == null) return;

    final dateStr = date ?? DateTime.now().toString().substring(0, 10);
    String msg = '';
    switch (lang) {
      case Language.english:
        msg = "Assalamu Alaikum,\nDear Parent,\nYour child *$studentName* was marked *Absent* from Maktab on *$dateStr*.\nPlease ensure regular attendance for better progress.";
        break;
      case Language.urdu:
        msg = "السلام علیکم،\nمحترم والدین،\nآپ کا بچہ *$studentName* آج *$dateStr* کو مکتب سے *غیر حاضر* ہے۔\nبہتر ترقی کے لیے باقاعدہ حاضری یقینی بنائیں۔";
        break;
      case Language.hindi:
        msg = "अस्सलामु अलैकुम,\nप्रिय माता-पिता,\nआपका बच्चा *$studentName* आज *$dateStr* को मकतब से *अनुपस्थित* रहा।\nबेहतर प्रगति के लिए नियमित उपस्थिति सुनिश्चित करें।";
        break;
      case Language.telugu:
        msg = "అస్సలాము అలైకుమ్,\nప్రియమైన తల్లిదండ్రులారా,\nమీ బిడ్డ *$studentName* తేది *$dateStr* న మక్తబ్ నుండి *హాజరు కాలేదు (గైర్హాజరు)*.\nమెరుగైన పురోగతి కోసం క్రమం తప్పకుండా హాజరయ్యేలా చూడండి.";
        break;
    }

    await launchWhatsApp(phone, msg + _signature);
  }

  /// Build and share a plain-text attendance report (no language selection needed).
  static String buildAttendanceReportText({
    required String date,
    required List<String> present,
    required List<String> absent,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📋 Attendance Report — $date');
    buffer.writeln('─────────────────────────');
    buffer.writeln('✅ Present (${present.length}):');
    for (final name in present) {
      buffer.writeln('  • $name');
    }
    buffer.writeln();
    buffer.writeln('❌ Absent / Leave (${absent.length}):');
    for (final name in absent) {
      buffer.writeln('  • $name');
    }
    buffer.write(_signature);
    return buffer.toString();
  }

  static Future<Language?> _promptLanguageSelection(BuildContext context) async {
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
