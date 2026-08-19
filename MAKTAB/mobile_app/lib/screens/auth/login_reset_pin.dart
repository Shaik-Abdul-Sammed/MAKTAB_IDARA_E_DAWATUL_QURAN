import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginResetPinScreen extends StatefulWidget {
  const LoginResetPinScreen({super.key});

  @override
  State<LoginResetPinScreen> createState() => _LoginResetPinScreenState();
}

class _LoginResetPinScreenState extends State<LoginResetPinScreen> {
  String _pinCode = '';
  bool _sendToWhatsApp = false;
  
  void _onKeypadPressed(String digit) async {
    if (_pinCode.length < 4) {
      setState(() => _pinCode += digit);
      if (_pinCode.length == 4) {
        if (_sendToWhatsApp) {
          final text = Uri.encodeComponent("Assalamu Alaikum. My Maktab app PIN is: $_pinCode. Please keep this safe.");
          final url = Uri.parse("https://wa.me/?text=$text");
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accessing database...')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40), // Dark green background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock, size: 64, color: Color(0xFFFFD700)),
              const SizedBox(height: 24),
              const Text(
                'Reset PIN Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Submit new security PIN credentials to log in.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              
              // Simulated dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pinCode.length ? const Color(0xFFFFD700) : Colors.white24,
                  ),
                )),
              ),
              const Spacer(),
              
              // WhatsApp backup option
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _sendToWhatsApp,
                    onChanged: (value) => setState(() => _sendToWhatsApp = value ?? false),
                    fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFFFFD700) : Colors.transparent),
                    checkColor: const Color(0xFF004D40),
                    side: const BorderSide(color: Colors.white70),
                  ),
                  const Text('Send PIN to WhatsApp for backup', style: TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Keyboard keypad
              Table(
                children: [
                  TableRow(children: [
                    _buildKeypadButton('1'),
                    _buildKeypadButton('2'),
                    _buildKeypadButton('3'),
                  ]),
                  TableRow(children: [
                    _buildKeypadButton('4'),
                    _buildKeypadButton('5'),
                    _buildKeypadButton('6'),
                  ]),
                  TableRow(children: [
                    _buildKeypadButton('7'),
                    _buildKeypadButton('8'),
                    _buildKeypadButton('9'),
                  ]),
                  TableRow(children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    _buildKeypadButton('0'),
                    IconButton(
                      icon: const Icon(Icons.backspace, color: Colors.white),
                      onPressed: () {
                        if (_pinCode.isNotEmpty) {
                          setState(() => _pinCode = _pinCode.substring(0, _pinCode.length - 1));
                        }
                      },
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String num) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton(
        onPressed: () => _onKeypadPressed(num),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.white10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(num, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  
}
