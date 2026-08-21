import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return PopupMenuButton<String>(
      icon: Icon(Icons.language),
      onSelected: (String langCode) {
        localeProvider.setLocale(Locale(langCode));
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Text('English', style: TextStyle(
            fontWeight: localeProvider.locale.languageCode == 'en' ? FontWeight.bold : FontWeight.normal
          )),
        ),
        PopupMenuItem<String>(
          value: 'te',
          child: Text('తెలుగు (Telugu)', style: TextStyle(
            fontWeight: localeProvider.locale.languageCode == 'te' ? FontWeight.bold : FontWeight.normal
          )),
        ),
        PopupMenuItem<String>(
          value: 'ur',
          child: Text('اردو (Urdu)', style: TextStyle(
            fontWeight: localeProvider.locale.languageCode == 'ur' ? FontWeight.bold : FontWeight.normal
          )),
        ),
        PopupMenuItem<String>(
          value: 'hi',
          child: Text('हिंदी (Hindi)', style: TextStyle(
            fontWeight: localeProvider.locale.languageCode == 'hi' ? FontWeight.bold : FontWeight.normal
          )),
        ),
      ],
    );
  }
}
