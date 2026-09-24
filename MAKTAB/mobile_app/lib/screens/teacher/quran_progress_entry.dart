import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/quran_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quran_progress_provider.dart';
import '../../repositories/quran_progress_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class QuranProgressEntryScreen extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final QuranProgress? existing;

  const QuranProgressEntryScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.existing,
  });

  @override
  State<QuranProgressEntryScreen> createState() => _QuranProgressEntryScreenState();
}

class _QuranProgressEntryScreenState extends State<QuranProgressEntryScreen> {
  late final QuranProgressProvider _provider;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _surahCtrl;
  late final TextEditingController _ayahFromCtrl;
  late final TextEditingController _ayahToCtrl;
  late final TextEditingController _remarksCtrl;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  String _grade = 'A+';
  String _recitationType = 'Sabaq';
  int _tajweedMistakes = 0;
  int _memorizationMistakes = 0;

  @override
  void initState() {
    super.initState();
    _provider = QuranProgressProvider(QuranProgressRepository());
    _speech = stt.SpeechToText();

    if (widget.existing != null) {
      final e = widget.existing!;
      _surahCtrl = TextEditingController(text: e.surah);
      _ayahFromCtrl = TextEditingController(text: e.ayahFrom.toString());
      _ayahToCtrl = TextEditingController(text: e.ayahTo.toString());
      _remarksCtrl = TextEditingController(text: e.remarks ?? '');
      _grade = e.grade;
      _recitationType = e.recitationType;
    } else {
      _surahCtrl = TextEditingController(text: 'Al-Baqarah');
      _ayahFromCtrl = TextEditingController(text: '1');
      _ayahToCtrl = TextEditingController(text: '10');
      _remarksCtrl = TextEditingController();
    }

    final effStudentId = widget.existing?.studentId ?? widget.studentId ?? 0;
    if (effStudentId > 0) {
      _provider.fetchProgress(effStudentId);
    }
  }

  @override
  void dispose() {
    _surahCtrl.dispose();
    _ayahFromCtrl.dispose();
    _ayahToCtrl.dispose();
    _remarksCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone unavailable.')),
        );
      }
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final spoken = result.recognizedWords.trim();
        final parts = spoken.split(RegExp(r'[,،.]'));
        if (parts.isNotEmpty) _surahCtrl.text = parts.first.trim();
        if (parts.length > 1) {
          _remarksCtrl.text = parts.sublist(1).join(' ').trim();
        }
        setState(() => _isListening = false);
      },
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (widget.existing != null) {
        final updated = widget.existing!.copyWith(
          surah: _surahCtrl.text.trim(),
          ayahFrom: int.tryParse(_ayahFromCtrl.text.trim()),
          ayahTo: int.tryParse(_ayahToCtrl.text.trim()),
          grade: _grade,
          recitationType: _recitationType,
          remarks: _remarksCtrl.text.trim(),
        );
        await QuranProgressRepository().updateQuranProgress(updated);
        await CloudSyncService.instance.pushQuranProgress(updated);
        CloudSyncService.instance.notifyDataChanged('quran_progress');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recitation progress updated successfully!'),
            backgroundColor: Color(0xFF004D40),
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentTeacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
      final effStudentId = widget.studentId ?? 0;
      await _provider.addProgress(
        studentId: effStudentId,
        teacherId: currentTeacherId,
        surah: _surahCtrl.text,
        ayahFrom: int.parse(_ayahFromCtrl.text),
        ayahTo: int.parse(_ayahToCtrl.text),
        grade: _grade,
        recitationType: _recitationType,
        remarks: _remarksCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recitation progress logged successfully!'),
          backgroundColor: Color(0xFF004D40),
        ),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('[QURAN_PROGRESS] save error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save recitation progress: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: widget.existing != null
              ? 'Edit Quran Progress'
              : (widget.studentName != null ? 'Log Progress: ${widget.studentName}' : 'Log Quran Progress'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Recitation Details'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Sabaq', label: Text('Sabaq')),
                        ButtonSegment(value: 'Sabaqi', label: Text('Sabaqi')),
                        ButtonSegment(value: 'Manzil', label: Text('Manzil')),
                      ],
                      selected: {_recitationType},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _recitationType = newSelection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final surahValue = _surahCtrl.text.isNotEmpty ? _surahCtrl.text : _surahPresets.first;
                      final effectiveValue = _surahPresets.contains(surahValue) ? surahValue : _surahPresets.first;
                      return DropdownButtonFormField<String>(
                        initialValue: effectiveValue,
                        decoration: InputDecoration(
                          labelText: 'Surah Name',
                          prefixIcon: const Icon(Icons.menu_book_outlined, color: Color(0xFF004D40), size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD8E8D5), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF004D40), width: 1.5),
                          ),
                        ),
                        items: _surahPresets.toSet().map((preset) {
                          return DropdownMenuItem<String>(
                            value: preset,
                            child: Text(preset, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _surahCtrl.text = val);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Mistake Tracking Section
                  const _SectionTitle('Tajweed / Memorization Mistakes'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMistakeCounter(
                          title: 'Tajweed Mistakes',
                          count: _tajweedMistakes,
                          onIncrement: () => setState(() => _tajweedMistakes++),
                          onDecrement: () => setState(() {
                            if (_tajweedMistakes > 0) _tajweedMistakes--;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMistakeCounter(
                          title: 'Memorization Mistakes',
                          count: _memorizationMistakes,
                          onIncrement: () => setState(() => _memorizationMistakes++),
                          onDecrement: () => setState(() {
                            if (_memorizationMistakes > 0) _memorizationMistakes--;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _ayahFromCtrl,
                          label: 'Ayah From',
                          hint: '1',
                          icon: Icons.numbers_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _ayahToCtrl,
                          label: 'Ayah To',
                          hint: '10',
                          icon: Icons.numbers_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('Grade & Performance'),
                  const SizedBox(height: 12),
                  _buildGradeSelector(),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _remarksCtrl,
                          label: 'Teacher Remarks / Tajweed Notes',
                          hint: 'e.g. Excellent makhraj',
                          icon: Icons.notes_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _toggleListen,
                        style: IconButton.styleFrom(
                          backgroundColor: _isListening ? Colors.red : const Color(0xFF004D40),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                        tooltip: 'Voice Dictate Remarks',
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Consumer<QuranProgressProvider>(
                    builder: (_, p, _) => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: p.isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: p.isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Color(0xFF004D40), strokeWidth: 2.5),
                              )
                            : const Text('Save Recitation Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('Recent Recitation History'),
                  const SizedBox(height: 12),
                  Consumer<QuranProgressProvider>(
                    builder: (_, p, _) {
                      if (p.progressHistory.isEmpty) {
                        return const Text('No past recitation logs recorded.', style: TextStyle(fontSize: 12, color: Colors.black45));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: p.progressHistory.length,
                        itemBuilder: (context, index) {
                          final item = p.progressHistory[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark_outline, color: Color(0xFF004D40), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item.surah} (${item.ayahFrom}-${item.ayahTo})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (item.remarks != null)
                                        Text(item.remarks!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004D40).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(item.grade,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradeSelector() {
    final grades = [
      {'code': 'A+', 'label': 'A+ (Mumtaz)'},
      {'code': 'A', 'label': 'A (Jayyid)'},
      {'code': 'B', 'label': 'B (Good)'},
      {'code': 'C', 'label': 'C (Needs Work)'},
    ];

    return Wrap(
      spacing: 8,
      children: grades.map((g) {
        final isSelected = _grade == g['code'];
        return ChoiceChip(
          label: Text(g['label']!),
          selected: isSelected,
          selectedColor: const Color(0xFF004D40),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF004D40),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          onSelected: (_) => setState(() => _grade = g['code']!),
        );
      }).toList(),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF004D40), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8E8D5), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF004D40), width: 1.5),
        ),
      ),
    );
  }
  Widget _buildMistakeCounter({
    required String title,
    required int count,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8D5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: onDecrement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF004D40)),
                onPressed: onIncrement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)));
  }
}
