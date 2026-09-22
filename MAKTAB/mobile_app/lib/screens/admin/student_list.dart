import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/config/app_colors.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../providers/auth_provider.dart';
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
  bool _isTeacher = false;
  int? _teacherId;

  bool _showUnassigned = false;
  List<Student> _unassignedStudents = [];
  bool _loadingUnassigned = false;

  @override
  void initState() {
    super.initState();
    _provider = StudentListProvider(StudentRepository());
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _provider.fetchStudents();
    _loadBatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final isTeacher = user?.role == 'teacher';
    if (_isTeacher != isTeacher || _teacherId != user?.id) {
      _isTeacher = isTeacher;
      _teacherId = user?.id;
      _loadBatches();
    }
  }

  Future<void> _loadBatches() async {
    try {
      List<Batch> list;
      if (_isTeacher && _teacherId != null) {
        list = await BatchRepository().fetchTeacherBatches(_teacherId!);
      } else {
        list = await BatchRepository().getAllBatches();
      }
      if (mounted) {
        setState(() => _batches = list);
      }
    } catch (_) {}
  }

  Future<void> _loadUnassignedStudents() async {
    setState(() {
      _showUnassigned = true;
      _loadingUnassigned = true;
    });
    try {
      final list = await StudentRepository().getUnassignedStudents();
      if (mounted) {
        setState(() {
          _unassignedStudents = list;
          _loadingUnassigned = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUnassigned = false);
    }
  }

  List<Student> get _filteredUnassignedStudents {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _unassignedStudents;
    return _unassignedStudents.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.admissionNumber.toLowerCase().contains(q) ||
          (s.fatherName ?? '').toLowerCase().contains(q) ||
          (s.phone ?? '').contains(q);
    }).toList();
  }

  Future<void> _showReassignSheet(Student student) async {
    int? selectedBatchId = _batches.isNotEmpty ? _batches.first.id : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Batch for ${student.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ADM: ${student.admissionNumber}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: selectedBatchId,
                    decoration: InputDecoration(
                      labelText: 'Select Batch',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.class_outlined, color: Color(0xFF004D40)),
                    ),
                    items: _batches.map((b) {
                      return DropdownMenuItem<int>(
                        value: b.id,
                        child: Text(b.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedBatchId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: selectedBatchId == null
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await StudentRepository().updateStudent(
                                student.copyWith(batchId: selectedBatchId),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Assigned "${student.name}" to batch.'),
                                    backgroundColor: const Color(0xFF004D40),
                                  ),
                                );
                                _loadUnassignedStudents();
                                _provider.fetchStudents();
                              }
                            },
                      child: const Text('Assign to Batch', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Student> _getScopedStudents(List<Student> students) {
    if (!_isTeacher) return students;
    if (_batches.isEmpty) return const [];
    final teacherBatchIds = _batches.map((b) => b.id).toSet();
    return students.where((s) => teacherBatchIds.contains(s.batchId)).toList();
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
    if (_showUnassigned) {
      setState(() {});
    }
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
    if (_isTeacher && _batches.isEmpty) return const SizedBox.shrink();
    return Consumer<StudentListProvider>(
      builder: (context, p, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Batches'),
                selected: !_showUnassigned && p.selectedBatchFilter == null,
                selectedColor: const Color(0xFF004D40),
                labelStyle: TextStyle(
                  color: (!_showUnassigned && p.selectedBatchFilter == null) ? Colors.white : const Color(0xFF004D40),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() => _showUnassigned = false);
                  p.setBatchFilter(null);
                },
              ),
              if (!_isTeacher) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Unassigned'),
                  selected: _showUnassigned,
                  selectedColor: const Color(0xFF004D40),
                  labelStyle: TextStyle(
                    color: _showUnassigned ? Colors.white : const Color(0xFF004D40),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => _loadUnassignedStudents(),
                ),
              ],
              const SizedBox(width: 8),
              ..._batches.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(b.name),
                      selected: !_showUnassigned && p.selectedBatchFilter == b.id,
                      selectedColor: const Color(0xFF004D40),
                      labelStyle: TextStyle(
                        color: (!_showUnassigned && p.selectedBatchFilter == b.id) ? Colors.white : const Color(0xFF004D40),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => _showUnassigned = false);
                        p.setBatchFilter(b.id);
                      },
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow() {
    if (_isTeacher && _batches.isEmpty) return const SizedBox.shrink();
    if (_showUnassigned) {
      final scoped = _filteredUnassignedStudents;
      final maleCount = scoped.where((s) => (s.gender ?? '').toLowerCase() == 'male').length;
      final femaleCount = scoped.where((s) => (s.gender ?? '').toLowerCase() == 'female').length;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            _Chip(label: '${scoped.length} Unassigned', color: const Color(0xFF004D40)),
            const SizedBox(width: 8),
            _Chip(label: '$maleCount Male', color: Colors.blue.shade700),
            const SizedBox(width: 8),
            _Chip(label: '$femaleCount Female', color: Colors.pink.shade700),
          ],
        ),
      );
    }
    return Consumer<StudentListProvider>(
      builder: (_, p, _) {
        final scoped = _getScopedStudents(p.filteredStudents);
        final maleCount = scoped.where((s) => (s.gender ?? '').toLowerCase() == 'male').length;
        final femaleCount = scoped.where((s) => (s.gender ?? '').toLowerCase() == 'female').length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _Chip(label: '${scoped.length} Students', color: const Color(0xFF004D40)),
              const SizedBox(width: 8),
              _Chip(label: '$maleCount Male', color: Colors.blue.shade700),
              const SizedBox(width: 8),
              _Chip(label: '$femaleCount Female', color: Colors.pink.shade700),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_showUnassigned) {
      if (_loadingUnassigned) {
        return const _ShimmerContent(key: ValueKey('shimmer_unassigned'));
      }
      final scoped = _filteredUnassignedStudents;
      if (scoped.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 72, color: Color(0xFFB0BEC5)),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No unassigned students match your filter.'
                    : 'All students are assigned to batches.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
            ],
          ),
        );
      }
      return _StudentListView(
        key: const ValueKey('unassigned_list'),
        students: scoped,
        batches: _batches,
        scrollController: _scrollController,
        onDelete: (s) async {
          await _confirmDelete(s);
          await _loadUnassignedStudents();
        },
        onRefresh: _loadUnassignedStudents,
        onReassign: _showReassignSheet,
      );
    }
    return Consumer<StudentListProvider>(
      builder: (context, p, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            final seenKeys = <Key?>{};
            if (currentChild?.key != null) seenKeys.add(currentChild!.key);
            final dedupedPrevious = <Widget>[];
            for (final child in previousChildren.reversed) {
              if (child.key == null || seenKeys.add(child.key)) {
                dedupedPrevious.add(child);
              }
            }
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...dedupedPrevious.reversed,
                ?currentChild,
              ],
            );
          },
          child: switch (p.status) {
            StudentListStatus.initial || StudentListStatus.loading =>
              const _ShimmerContent(key: ValueKey('shimmer')),
            StudentListStatus.error => _ErrorContent(
                key: const ValueKey('error'),
                message: p.errorMessage,
                onRetry: p.fetchStudents,
              ),
            StudentListStatus.success => () {
                final scoped = _getScopedStudents(p.filteredStudents);
                if (scoped.isEmpty) {
                  return _EmptyContent(
                    key: const ValueKey('empty'),
                    isFiltered: p.searchQuery.isNotEmpty || p.selectedBatchFilter != null,
                    noBatches: _isTeacher && _batches.isEmpty,
                  );
                }
                return _StudentListView(
                  key: const ValueKey('list'),
                  students: scoped,
                  batches: _batches,
                  scrollController: _scrollController,
                  onDelete: _confirmDelete,
                  onRefresh: p.fetchStudents,
                );
              }(),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
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
  final bool noBatches;
  const _EmptyContent({
    super.key,
    required this.isFiltered,
    this.noBatches = false,
  });

  @override
  Widget build(BuildContext context) {
    if (noBatches) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 72, color: Color(0xFFB0BEC5)),
            SizedBox(height: 16),
            Text(
              'No batches assigned yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
            ),
            SizedBox(height: 8),
            Text(
              'Contact Admin to assign your batches.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      );
    }
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
  final List<Batch> batches;
  final ScrollController scrollController;
  final Future<void> Function(Student) onDelete;
  final Future<void> Function() onRefresh;
  final void Function(Student)? onReassign;

  const _StudentListView({
    super.key,
    required this.students,
    required this.batches,
    required this.scrollController,
    required this.onDelete,
    required this.onRefresh,
    this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    final batchMap = {for (final b in batches) b.id: b.name};
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
                color: onReassign != null ? const Color(0xFF004D40) : AppColors.primaryTeal,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  Icon(onReassign != null ? Icons.assignment_ind_rounded : Icons.edit_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(onReassign != null ? 'Assign' : 'Edit', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
                if (onReassign != null) {
                  onReassign!(student);
                } else {
                  context.push('/admin/students/${student.id}/edit', extra: student);
                }
                return false;
              } else {
                await onDelete(student);
                return false;
              }
            },
            child: _StudentTile(
              student: student,
              batchName: batchMap[student.batchId],
              onLongPress: onReassign != null ? () => onReassign!(student) : null,
            ),
          );
        },
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final String? batchName;
  final VoidCallback? onLongPress;
  const _StudentTile({required this.student, this.batchName, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final initials = student.name.isNotEmpty
        ? student.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    final hasPhoto = student.photoPath != null &&
        student.photoPath!.isNotEmpty &&
        File(student.photoPath!).existsSync();

    final isSynced = student.isSynced ?? true;

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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Hero(
              tag: 'student_avatar_${student.id}',
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryTeal,
                backgroundImage: hasPhoto ? FileImage(File(student.photoPath!)) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(genderIcon, size: 16, color: genderColor),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'ADM: ${student.admissionNumber} ${student.fatherName != null ? '· S/O ${student.fatherName}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (batchName != null && batchName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      batchName!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF004D40),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: isSynced ? 'Synced with cloud' : 'Pending cloud sync',
                  child: Icon(
                    isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 18,
                    color: isSynced ? Colors.green.shade600 : Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
            onTap: () => context.push('/admin/students/${student.id}'),
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}

extension _StudentSyncExt on Student {
  bool? get isSynced => null;
}
