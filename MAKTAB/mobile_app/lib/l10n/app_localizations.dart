import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Maktab Management',
      'login': 'Login',
      'admin_dashboard': 'Admin Dashboard',
      'teacher_dashboard': 'Teacher Dashboard',
      'attendance': 'Attendance',
      'quran_progress': 'Quran Progress',
      'reports': 'Reports',
      'profiles': 'Profiles',
      'checklist': 'Daily Checklist',
      'settings': 'Settings',
      'logout': 'Logout',
      'present': 'Present',
      'absent': 'Absent',
      'mark_all_present': 'Mark All Present',
      'students': 'Students',
      'teachers': 'Teachers',
      'batches': 'Batches',
      'fee_management': 'Fee Management',
      'fee_receipt': 'Fee Receipt',
      'amount': 'Amount',
      'payment_mode': 'Payment Mode',
      'date_time': 'Date & Time',
      'save': 'Save',
      'cancel': 'Cancel',
      'send_whatsapp': 'Send WhatsApp',
      'print_pdf': 'Print PDF',
      'search': 'Search',
      'academic_history': 'Academic History',
      'syllabus': 'Syllabus Tracker',
      'behavior_log': 'Behavior Log',
      'announcements': 'Announcements',
      'promotions': 'Student Promotions',
      'salary_management': 'Salary Management',
      'sync': 'Sync Data',
      'language': 'Language',
      'help_support': 'Help & Support',
      'management_console': 'Management Console',
      'teacher_portal': 'Teacher Portal',
    },
    'te': {
      'app_title': 'మక్తబ్ నిర్వహణ',
      'login': 'లాగిన్',
      'admin_dashboard': 'అడ్మిన్ డాష్బోర్డ్',
      'teacher_dashboard': 'ఉపాధ్యాయ డాష్బోర్డ్',
      'attendance': 'హాజరు',
      'quran_progress': 'ఖురాన్ పురోగతి',
      'reports': 'నివేదికలు',
      'profiles': 'ప్రొఫైల్స్',
      'checklist': 'రోజువారీ చెక్‌లిస్ట్',
      'settings': 'సెట్టింగ్‌లు',
      'logout': 'లాగ్అవుట్',
      'present': 'హాజరు',
      'absent': 'గైర్హాజరు',
      'mark_all_present': 'అందరినీ హాజరుగా గుర్తించండి',
      'students': 'విద్యార్థులు',
      'teachers': 'ఉపాధ్యాయులు',
      'batches': 'బ్యాచ్‌లు',
      'fee_management': 'ఫీజు నిర్వహణ',
      'fee_receipt': 'ఫీజు రసీదు',
      'amount': 'మొత్తం',
      'payment_mode': 'చెల్లింపు విధానం',
      'date_time': 'తేదీ & సమయం',
      'save': 'సేవ్ చేయండి',
      'cancel': 'రద్దు చేయండి',
      'send_whatsapp': 'వాట్సాప్ ద్వారా పంపండి',
      'print_pdf': 'పిడిఎఫ్ ప్రింట్ చేయండి',
      'search': 'శోధించండి',
      'academic_history': 'విద్యా చరిత్ర',
      'syllabus': 'సిలబస్ ట్రాకర్',
      'behavior_log': 'ప్రవర్తన లాగ్',
      'announcements': 'ప్రకటనలు',
      'promotions': 'విద్యార్థుల ప్రమోషన్లు',
      'salary_management': 'జీతాల నిర్వహణ',
      'sync': 'డేటా సింక్ చేయండి',
      'language': 'భాష',
      'help_support': 'సహాయం & మద్దతు',
      'management_console': 'నిర్వహణ కన్సోల్',
      'teacher_portal': 'ఉపాధ్యాయ పోర్టల్',
    },
    'ur': {
      'app_title': 'مکتب مینجمنٹ',
      'login': 'لاگ ان کریں',
      'admin_dashboard': 'ایڈمن ڈیش بورڈ',
      'teacher_dashboard': 'استاد ڈیش بورڈ',
      'attendance': 'حاضری',
      'quran_progress': 'قرآن کی پیشرفت',
      'reports': 'رپورٹس',
      'profiles': 'پروفائلز',
      'checklist': 'روزانہ کی فہرست',
      'settings': 'ترتیبات',
      'logout': 'لاگ آؤٹ',
      'present': 'حاضر',
      'absent': 'غیر حاضر',
      'mark_all_present': 'سب کو حاضر نشان زد کریں',
      'students': 'طلباء',
      'teachers': 'اساتذہ',
      'batches': 'بیچز',
      'fee_management': 'فیس مینجمنٹ',
      'fee_receipt': 'فیس کی رسیپٹ',
      'amount': 'رقم',
      'payment_mode': 'ادائیگی کا طریقہ',
      'date_time': 'تاریخ اور وقت',
      'save': 'محفوظ کریں',
      'cancel': 'منسوخ کریں',
      'send_whatsapp': 'واٹس ایپ بھیجیں',
      'print_pdf': 'پی ڈی ایف پرنٹ کریں',
      'search': 'تلاش کریں',
      'academic_history': 'تعلیمی ہسٹری',
      'syllabus': 'نصاب ٹریکر',
      'behavior_log': 'رویے کا لاگ',
      'announcements': 'اعلانات',
      'promotions': 'طلباء کی ترقیاں',
      'salary_management': 'تنخواہ کی منتقلی',
      'sync': 'ڈیٹا ہم وقت سازی',
      'language': 'زبان',
      'help_support': 'مدد اور معاونت',
      'management_console': 'مینجمنٹ کنسول',
      'teacher_portal': 'ٹیچر پورٹل',
    },
    'hi': {
      'app_title': 'मकतब प्रबंधन',
      'login': 'लॉगिन करें',
      'admin_dashboard': 'एडमिन डैशबोर्ड',
      'teacher_dashboard': 'शिक्षक डैशबोर्ड',
      'attendance': 'उपस्थिति',
      'quran_progress': 'क़ुरआन प्रगति',
      'reports': 'रिपोर्ट',
      'profiles': 'प्रोफ़ाइल',
      'checklist': 'दैनिक चेकलिस्ट',
      'settings': 'सेटिंग्स',
      'logout': 'लॉगआउट',
      'present': 'उपस्थित',
      'absent': 'अनुपस्थित',
      'mark_all_present': 'सभी को उपस्थित चिन्हित करें',
      'students': 'छात्र',
      'teachers': 'शिक्षक',
      'batches': 'बैच',
      'fee_management': 'शुल्क प्रबंधन',
      'fee_receipt': 'शुल्क रसीद',
      'amount': 'राशि',
      'payment_mode': 'भुगतान विधि',
      'date_time': 'तिथि एवं समय',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'send_whatsapp': 'व्हाट्सएप भेजें',
      'print_pdf': 'पीडीएफ प्रिंट करें',
      'search': 'खोजें',
      'academic_history': 'शैक्षणिक इतिहास',
      'syllabus': 'पाठ्यक्रम ट्रैकर',
      'behavior_log': 'व्यवहार लॉग',
      'announcements': 'घोषणाएँ',
      'promotions': 'छात्र पदोन्नति',
      'salary_management': 'वेतन प्रबंधन',
      'sync': 'डेटा सिंक करें',
      'language': 'भाषा',
      'help_support': 'सहायता एवं समर्थन',
      'management_console': 'प्रबंधन कंसोल',
      'teacher_portal': 'शिक्षक पोर्टल',
    }
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'te', 'ur', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
