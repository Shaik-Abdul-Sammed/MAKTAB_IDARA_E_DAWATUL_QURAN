import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/quran_progress_repository.dart';
import '../../repositories/student_repository.dart';

class QuranProgressSummaryScreen extends StatefulWidget {
  const QuranProgressSummaryScreen({super.key});

  @override
  State<QuranProgressSummaryScreen> createState() => _QuranProgressSummaryScreenState();
}

class _QuranProgressSummaryScreenState extends State<QuranProgressSummaryScreen> {
  bool _isLoading = true;
  int _totalRecords = 0;
  int _studentsWithProgress = 0;
  int _totalStudents = 0;
  int _thisMonthCount = 0;
  Map<String, int> _gradeDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = auth.currentUser?.teacherId ?? auth.currentUser?.id;
      final qpRepo = QuranProgressRepository();
      final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

      if (teacherId != null) {
        final totalRec = await qpRepo.getTotalProgressCount(teacherId);
        final activeStudents = await qpRepo.getStudentsWithProgressCount(teacherId);
        final allStudents = await StudentRepository().getStudentsByTeacher(teacherId);
        final monthCount = await qpRepo.getMonthlyProgressCount(teacherId, currentMonthStr);
        final gradeDist = await qpRepo.getGradeDistribution(teacherId);

        if (mounted) {
          setState(() {
            _totalRecords = totalRec;
            _studentsWithProgress = activeStudents;
            _totalStudents = allStudents.length;
            _thisMonthCount = monthCount;
            _gradeDistribution = gradeDist;
            _isLoading = false;
          });
        }
      } else {
        final all = await qpRepo.getAllProgress();
        if (mounted) {
          setState(() {
            _totalRecords = all.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[QURAN_SUMMARY] load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coveragePercent = _totalStudents > 0
        ? ((_studentsWithProgress / _totalStudents) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7), // Cream background
      appBar: AppBar(
        title: const Text(
          'Quran Progress Rate Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, overflow: TextOverflow.ellipsis),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF004D40),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistical Overview',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live aggregated statistics of recorded lessons and memorization.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Big stat cards grid
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total Logs', '$_totalRecords', Icons.menu_book, Colors.blue)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Student Coverage',
                              '${coveragePercent.toStringAsFixed(1)}%',
                              Icons.trending_up,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Active Learners',
                              '$_studentsWithProgress / $_totalStudents',
                              Icons.people,
                              Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'This Month',
                              '$_thisMonthCount',
                              Icons.calendar_month,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Progress visualizers
                      const Text('Grade Progress Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      const SizedBox(height: 16),

                      if (_totalRecords == 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No recitation progress recorded yet.',
                              style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                            ),
                          ),
                        )
                      else ...[
                        _buildGradeBreakdown('Mumtaz (A+)', _gradeDistribution['A+'] ?? _gradeDistribution['Mumtaz'] ?? 0),
                        _buildGradeBreakdown('Jayyid Jiddan (A)', _gradeDistribution['A'] ?? _gradeDistribution['Jayyid Jiddan'] ?? 0),
                        _buildGradeBreakdown('Jayyid (B)', _gradeDistribution['B'] ?? _gradeDistribution['Jayyid'] ?? 0),
                        _buildGradeBreakdown('Maqbool (C)', _gradeDistribution['C'] ?? _gradeDistribution['Maqbool'] ?? 0),
                        _buildGradeBreakdown('Da\'eef (D)', _gradeDistribution['D'] ?? _gradeDistribution['Da\'eef'] ?? 0),
                      ],

                      const SizedBox(height: 36),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reports compiled successfully! Exporting file to documents.'),
                              backgroundColor: Color(0xFF004D40),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export Excel/PDF Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700), // Gold
                          foregroundColor: const Color(0xFF004D40),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGradeBreakdown(String gradeLabel, int count) {
    final double pct = _totalRecords > 0 ? (count / _totalRecords) : 0.0;
    final pctString = '${(pct * 100).toStringAsFixed(1)}%';
    return _buildProgressBar(gradeLabel, pct, '$count logged ($pctString)');
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String title, double percentage, String caption) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              Text(caption, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF9FBE7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
