import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maktab_app/services/backup_restore_service.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class BackupHistoryScreen extends StatefulWidget {
  const BackupHistoryScreen({super.key});

  @override
  State<BackupHistoryScreen> createState() => _BackupHistoryScreenState();
}

class _BackupHistoryScreenState extends State<BackupHistoryScreen> {
  final _backupService = BackupRestoreService();
  bool _isLoading = false;

  final List<Map<String, String>> _backups = [
    {'name': 'maktab_backup_20260805.zip', 'date': 'Today, 09:30 PM', 'size': '2.4 MB'},
    {'name': 'maktab_backup_20260801.zip', 'date': '01 Aug 2026', 'size': '2.3 MB'},
    {'name': 'maktab_backup_20260715.zip', 'date': '15 Jul 2026', 'size': '2.1 MB'},
  ];

  Future<void> _createNewBackup() async {
    setState(() => _isLoading = true);
    final path = await _backupService.createBackup();
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created. Opening export options...'), backgroundColor: Color(0xFF004D40)),
      );
      try {
        await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Maktab Database Backup'));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing backup: $e'), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create backup'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _restoreFile() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!'), backgroundColor: Color(0xFF004D40)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore backup ZIP file.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: 'Backup & Disaster Recovery',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: _createNewBackup,
            tooltip: 'Create New Backup',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _createNewBackup,
                            icon: const Icon(Icons.backup_rounded),
                            label: const Text('Export Backup ZIP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004D40),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _restoreFile,
                            icon: const Icon(Icons.restore_page_rounded),
                            label: const Text('Restore File'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004D40),
                              side: const BorderSide(color: Color(0xFF004D40)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Available Local Backup Snapshots',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
                    const SizedBox(height: 12),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backups.length,
                      itemBuilder: (context, index) {
                        final b = _backups[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFF004D40),
                                child: Icon(Icons.folder_zip_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('${b['date']} · ${b['size']}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore, color: Color(0xFF004D40)),
                                onPressed: _restoreFile,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF004D40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.security_rounded, color: Color(0xFFFFD700), size: 40),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Encrypted SQLite Backups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Offline-first data protection & recovery', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
