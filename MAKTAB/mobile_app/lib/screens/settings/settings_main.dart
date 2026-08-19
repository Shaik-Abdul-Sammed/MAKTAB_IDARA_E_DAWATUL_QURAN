import 'package:flutter/material.dart';

class SettingsMainScreen extends StatefulWidget {
  const SettingsMainScreen({super.key});

  @override
  State<SettingsMainScreen> createState() => _SettingsMainScreenState();
}

class _SettingsMainScreenState extends State<SettingsMainScreen> {
  bool _toggleOption1 = true;
  bool _toggleOption2 = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'System Settings Central',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF004D40), // Dark green
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'System Config Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage local configurations, biometric auth, and database operations.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            
            // Toggle options
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Security Pin Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Require 4-digit PIN on every session load'),
                    value: _toggleOption1,
                    activeThumbColor: const Color(0xFF004D40),
                    onChanged: (val) => setState(() => _toggleOption1 = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Offline Database Compression', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Compact indices periodically in the background'),
                    value: _toggleOption2,
                    activeThumbColor: const Color(0xFF004D40),
                    onChanged: (val) => setState(() => _toggleOption2 = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Standard action list tiles
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storage, color: Color(0xFF004D40)),
                    title: const Text('Manage Storage Space'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showActionDialog('Database compaction triggered. Storage space optimized!');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync_problem, color: Color(0xFF004D40)),
                    title: const Text('Reset local database indexes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showActionDialog('Database indexes successfully rebuilt.');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings Action'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF004D40))),
          ),
        ],
      ),
    );
  }
}
