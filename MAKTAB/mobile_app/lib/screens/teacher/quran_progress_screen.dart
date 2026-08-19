import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/batch.dart';
import '../../models/student.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class QuranProgressScreen extends StatefulWidget {
  const QuranProgressScreen({super.key});

  @override
  State<QuranProgressScreen> createState() => _QuranProgressScreenState();
}

class _QuranProgressScreenState extends State<QuranProgressScreen> {
  List<Batch> _batches = [];
  int? _selectedBatchId;
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final batches = await BatchRepository().getAllBatches();
      _batches = batches;
      if (batches.isNotEmpty) {
        _selectedBatchId = batches.first.id;
        _students = await StudentRepository().getStudentsByBatch(_selectedBatchId!);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Daily Quran Recitation Progress'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(),
              const SizedBox(height: 20),

              const Text('Select Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
              const SizedBox(height: 10),
              _buildBatchChips(),
              const SizedBox(height: 24),

              const Text('Students Recitation Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40))),
              const SizedBox(height: 12),

              if (_isLoading) ...[
                ShimmerLoader(height: 80),
                const SizedBox(height: 12),
                ShimmerLoader(height: 80),
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
                    return _StudentRecitationTile(student: student);
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
      child: const Row(
        children: [
          Icon(Icons.menu_book_rounded, color: Color(0xFFFFD700), size: 40),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quran Progress Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 4),
              Text('Record Sabaq, Sabaqi, and Manzil daily', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchChips() {
    if (_batches.isEmpty) return const SizedBox.shrink();
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
  const _StudentRecitationTile({required this.student});

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: const Color(0xFF004D40),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('ADM: ${student.admissionNumber}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            trailing: ElevatedButton.icon(
              onPressed: () {
                context.push('/teacher/quran_progress/entry?studentId=${student.id}&studentName=${Uri.encodeComponent(student.name)}');
              },
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Log Sabaq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
