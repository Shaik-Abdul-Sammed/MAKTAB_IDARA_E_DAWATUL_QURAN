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
    return ['en', 'te', 'ur'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
