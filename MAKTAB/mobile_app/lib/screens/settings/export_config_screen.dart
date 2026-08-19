import 'package:flutter/material.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class ExportConfigScreen extends StatefulWidget {
  const ExportConfigScreen({super.key});

  @override
  State<ExportConfigScreen> createState() => _ExportConfigScreenState();
}

class _ExportConfigScreenState extends State<ExportConfigScreen> {
  final TextEditingController _instCtrl = TextEditingController(text: 'MAKTAB - Idara-e-Dawatul Qur\'an');
  final TextEditingController _headerCtrl = TextEditingController(text: 'Official Academic & Fee Record');

  @override
  void dispose() {
    _instCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF Header & Branding Settings Saved!'), backgroundColor: Color(0xFF004D40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'PDF Header & Branding Config'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Institution Title on PDF Documents', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _instCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Document Subtitle Header', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _headerCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Export Branding', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
