import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MicrophoneInputButton extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onResult;

  const MicrophoneInputButton({
    super.key,
    required this.controller,
    this.onResult,
  });

  @override
  _MicrophoneInputButtonState createState() => _MicrophoneInputButtonState();
}

class _MicrophoneInputButtonState extends State<MicrophoneInputButton> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) {
        debugPrint('SpeechError: $val');
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            widget.controller.text = val.recognizedWords;
            if (widget.onResult != null) {
              widget.onResult!(val.recognizedWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable) {
      return SizedBox.shrink(); // Hide if device doesn't support speech to text
    }
    
    return IconButton(
      icon: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: _isListening ? Colors.red : Colors.grey,
      ),
      onPressed: _listen,
      tooltip: 'Speak to Text',
    );
  }
}
