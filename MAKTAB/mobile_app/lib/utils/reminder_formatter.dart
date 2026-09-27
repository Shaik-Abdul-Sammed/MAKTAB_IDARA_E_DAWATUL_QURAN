class ReminderFormatter {
  static String formatFeeReminder({
    required double amountDue,
    required String studentName,
    required String admissionNumber,
    required String dueDate,
    String languageCode = 'en',
  }) {
    switch (languageCode) {
      case 'ur':
        return 'السلام علیکم، یہ مکتب ادارہ دعوت القرآن کی طرف سے طالب علم $studentName (داخلہ نمبر: $admissionNumber) کی ماہانہ فیس ₹${amountDue.toInt()} کی بابت یاد دہانی ہے۔ آخری تاریخ: $dueDate۔ جزاک اللہ خیر۔';
      case 'hi':
        return 'अस्सलामू अलैकुम, यह मकतब इदारा-ए-दावतुल कुरआन की ओर से छात्र $studentName (प्रवेश संख्या: $admissionNumber) की मासिक फीस ₹${amountDue.toInt()} के संबंध में अनुस्मारक है। देय तिथि: $dueDate। जज़ाक अल्लाह खैर।';
      case 'te':
        return 'అస్సలాము అలైకుమ్, విద్యార్థి $studentName (అడ్మిషన్ నం: $admissionNumber) యొక్క నెలవారీ రుసుము ₹${amountDue.toInt()} చెల్లింపునకు సంబంధించి మక్తబ్ ఇదారా-ఎ-దావతుల్ ఖురాన్ నుండి రిమైండర్. గడువు తేదీ: $dueDate. జజాక్ అల్లాహ్ ఖైర్.';
      case 'en':
      default:
        return 'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN regarding monthly fee of ₹${amountDue.toInt()} for student $studentName (ADM: $admissionNumber). Due Date: $dueDate. JazakAllah Khair.';
    }
  }
}
