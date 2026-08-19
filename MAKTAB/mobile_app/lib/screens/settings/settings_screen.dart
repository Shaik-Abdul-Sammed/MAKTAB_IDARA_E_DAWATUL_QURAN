import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/services/backup_restore_service.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/config/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backupService = BackupRestoreService();
  bool _isLoading = false;
  bool _biometricEnabled = true;

  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    final path = await _backupService.createBackup();
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved at $path')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create backup')));
    }
  }

  Future<void> _handleRestore() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      final success = await _backupService.restoreBackup(result.files.single.path!);
      setState(() => _isLoading = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored! Please log in again.')));
        Provider.of<AuthProvider>(context, listen: false).logout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to restore backup')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Tools & Integrations'),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF004D40)),
                  title: const Text('Fee Management & UPI'),
                  subtitle: const Text('Track pending fees and collect via UPI'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/fees'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.chat_rounded, color: Colors.green),
                  title: const Text('WhatsApp Broadcasts'),
                  subtitle: const Text('Send template messages to parents'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/tools/whatsapp'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF004D40)),
                  title: const Text('Calendar Sync'),
                  subtitle: const Text('Add exam and fee due dates to device calendar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/tools/calendar'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.contacts_rounded, color: Color(0xFF004D40)),
                  title: const Text('Contact Directory & Sync'),
                  subtitle: const Text('Export student and guardian contacts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/tools/contacts'),
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Server & Network Sync'),
                FutureBuilder<String>(
                  future: ApiConfig.baseUrl,
                  builder: (context, snapshot) {
                    final currentUrl = snapshot.data ?? 'http://127.0.0.1:8000';
                    return ListTile(
                      leading: const Icon(Icons.dns_rounded, color: Color(0xFF004D40)),
                      title: const Text('FastAPI Server URL'),
                      subtitle: Text(currentUrl),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: () => _showServerConfigDialog(currentUrl),
                    );
                  },
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Security & Biometrics'),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded, color: Color(0xFF004D40)),
                  title: const Text('Biometric PIN Lock'),
                  subtitle: const Text('Require Fingerprint/Face to open app'),
                  value: _biometricEnabled,
                  activeThumbColor: const Color(0xFF004D40),
                  onChanged: (val) => setState(() => _biometricEnabled = val),
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('Data & Storage'),
                ListTile(
                  leading: const Icon(Icons.backup, color: Color(0xFF004D40)),
                  title: const Text('Backup Database'),
                  subtitle: const Text('Export your encrypted SQLite data to ZIP'),
                  onTap: _handleBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: Color(0xFF004D40)),
                  title: const Text('Restore Database'),
                  subtitle: const Text('Import data from a backup ZIP file'),
                  onTap: _handleRestore,
                ),
                const SizedBox(height: 20),

                _buildSectionHeader('About App'),
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: Color(0xFF004D40)),
                  title: Text('Maktab Quran Management'),
                  subtitle: Text('Version 2.4.0 (Build 2026) · Offline First'),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sign out securely'),
                  onTap: () async {
                    await Provider.of<AuthProvider>(context, listen: false).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _showServerConfigDialog(String currentUrl) async {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure FastAPI Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the central server URL (e.g. http://192.168.1.100:8000 for LAN or local IP):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://192.168.1.100:8000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiConfig.setBaseUrl(newUrl);
                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server URL updated to $newUrl')),
                  );
                }
              }
            },
            child: const Text('Save URL', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40)),
      ),
    );
  }
}
