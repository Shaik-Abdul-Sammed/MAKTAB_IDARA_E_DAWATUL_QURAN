import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';
import 'package:maktab_app/config/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
      tooltip: 'Language / زبان / భాష',
      onSelected: (String langCode) {
        localeProvider.setLocale(Locale(langCode));
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              const Text('🇬🇧 ', style: TextStyle(fontSize: 16)),
              Text('English', style: TextStyle(
                fontWeight: localeProvider.locale.languageCode == 'en' ? FontWeight.bold : FontWeight.normal,
                color: localeProvider.locale.languageCode == 'en' ? AppColors.primaryTeal : Colors.black87,
              )),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'te',
          child: Row(
            children: [
              const Text('🇮🇳 ', style: TextStyle(fontSize: 16)),
              Text('తెలుగు (Telugu)', style: TextStyle(
                fontWeight: localeProvider.locale.languageCode == 'te' ? FontWeight.bold : FontWeight.normal,
                color: localeProvider.locale.languageCode == 'te' ? AppColors.primaryTeal : Colors.black87,
              )),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ur',
          child: Row(
            children: [
              const Text('🇵🇰 ', style: TextStyle(fontSize: 16)),
              Text('اردو (Urdu)', style: TextStyle(
                fontWeight: localeProvider.locale.languageCode == 'ur' ? FontWeight.bold : FontWeight.normal,
                color: localeProvider.locale.languageCode == 'ur' ? AppColors.primaryTeal : Colors.black87,
              )),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'hi',
          child: Row(
            children: [
              const Text('🇮🇳 ', style: TextStyle(fontSize: 16)),
              Text('हिंदी (Hindi)', style: TextStyle(
                fontWeight: localeProvider.locale.languageCode == 'hi' ? FontWeight.bold : FontWeight.normal,
                color: localeProvider.locale.languageCode == 'hi' ? AppColors.primaryTeal : Colors.black87,
              )),
            ],
          ),
        ),
      ],
    );
  }
}
