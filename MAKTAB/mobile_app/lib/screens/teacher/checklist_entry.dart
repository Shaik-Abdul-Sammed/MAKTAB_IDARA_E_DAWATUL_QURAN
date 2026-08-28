import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../models/checklist.dart';
import '../../../repositories/checklist_repository.dart';
import '../../../utils/voice_parser.dart';

class ChecklistEntryScreen extends StatefulWidget {
  const ChecklistEntryScreen({super.key});

  @override
  State<ChecklistEntryScreen> createState() => _ChecklistEntryScreenState();
}

class _ChecklistEntryScreenState extends State<ChecklistEntryScreen> {
  List<ChecklistQuestion> _items = [];
  final Set<int> _completedIds = {};
  bool _isLoading = true;
  bool _isListening = false;
  String _searchQuery = '';
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final repo = ChecklistRepository();
      final records = await repo.getAllQuestions();
      if (mounted) {
        setState(() {
          _items = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          if (mounted) setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
              final newCompleted = VoiceParser.parseChecklistVoiceInput(val.recognizedWords, _items);
              if (mounted && newCompleted.isNotEmpty) {
                setState(() {
                  _completedIds.addAll(newCompleted);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Voice Matched ${newCompleted.length} items: "${val.recognizedWords}"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available on this device.')),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  void _showDetailSheet(ChecklistQuestion item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Record Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const Divider(),
            const SizedBox(height: 12),
            
              // Try to cast to map, if fails, use toString
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    () {
                      try {
                        return (item as dynamic).toMap().entries.map((e) => '${e.key}: ${e.value}').join('\n\n');
                      } catch (_) {
                        return item.toString();
                      }
                    }(), 
                    style: const TextStyle(fontSize: 16)
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) => item.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text(
          'Submit Daily Checklist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _listenVoice,
        backgroundColor: _isListening ? Colors.red : const Color(0xFF004D40),
        foregroundColor: const Color(0xFFFFD700),
        icon: Icon(_isListening ? Icons.mic_off_rounded : Icons.mic_rounded),
        label: Text(_isListening ? 'Listening...' : 'Voice Entry', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search checklist questions...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRecords,
                color: const Color(0xFF004D40),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
                    : filteredItems.isEmpty
                        ? const Center(child: Text('No matching records found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isDone = item.id != null && _completedIds.contains(item.id!);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDone ? const Color(0xFFE8F5E9) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDone ? const Color(0xFF2E7D32) : Colors.black12,
                                    width: isDone ? 1.5 : 1.0,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: isDone,
                                      activeColor: const Color(0xFF004D40),
                                      checkColor: const Color(0xFFFFD700),
                                      onChanged: (val) {
                                        if (item.id == null) return;
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          if (val == true) {
                                            _completedIds.add(item.id!);
                                          } else {
                                            _completedIds.remove(item.id!);
                                          }
                                        });
                                      },
                                      title: Text(
                                        item.text,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          color: isDone ? Colors.green.shade900 : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text('Category: ${item.category}'),
                                      secondary: IconButton(
                                        icon: const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF004D40)),
                                        onPressed: () => _showDetailSheet(item),
                                        tooltip: 'View Details',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
