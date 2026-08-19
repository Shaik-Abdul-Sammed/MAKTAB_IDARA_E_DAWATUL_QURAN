import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class SyllabusHubScreen extends StatefulWidget {
  const SyllabusHubScreen({super.key});

  @override
  State<SyllabusHubScreen> createState() => _SyllabusHubScreenState();
}

class _SyllabusHubScreenState extends State<SyllabusHubScreen> {
  final List<Map<String, String>> _tracks = [
    {'title': 'Noorani Qaida (Beginner)', 'desc': 'Arabic Alphabet, Pronunciation & Basic Vowels (Harakat)'},
    {'title': 'Nazira Quran (Intermediate)', 'desc': 'Fluency in reading the Holy Quran with Tajweed rules'},
    {'title': 'Hifz-ul-Quran (Advanced)', 'desc': 'Memorization of Surahs, Juz 30 & full Quran'},
    {'title': 'Essential Islamic Duas & Masnoon Supplications', 'desc': 'Daily Athkar, Salah duas & morals'},
  ];

  Future<void> _pickSyllabusPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attached Syllabus PDF: ${result.files.single.name}'),
          backgroundColor: const Color(0xFF004D40),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Syllabus & Curriculum Hub',
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            onPressed: _pickSyllabusPdf,
            tooltip: 'Attach PDF Syllabus Doc',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: _tracks.length,
          itemBuilder: (context, index) {
            final t = _tracks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF004D40), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
                        const SizedBox(height: 4),
                        Text(t['desc']!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
