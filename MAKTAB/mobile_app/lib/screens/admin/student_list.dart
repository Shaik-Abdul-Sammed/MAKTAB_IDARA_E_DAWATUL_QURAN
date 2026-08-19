import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../providers/student_list_provider.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  late final StudentListProvider _provider;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  Timer? _debounce;
  List<Batch> _batches = [];

  @override
  void initState() {
    super.initState();
    _provider = StudentListProvider(StudentRepository());
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _provider.fetchStudents();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final list = await BatchRepository().getAllBatches();
      if (mounted) {
        setState(() => _batches = list);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _provider.updateSearchQuery(val);
    });
  }

  Future<void> _confirmDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Student',
        message:
            'Are you sure you want to delete student "${student.name}" (ADM: ${student.admissionNumber})?',
      ),
    );
    if (confirmed == true && student.id != null) {
      try {
        await _provider.deleteStudent(student.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${student.name}" removed from database.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete student. Retry?'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _confirmDelete(student),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: 'Students Roster',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.trending_up_rounded),
              tooltip: 'Bulk Promote Students',
              onPressed: () async {
                await context.push('/admin/students/promotion');
                _provider.fetchStudents();
              },
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Past / Deleted Students',
              onPressed: () async {
                await context.push('/admin/students/past');
                _provider.fetchStudents();
              },
            ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Analytics',
              onPressed: () => context.push('/admin/students/stats'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'student_add_fab',
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: const Color(0xFF004D40),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add Student', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () =>
              context.push('/admin/students/add').then((_) => _provider.fetchStudents()),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildBatchFilterRow(),
            _buildSummaryRow(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name, adm no, phone...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _provider.updateSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E8D5), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF004D40), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchFilterRow() {
    return Consumer<StudentListProvider>(
      builder: (context, p, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Batches'),
                selected: p.selectedBatchFilter == null,
                selectedColor: const Color(0xFF004D40),
                labelStyle: TextStyle(
                  color: p.selectedBatchFilter == null ? Colors.white : const Color(0xFF004D40),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) => p.setBatchFilter(null),
              ),
              const SizedBox(width: 8),
              ..._batches.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(b.name),
                      selected: p.selectedBatchFilter == b.id,
                      selectedColor: const Color(0xFF004D40),
                      labelStyle: TextStyle(
                        color: p.selectedBatchFilter == b.id ? Colors.white : const Color(0xFF004D40),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) => p.setBatchFilter(b.id),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow() {
    return Consumer<StudentListProvider>(
      builder: (_, p, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            _Chip(label: '${p.filteredStudents.length} Students', color: const Color(0xFF004D40)),
            const SizedBox(width: 8),
            _Chip(label: '${p.maleCount} Male', color: Colors.blue.shade700),
            const SizedBox(width: 8),
            _Chip(label: '${p.femaleCount} Female', color: Colors.pink.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<StudentListProvider>(
      builder: (context, p, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (p.status) {
            StudentListStatus.initial || StudentListStatus.loading =>
              const _ShimmerContent(key: ValueKey('shimmer')),
            StudentListStatus.error => _ErrorContent(
                key: const ValueKey('error'),
                message: p.errorMessage,
                onRetry: p.fetchStudents,
              ),
            StudentListStatus.success => p.filteredStudents.isEmpty
                ? _EmptyContent(
                    key: const ValueKey('empty'),
                    isFiltered: p.searchQuery.isNotEmpty || p.selectedBatchFilter != null,
                  )
                : _StudentListView(
                    key: const ValueKey('list'),
                    students: p.filteredStudents,
                    scrollController: _scrollController,
                    onDelete: _confirmDelete,
                    onRefresh: p.fetchStudents,
                  ),
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ShimmerContent extends StatelessWidget {
  const _ShimmerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: ShimmerListLoader(count: 7, height: 74),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorContent({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Color(0xFFB0BEC5)),
            const SizedBox(height: 16),
            const Text('Unable to load students',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final bool isFiltered;
  const _EmptyContent({super.key, required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFiltered ? Icons.search_off_rounded : Icons.school_outlined,
              size: 72, color: const Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No students match your filter.' : 'No students registered yet.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'Try clearing search or batch filter.' : 'Tap + Add Student to enroll your first student.',
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StudentListView extends StatelessWidget {
  final List<Student> students;
  final ScrollController scrollController;
  final Future<void> Function(Student) onDelete;
  final Future<void> Function() onRefresh;

  const _StudentListView({
    super.key,
    required this.students,
    required this.scrollController,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF004D40),
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Dismissible(
            key: ValueKey(student.id),
            background: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Delete', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                context.push('/admin/students/${student.id}/edit', extra: student);
                return false;
              } else {
                await onDelete(student);
                return false;
              }
            },
            child: _StudentTile(student: student),
          );
        },
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final initials = student.name.isNotEmpty
        ? student.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    final genderIcon = (student.gender ?? '').toLowerCase() == 'female'
        ? Icons.female_rounded
        : Icons.male_rounded;
    final genderColor = (student.gender ?? '').toLowerCase() == 'female'
        ? Colors.pink.shade400
        : Colors.blue.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Hero(
          tag: 'student_avatar_${student.id}',
          child: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF004D40),
            child: Text(initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
            ),
            Icon(genderIcon, size: 16, color: genderColor),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('ADM: ${student.admissionNumber} ${student.fatherName != null ? '· S/O ${student.fatherName}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: () => context.push('/admin/students/${student.id}'),
      ),
        ),
      ),
    );
  }
}
