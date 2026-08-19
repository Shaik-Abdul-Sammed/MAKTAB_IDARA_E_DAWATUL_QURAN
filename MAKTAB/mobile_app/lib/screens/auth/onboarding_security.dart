import 'package:flutter/material.dart';

class OnboardingSecurityScreen extends StatefulWidget {
  const OnboardingSecurityScreen({super.key});

  @override
  State<OnboardingSecurityScreen> createState() => _OnboardingSecurityScreenState();
}

class _OnboardingSecurityScreenState extends State<OnboardingSecurityScreen> {
  String _pinCode = '';
  
  void _onKeypadPressed(String digit) {
    if (_pinCode.length < 4) {
      setState(() => _pinCode += digit);
      if (_pinCode.length == 4) {
        // Simulate login state trigger
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accessing database...')),
        );
        Navigator.pop(context);
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
                'Security Onboarding',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'All PIN hashes, student records, and audits are secured via local SHA-256 hashes.',
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
