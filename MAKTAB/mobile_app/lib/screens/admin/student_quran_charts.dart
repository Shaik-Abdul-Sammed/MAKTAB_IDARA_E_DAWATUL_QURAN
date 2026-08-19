import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class StudentQuranChartsScreen extends StatefulWidget {
  const StudentQuranChartsScreen({super.key});

  @override
  State<StudentQuranChartsScreen> createState() => _StudentQuranChartsScreenState();
}

class _StudentQuranChartsScreenState extends State<StudentQuranChartsScreen> {
  late final _StudentStatsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _StudentStatsProvider(StudentRepository(), BatchRepository());
    _provider.loadStats();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: const CustomAppBar(title: 'Student Analytics & Demographics'),
        body: Consumer<_StudentStatsProvider>(
          builder: (context, p, _) {
            if (p.isLoading) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ShimmerLoader(height: 110),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: ShimmerLoader(height: 100)),
                      const SizedBox(width: 12),
                      Expanded(child: ShimmerLoader(height: 100)),
                    ]),
                    const SizedBox(height: 16),
                    ShimmerLoader(height: 200),
                  ],
                ),
              );
            }
            if (p.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart_outlined, size: 64, color: Color(0xFFB0BEC5)),
                    const SizedBox(height: 16),
                    const Text('Failed to load student statistics.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: p.loadStats,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _StudentStatsContent(provider: p);
          },
        ),
      ),
    );
  }
}

class _StudentStatsContent extends StatelessWidget {
  final _StudentStatsProvider provider;
  const _StudentStatsContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryBanner(p),
          const SizedBox(height: 20),

          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.school_outlined,
                  label: 'Total Enrolled',
                  value: p.totalCount.toString(),
                  color: const Color(0xFF004D40),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.male_rounded,
                  label: 'Male Students',
                  value: p.maleCount.toString(),
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.female_rounded,
                  label: 'Female Students',
                  value: p.femaleCount.toString(),
                  color: Colors.pink.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.phone_android_rounded,
                  label: 'Parent Contact %',
                  value: '${p.phoneCoverageRate}%',
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gender Ratio Bar
          const _SectionTitle('Gender Ratio'),
          const SizedBox(height: 12),
          _buildGenderBar(p),
          const SizedBox(height: 24),

          // Batch Breakdown
          if (p.batchStats.isNotEmpty) ...[
            const _SectionTitle('Batch Breakdown'),
            const SizedBox(height: 12),
            ...p.batchStats.map((bs) => _BatchProgressCard(
                  batchName: bs.batchName,
                  count: bs.count,
                  percentage: p.totalCount == 0 ? 0.0 : bs.count / p.totalCount,
                )),
          ],
          const SizedBox(height: 24),

          // Recent Enrollments
          if (p.recentStudents.isNotEmpty) ...[
            const _SectionTitle('Recent Admissions'),
            const SizedBox(height: 12),
            ...p.recentStudents.map((s) => _RecentStudentTile(student: s)),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(_StudentStatsProvider p) {
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
          const Icon(Icons.pie_chart_outline_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.totalCount} Enrolled Students',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${p.maleCount} Male · ${p.femaleCount} Female across ${p.batchStats.length} Batches',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderBar(_StudentStatsProvider p) {
    final maleRatio = p.totalCount == 0 ? 0.5 : p.maleCount / p.totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Male: ${p.maleCount}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 13)),
              Text('Female: ${p.femaleCount}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink.shade700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: maleRatio,
              minHeight: 14,
              backgroundColor: Colors.pink.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _BatchProgressCard extends StatelessWidget {
  final String batchName;
  final int count;
  final double percentage;

  const _BatchProgressCard({required this.batchName, required this.count, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
              Text('$count Students (${(percentage * 100).toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: const Color(0xFFF9FBE7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _RecentStudentTile extends StatelessWidget {
  final Student student;
  const _RecentStudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final initials = student.name.isNotEmpty
        ? student.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF004D40),
            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text('ADM: ${student.admissionNumber}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)));
  }
}

class _BatchStat {
  final String batchName;
  final int count;
  _BatchStat({required this.batchName, required this.count});
}

class _StudentStatsProvider extends ChangeNotifier {
  final StudentRepository _studentRepo;
  final BatchRepository _batchRepo;
  _StudentStatsProvider(this._studentRepo, this._batchRepo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  List<Student> _allStudents = [];
  List<Batch> _allBatches = [];

  int get totalCount => _allStudents.length;
  int get maleCount => _allStudents.where((s) => (s.gender ?? '').toLowerCase() == 'male').length;
  int get femaleCount => _allStudents.where((s) => (s.gender ?? '').toLowerCase() == 'female').length;
  int get phoneCoverageRate =>
      totalCount == 0 ? 0 : (_allStudents.where((s) => s.phone != null && s.phone!.isNotEmpty).length * 100 ~/ totalCount);

  List<_BatchStat> get batchStats {
    final Map<int?, int> counts = {};
    for (var s in _allStudents) {
      counts[s.batchId] = (counts[s.batchId] ?? 0) + 1;
    }
    final List<_BatchStat> list = [];
    counts.forEach((batchId, count) {
      String name = 'Unassigned';
      if (batchId != null) {
        final found = _allBatches.firstWhere((b) => b.id == batchId, orElse: () => Batch(name: 'Batch #$batchId', timing: 'N/A'));
        name = found.name;
      }
      list.add(_BatchStat(batchName: name, count: count));
    });
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  List<Student> get recentStudents {
    final sorted = [..._allStudents]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  Future<void> loadStats() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _allStudents = await _studentRepo.getAllStudents();
      _allBatches = await _batchRepo.getAllBatches();
    } catch (_) {
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }
}
