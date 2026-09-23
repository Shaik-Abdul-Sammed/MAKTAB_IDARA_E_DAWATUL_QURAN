import 'package:flutter/material.dart';

class LanguagePickerDialog extends StatelessWidget {
  const LanguagePickerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const LanguagePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('English'),
            onTap: () => Navigator.pop(context, 'en'),
          ),
          ListTile(
            title: const Text('اردو (Urdu)'),
            onTap: () => Navigator.pop(context, 'ur'),
          ),
          ListTile(
            title: const Text('हिन्दी (Hindi)'),
            onTap: () => Navigator.pop(context, 'hi'),
          ),
          ListTile(
            title: const Text('తెలుగు (Telugu)'),
            onTap: () => Navigator.pop(context, 'te'),
          ),
        ],
      ),
    );
  }
}
