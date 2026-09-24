import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/batch.dart';
import '../../models/student.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/quran_progress_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';
import '../../l10n/app_localizations.dart';

class QuranProgressScreen extends StatefulWidget {
  const QuranProgressScreen({super.key});

  @override
  State<QuranProgressScreen> createState() => _QuranProgressScreenState();
}

class _QuranProgressScreenState extends State<QuranProgressScreen> {
  List<Batch> _batches = [];
  int? _selectedBatchId;
  List<Student> _students = [];
  Map<int, Map<String, dynamic>> _latestProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _fetchBatchProgress(int batchId) async {
    try {
      final progressList = await QuranProgressRepository().getLatestProgressForBatch(batchId);
      final map = <int, Map<String, dynamic>>{};
      for (final p in progressList) {
        final sid = p['student_id'] as int?;
        if (sid != null) {
          map[sid] = p;
        }
      }
      if (mounted) {
        setState(() {
          _latestProgress = map;
        });
      }
    } catch (e) {
      debugPrint('[QURAN_PROGRESS] fetchBatchProgress error: $e');
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;
      final canonicalTeacherId = user?.teacherId ?? user?.id;
      final List<Batch> batches;
      if (user?.role == 'teacher' && canonicalTeacherId != null) {
        batches = await BatchRepository().fetchTeacherBatches(canonicalTeacherId);
      } else {
        batches = await BatchRepository().getAllBatches();
      }
      _batches = batches;
      if (batches.isNotEmpty) {
        _selectedBatchId = batches.first.id;
        _students = await StudentRepository().getStudentsByBatch(_selectedBatchId!);
        await _fetchBatchProgress(_selectedBatchId!);
      } else {
        _selectedBatchId = null;
        _students = [];
        _latestProgress = {};
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e, st) {
      debugPrint('[QURAN_PROGRESS] load error: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load progress: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _onBatchSelected(int? batchId) async {
    if (batchId == null) return;
    setState(() {
      _selectedBatchId = batchId;
      _isLoading = true;
    });
    try {
      final list = await StudentRepository().getStudentsByBatch(batchId);
      await _fetchBatchProgress(batchId);
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[QURAN_PROGRESS] load error: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load progress: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: CustomAppBar(
        title: loc?.translate('quran_progress') ?? 'Daily Sabaq Progress',
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: loc?.translate('view_history') ?? 'Sabaq History',
            onPressed: () => context.push('/teacher/quran_progress/history'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: loc?.translate('summary_report') ?? 'Sabaq Summary',
            onPressed: () => context.push('/teacher/quran_progress/summary'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(),
              const SizedBox(height: 20),

              Text(loc?.translate('select_batch') ?? 'Select Batch', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
              const SizedBox(height: 10),
              _buildBatchChips(),
              const SizedBox(height: 24),

              Text(loc?.translate('students') ?? 'Students Recitation Roster', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
              const SizedBox(height: 12),

              if (_isLoading) ...[
                ShimmerLoader(height: 80),
                const SizedBox(height: 12),
                ShimmerLoader(height: 80),
              ] else if (_batches.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No batches assigned.', style: TextStyle(color: Colors.black45)),
                  ),
                ),
              ] else if (_students.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No students in this batch.', style: TextStyle(color: Colors.black45)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return _StudentRecitationTile(
                      student: student,
                      latestProgress: _latestProgress[student.id],
                      onProgressLogged: () {
                        if (_selectedBatchId != null) {
                          _fetchBatchProgress(_selectedBatchId!);
                        }
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: Color(0xFFFFD700), size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc?.translate('quran_progress') ?? 'Sabaq Tracker', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, overflow: TextOverflow.ellipsis)),
              const SizedBox(height: 4),
              Text(loc?.translate('recitation_type') ?? 'Record Sabaq, Sabaqi, and Manzil daily', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchChips() {
    if (_batches.isEmpty) {
      return const Text('No batches assigned.', style: TextStyle(color: Colors.black45, fontSize: 13));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _batches.map((b) {
          final isSelected = _selectedBatchId == b.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(b.name),
              selected: isSelected,
              selectedColor: const Color(0xFF004D40),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF004D40),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              onSelected: (_) => _onBatchSelected(b.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StudentRecitationTile extends StatelessWidget {
  final Student student;
  final Map<String, dynamic>? latestProgress;
  final VoidCallback onProgressLogged;

  const _StudentRecitationTile({
    required this.student,
    this.latestProgress,
    required this.onProgressLogged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final p = latestProgress;
    final hasProgress = p != null && p['surah'] != null && p['surah'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADM: ${student.admissionNumber}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  const SizedBox(height: 3),
                  if (hasProgress) ...[
                    Text(
                      '${loc?.translate('surah') ?? 'Surah'} ${p['surah']} · ${loc?.translate('ayat') ?? 'Ayah'} ${p['ayah_from']}–${p['ayah_to']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loc?.translate('date_time') ?? 'Date'}: ${p['date']} · ${p['grade']}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ] else ...[
                    Text(
                      loc?.translate('no_progress_recorded') ?? 'Not started yet',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            isThreeLine: true,
            trailing: ElevatedButton.icon(
              onPressed: () async {
                final res = await context.push(
                  '/teacher/quran_progress/entry?studentId=${student.id}&studentName=${Uri.encodeComponent(student.name)}',
                );
                if (res == true) {
                  onProgressLogged();
                }
              },
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: Text(
                '${loc?.translate('save') ?? 'Log'} ${loc?.translate('sabaq') ?? 'Sabaq'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF004D40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
