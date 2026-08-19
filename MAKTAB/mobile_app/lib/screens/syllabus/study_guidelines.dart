import 'package:flutter/material.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudyGuidelinesScreen extends StatelessWidget {
  const StudyGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> rules = [
      {'rule': 'Makharij (Articulation Points)', 'detail': 'Proper pronunciation of letters from Throat, Tongue, Lips, and Nasal cavity.'},
      {'rule': 'Ghunna (Nasalization)', 'detail': 'Holding sound for 2 counts on Noon and Meem Mushaddad.'},
      {'rule': 'Qalqalah (Echoing Sound)', 'detail': 'Bouncing sound on 5 letters (ق, ط, ب, ج, د) when they carry Sukoon.'},
      {'rule': 'Ikhfa (Concealment)', 'detail': 'Hiding Noon Sakin / Tanween sound before 15 Ikhfa letters.'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Tajweed Study Guidelines'),
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: rules.length,
          itemBuilder: (context, index) {
            final r = rules[index];
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['rule']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
                  const SizedBox(height: 6),
                  Text(r['detail']!, style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.7), height: 1.4)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
