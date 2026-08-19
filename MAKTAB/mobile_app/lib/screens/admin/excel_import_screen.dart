import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/services/excel_import_service.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> with SingleTickerProviderStateMixin {
  final ExcelImportService _importService = ExcelImportService();

  late TabController _tabController;
  String? _selectedFileName;
  List<Map<String, String>> _parsedRows = [];
  bool _isParsing = false;
  bool _isImporting = false;
  ExcelImportResult? _importResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        setState(() {
          _selectedFileName = name;
          _isParsing = true;
          _importResult = null;
        });

        final rows = await _importService.parseFileToRows(path);

        setState(() {
          _parsedRows = rows;
          _isParsing = false;
        });

        if (rows.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data found in selected file.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _runImport() async {
    if (_parsedRows.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final isStudentsTab = _tabController.index == 0;
      final result = isStudentsTab
          ? await _importService.importStudents(_parsedRows)
          : await _importService.importTeachers(_parsedRows);

      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${result.successCount} records successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Bulk Data Import',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldAccent,
          indicatorWeight: 3,
          labelColor: AppColors.goldAccent,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Students Import', icon: Icon(Icons.school_rounded, size: 20)),
            Tab(text: 'Teachers Import', icon: Icon(Icons.person_rounded, size: 20)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pick File Banner Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_rounded, color: AppColors.primaryTeal, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName ?? 'Select Excel or CSV File',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _parsedRows.isNotEmpty
                                  ? '${_parsedRows.length} rows loaded & ready'
                                  : 'Supports .xlsx and .csv spreadsheets',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _isParsing ? null : _pickFile,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Browse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Import Result Card (if done)
            if (_importResult != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _importResult!.errorCount == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _importResult!.errorCount == 0 ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _importResult!.errorCount == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: _importResult!.errorCount == 0 ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Import Complete: ${_importResult!.successCount} inserted, ${_importResult!.errorCount} failed.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _importResult!.errorCount == 0 ? Colors.green.shade800 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Preview Table Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'PARSED DATA PREVIEW',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  if (_parsedRows.isNotEmpty)
                    Text(
                      '${_parsedRows.length} Rows',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                    ),
                ],
              ),
            ),

            // Parsed Rows List
            Expanded(
              child: _isParsing
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
                  : _parsedRows.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.table_chart_outlined, size: 48, color: Colors.black26),
                              SizedBox(height: 12),
                              Text('No file loaded yet. Click Browse to select a file.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _parsedRows.length,
                          itemBuilder: (context, index) {
                            final row = _parsedRows[index];
                            final title = row['name'] ?? row['student_name'] ?? row['teacher_name'] ?? 'Row #${index + 1}';
                            final subtitle = row.entries
                                .where((e) => e.key != 'name' && e.key != 'student_name' && e.key != 'teacher_name')
                                .map((e) => '${e.key}: ${e.value}')
                                .take(3)
                                .join(' · ');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.12),
                                  child: Text('${index + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryTeal)),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            );
                          },
                        ),
            ),

            // Import Action Button Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldAccent,
                    foregroundColor: AppColors.primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: (_parsedRows.isEmpty || _isImporting) ? null : _runImport,
                  child: _isImporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: AppColors.primaryTeal, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Execute Bulk Import',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
