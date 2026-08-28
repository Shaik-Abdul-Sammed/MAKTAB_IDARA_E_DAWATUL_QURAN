import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/student.dart';
import '../utils/voice_parser.dart';

class VoiceAttendanceItem {
  final int id;
  final String name;
  String currentStatus;

  VoiceAttendanceItem({
    required this.id,
    required this.name,
    this.currentStatus = 'Present',
  });
}

class VoiceAttendanceDialog extends StatefulWidget {
  final String title;
  final List<VoiceAttendanceItem> items;
  final Function(Map<int, String> updatedStatuses) onComplete;

  const VoiceAttendanceDialog({
    super.key,
    required this.title,
    required this.items,
    required this.onComplete,
  });

  @override
  State<VoiceAttendanceDialog> createState() => _VoiceAttendanceDialogState();
}

class _VoiceAttendanceDialogState extends State<VoiceAttendanceDialog> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';
  String _statusFeedback = 'Tap the microphone and say commands like:\n"Ahmad Present", "Zaid Absent", or "Mark all present"';
  late Map<int, String> _statuses;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _statuses = {for (var item in widget.items) item.id: item.currentStatus};
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (val) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusFeedback = 'Speech recognition error: ${val.errorMsg}';
            });
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusFeedback = 'Voice recognition is unavailable on this device.';
        });
      }
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _statusFeedback = 'Listening... Speak name and status (e.g. "Bilal Present")';
        });
        _speech.listen(
          onResult: (val) {
            setState(() {
              _lastWords = val.recognizedWords;
              _parseVoiceCommand(_lastWords);
            });
          },
        );
      } else {
        setState(() => _statusFeedback = 'Microphone permission or speech service missing.');
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _parseVoiceCommand(String speechText) {
    if (speechText.trim().isEmpty) return;

    final dummyStudents = widget.items.map((i) => Student(
      id: i.id,
      admissionNumber: 'V${i.id}',
      name: i.name,
      dob: '2015-01-01',
      gender: 'Male',
      fatherName: 'Father',
      phone: '0000000000',
      createdAt: '2026-08-01',
    )).toList();

    final result = VoiceParser.parseAttendanceVoiceInput(speechText, dummyStudents);

    if (result.studentStatuses.isNotEmpty) {
      setState(() {
        _statuses.addAll(result.studentStatuses);
        if (result.matchedNames.isNotEmpty) {
          _statusFeedback = 'Updated: ${result.matchedNames.take(3).join(", ")}';
        } else {
          _statusFeedback = 'Updated statuses from voice!';
        }
      });
    } else {
      setState(() {
        _statusFeedback = 'Recognized: "$speechText"\n(Could not match student/teacher name)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, color: Color(0xFF004D40), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // Speech Status Feedback Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isListening ? const Color(0xFFE8F5E9) : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isListening ? const Color(0xFF004D40) : Colors.black12,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _statusFeedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isListening ? const Color(0xFF004D40) : Colors.black87,
                    ),
                  ),
                  if (_lastWords.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$_lastWords"',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

            // Mic Button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : const Color(0xFF004D40),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : const Color(0xFF004D40)).withValues(alpha: 0.4),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isListening ? 'TAP TO STOP LISTENING' : 'TAP TO START VOICE ATTENDANCE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: _isListening ? Colors.red : const Color(0xFF004D40),
              ),
            ),
            const SizedBox(height: 16),

            // Preview List of Current States
            Flexible(
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final st = _statuses[item.id] ?? 'Present';
                    Color stColor = Colors.green.shade700;
                    if (st == 'Absent') stColor = Colors.red;
                    if (st == 'Late') stColor = Colors.orange.shade800;
                    if (st == 'Leave') stColor = Colors.blue;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          st,
                          style: TextStyle(color: stColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      widget.onComplete(_statuses);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Voice Results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
