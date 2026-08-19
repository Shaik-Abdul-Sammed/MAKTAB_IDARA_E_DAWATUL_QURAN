import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/dtos/user_dto.dart';
import '../../providers/teacher_list_provider.dart';
import '../../repositories/teacher_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class TeacherListScreen extends StatefulWidget {
  const TeacherListScreen({super.key});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  late final TeacherListProvider _provider;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _provider = TeacherListProvider(TeacherRepository());
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _provider.fetchTeachers();
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

  Future<void> _confirmDelete(UserDTO teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Teacher',
        message:
            'Are you sure you want to permanently remove "${teacher.name}"? This action cannot be undone.',
      ),
    );
    if (confirmed == true && teacher.id != null) {
      try {
        await _provider.deleteTeacher(teacher.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${teacher.name}" has been removed.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete. Please retry.'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _confirmDelete(teacher),
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
          title: 'Teachers',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Stats',
              onPressed: () => context.push('/admin/teachers/stats'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'teacher_add_fab',
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: const Color(0xFF004D40),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Teacher', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () =>
              context.push('/admin/teachers/add').then((_) => _provider.fetchTeachers()),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
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
          hintText: 'Search by name or mobile...',
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

  Widget _buildSummaryRow() {
    return Consumer<TeacherListProvider>(
      builder: (_, p, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            _Chip(label: '${p.totalCount} Total', color: const Color(0xFF004D40)),
            const SizedBox(width: 8),
            _Chip(label: '${p.activeCount} Active', color: Colors.green.shade700),
            const SizedBox(width: 8),
            _Chip(label: '${p.inactiveCount} Inactive', color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<TeacherListProvider>(
      builder: (context, p, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (p.status) {
            TeacherListStatus.initial || TeacherListStatus.loading =>
              const _ShimmerContent(key: ValueKey('shimmer')),
            TeacherListStatus.error => _ErrorContent(
                key: const ValueKey('error'),
                message: p.errorMessage,
                onRetry: p.fetchTeachers,
              ),
            TeacherListStatus.success => p.filteredTeachers.isEmpty
                ? _EmptyContent(
                    key: const ValueKey('empty'),
                    isFiltered: p.searchQuery.isNotEmpty,
                  )
                : _TeacherListView(
                    key: const ValueKey('list'),
                    teachers: p.filteredTeachers,
                    scrollController: _scrollController,
                    onDelete: _confirmDelete,
                    onRefresh: p.fetchTeachers,
                  ),
          },
        );
      },
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ShimmerListLoader(count: 7, height: 72),
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
            const Text('Unable to load teachers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
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
          Icon(isFiltered ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 72, color: const Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No teachers match your search.' : 'No teachers added yet.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'Try a different name or mobile.' : 'Tap the + button to add your first teacher.',
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TeacherListView extends StatelessWidget {
  final List<UserDTO> teachers;
  final ScrollController scrollController;
  final Future<void> Function(UserDTO) onDelete;
  final Future<void> Function() onRefresh;

  const _TeacherListView({
    super.key,
    required this.teachers,
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
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return Dismissible(
            key: ValueKey(teacher.id),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF004D40),
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
              margin: const EdgeInsets.only(bottom: 12),
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
                context.push('/admin/teachers/${teacher.id}/edit', extra: teacher);
                return false;
              } else {
                await onDelete(teacher);
                return false;
              }
            },
            child: _TeacherTile(teacher: teacher),
          );
        },
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final UserDTO teacher;
  const _TeacherTile({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'T';

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
          tag: 'teacher_avatar_${teacher.id}',
          child: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF004D40),
            child: Text(initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        title: Text(teacher.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 13, color: Colors.black38),
                const SizedBox(width: 4),
                Text(teacher.mobile ?? 'No mobile', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: teacher.isActive
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: teacher.isActive ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                teacher.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: teacher.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
        onTap: () => context.push('/admin/teachers/${teacher.id}'),
          ),
        ),
      ),
    );
  }
}
