import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/dtos/user_dto.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class TeacherStatsScreen extends StatefulWidget {
  const TeacherStatsScreen({super.key});

  @override
  State<TeacherStatsScreen> createState() => _TeacherStatsScreenState();
}

class _TeacherStatsScreenState extends State<TeacherStatsScreen> {
  late final _StatsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _StatsProvider(TeacherRepository());
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
        appBar: const CustomAppBar(title: 'Teacher Statistics'),
        body: Consumer<_StatsProvider>(
          builder: (_, p, _) {
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
                    const Text('Failed to load statistics.',
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
            return _StatsContent(provider: p);
          },
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final _StatsProvider provider;
  const _StatsContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          _buildSummaryBanner(p),
          const SizedBox(height: 20),

          // Stat cards row
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.group_outlined,
                label: 'Total Teachers',
                value: p.totalCount.toString(),
                color: const Color(0xFF004D40),
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Active',
                value: p.activeCount.toString(),
                color: Colors.green.shade700,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.cancel_outlined,
                label: 'Inactive',
                value: p.inactiveCount.toString(),
                color: Colors.orange.shade700,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: 'Active Rate',
                value: '${p.activeRate}%',
                color: Colors.blue.shade700,
              )),
            ],
          ),
          const SizedBox(height: 24),

          // Active/Inactive breakdown
          const _SectionTitle('Roster Breakdown'),
          const SizedBox(height: 12),
          _buildBreakdownBar(p),
          const SizedBox(height: 24),

          // Recently added
          if (p.recentTeachers.isNotEmpty) ...[
            const _SectionTitle('Recently Added'),
            const SizedBox(height: 12),
            ...p.recentTeachers.map((t) => _RecentTile(teacher: t)),
          ],
          const SizedBox(height: 24),

          // Mobile coverage
          const _SectionTitle('Mobile Coverage'),
          const SizedBox(height: 12),
          _buildProgressCard(
            label: 'Teachers with mobile on file',
            value: p.mobileCoverageRate,
            color: const Color(0xFF004D40),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(_StatsProvider p) {
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
          const Icon(Icons.school_outlined, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.totalCount} Teachers Registered',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${p.activeCount} active · ${p.inactiveCount} inactive',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownBar(_StatsProvider p) {
    final activeRatio = p.totalCount == 0 ? 0.0 : p.activeCount / p.totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active  ${p.activeCount}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13)),
              Text('Inactive  ${p.inactiveCount}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: activeRatio,
              minHeight: 14,
              backgroundColor: Colors.orange.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 10,
            backgroundColor: const Color(0xFFE0F2F1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$value%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)));
  }
}

class _RecentTile extends StatelessWidget {
  final UserDTO teacher;
  const _RecentTile({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'T';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF004D40),
            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(teacher.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text(
            teacher.mobile ?? '—',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

// ── Stats Provider (scoped to this screen) ──────────────────

class _StatsProvider extends ChangeNotifier {
  final TeacherRepository _repo;
  _StatsProvider(this._repo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  List<UserDTO> _all = [];

  int get totalCount => _all.length;
  int get activeCount => _all.where((t) => t.isActive).length;
  int get inactiveCount => _all.where((t) => !t.isActive).length;
  int get activeRate => totalCount == 0 ? 0 : (activeCount * 100 ~/ totalCount);
  int get mobileCoverageRate => totalCount == 0 ? 0 : (_all.where((t) => t.mobile != null && t.mobile!.isNotEmpty).length * 100 ~/ totalCount);

  List<UserDTO> get recentTeachers {
    final sorted = [..._all]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }

  Future<void> loadStats() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _all = await _repo.getAllTeachers();
    } catch (_) {
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }
}
