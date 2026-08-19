import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../domain/dtos/user_dto.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/teacher_repository.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class BatchScheduleScreen extends StatefulWidget {
  const BatchScheduleScreen({super.key});

  @override
  State<BatchScheduleScreen> createState() => _BatchScheduleScreenState();
}

class _BatchScheduleScreenState extends State<BatchScheduleScreen> {
  late final _ScheduleProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _ScheduleProvider(BatchRepository(), TeacherRepository(), StudentRepository());
    _provider.loadSchedule();
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
        appBar: const CustomAppBar(title: 'Master Batch Schedule'),
        body: Consumer<_ScheduleProvider>(
          builder: (context, p, _) {
            if (p.isLoading) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ShimmerLoader(height: 100),
                    const SizedBox(height: 16),
                    ShimmerLoader(height: 120),
                    const SizedBox(height: 16),
                    ShimmerLoader(height: 120),
                  ],
                ),
              );
            }
            if (p.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_outlined, size: 64, color: Color(0xFFB0BEC5)),
                    const SizedBox(height: 16),
                    const Text('Failed to load master schedule.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: p.loadSchedule,
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
            return _ScheduleContent(provider: p);
          },
        ),
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  final _ScheduleProvider provider;
  const _ScheduleContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(p),
          const SizedBox(height: 20),

          const Text('Classes & Timetable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          const SizedBox(height: 12),

          if (p.batches.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No batches created yet to schedule.', style: TextStyle(color: Colors.black45)),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: p.batches.length,
              itemBuilder: (context, index) {
                final b = p.batches[index];
                final teacher = p.teacherForBatch(b.teacherId);
                final studentCount = p.studentCountForBatch(b.id);
                return _ScheduleCard(batch: b, teacher: teacher, studentCount: studentCount);
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBanner(_ScheduleProvider p) {
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
          const Icon(Icons.access_time_filled_rounded, color: Color(0xFFFFD700), size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.batches.length} Active Batches Scheduled',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('${p.totalStudents} Students Enrolled across all Timings',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Batch batch;
  final UserDTO? teacher;
  final int studentCount;

  const _ScheduleCard({
    required this.batch,
    required this.teacher,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_outlined, color: Color(0xFF004D40), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF004D40))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(batch.timing, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black26),
                onPressed: () => context.push('/admin/batches/${batch.id}'),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF004D40)),
                  const SizedBox(width: 6),
                  Text(
                    teacher != null ? teacher!.name : 'Unassigned Teacher',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: teacher != null ? Colors.black87 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 16, color: Color(0xFF004D40)),
                  const SizedBox(width: 6),
                  Text('$studentCount Students', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleProvider extends ChangeNotifier {
  final BatchRepository _batchRepo;
  final TeacherRepository _teacherRepo;
  final StudentRepository _studentRepo;

  _ScheduleProvider(this._batchRepo, this._teacherRepo, this._studentRepo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  List<Batch> _batches = [];
  List<Batch> get batches => _batches;

  Map<int, UserDTO> _teachersMap = {};
  Map<int, int> _studentCountsMap = {};

  int get totalStudents => _studentCountsMap.values.fold(0, (sum, count) => sum + count);

  UserDTO? teacherForBatch(int? teacherId) {
    if (teacherId == null) return null;
    return _teachersMap[teacherId];
  }

  int studentCountForBatch(int? batchId) {
    if (batchId == null) return 0;
    return _studentCountsMap[batchId] ?? 0;
  }

  Future<void> loadSchedule() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
    try {
      _batches = await _batchRepo.getAllBatches();
      final teachers = await _teacherRepo.getAllTeachers();
      _teachersMap = {for (var t in teachers) if (t.id != null) t.id!: t};

      final allStudents = await _studentRepo.getAllStudents();
      final Map<int, int> counts = {};
      for (var s in allStudents) {
        if (s.batchId != null) {
          counts[s.batchId!] = (counts[s.batchId!] ?? 0) + 1;
        }
      }
      _studentCountsMap = counts;
    } catch (_) {
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }
}
