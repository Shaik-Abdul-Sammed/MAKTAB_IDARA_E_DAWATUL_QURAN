import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _summary = 'Loading diagnostic summary...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final text = await CloudSyncService.instance.getDiagnosticSummary();
      if (mounted) {
        setState(() {
          _summary = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summary = 'Error generating diagnostics: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rerunProbe() async {
    setState(() => _isLoading = true);
    try {
      await CloudSyncService.instance.rerunProbe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Startup probe completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Probe error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await _loadSummary();
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostic summary copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Sync Diagnostics'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy to Clipboard',
            onPressed: _summary.isNotEmpty ? _copyToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadSummary,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF2D2D2D),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('Re-run Probe', style: TextStyle(fontSize: 12)),
                    onPressed: _isLoading ? null : _rerunProbe,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade800,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.content_copy, size: 18),
                  tooltip: 'Copy to Clipboard',
                  onPressed: _summary.isNotEmpty ? _copyToClipboard : null,
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _summary,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFE0E0E0),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
