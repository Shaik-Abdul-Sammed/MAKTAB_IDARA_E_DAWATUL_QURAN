import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../providers/batch_list_provider.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class BatchListScreen extends StatefulWidget {
  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  late final BatchListProvider _provider;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _provider = BatchListProvider(BatchRepository());
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _provider.fetchBatches();
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

  Future<void> _confirmDelete(Batch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Batch',
        message: 'Are you sure you want to delete batch "${batch.name}" (${batch.timing})?',
      ),
    );
    if (confirmed == true && batch.id != null) {
      try {
        await _provider.deleteBatch(batch.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch "${batch.name}" deleted.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete batch. Please retry.'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _confirmDelete(batch),
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
          title: 'Batches & Classes',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.schedule_rounded),
              tooltip: 'Schedule Overview',
              onPressed: () => context.push('/admin/batches/schedule'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'batch_add_fab',
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: const Color(0xFF004D40),
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Add Batch', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () =>
              context.push('/admin/batches/add').then((_) => _provider.fetchBatches()),
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
          hintText: 'Search batch name or timing...',
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
    return Consumer<BatchListProvider>(
      builder: (_, p, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            _Chip(label: '${p.totalCount} Batches', color: const Color(0xFF004D40)),
            const SizedBox(width: 8),
            _Chip(label: '${p.assignedCount} Assigned', color: Colors.green.shade700),
            const SizedBox(width: 8),
            _Chip(label: '${p.unassignedCount} Unassigned', color: Colors.orange.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<BatchListProvider>(
      builder: (context, p, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (p.status) {
            BatchListStatus.initial || BatchListStatus.loading =>
              const _ShimmerContent(key: ValueKey('shimmer')),
            BatchListStatus.error => _ErrorContent(
                key: const ValueKey('error'),
                message: p.errorMessage,
                onRetry: p.fetchBatches,
              ),
            BatchListStatus.success => p.filteredBatches.isEmpty
                ? _EmptyContent(
                    key: const ValueKey('empty'),
                    isFiltered: p.searchQuery.isNotEmpty,
                  )
                : _BatchListView(
                    key: const ValueKey('list'),
                    batches: p.filteredBatches,
                    scrollController: _scrollController,
                    onDelete: _confirmDelete,
                    onRefresh: p.fetchBatches,
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
      child: ShimmerListLoader(count: 6, height: 80),
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
            const Text('Unable to load batches',
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
          Icon(isFiltered ? Icons.search_off_rounded : Icons.class_outlined,
              size: 72, color: const Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No batches match your search.' : 'No batches created yet.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? 'Try searching another name or time.' : 'Tap + Add Batch to create your first class batch.',
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BatchListView extends StatelessWidget {
  final List<Batch> batches;
  final ScrollController scrollController;
  final Future<void> Function(Batch) onDelete;
  final Future<void> Function() onRefresh;

  const _BatchListView({
    super.key,
    required this.batches,
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
        itemCount: batches.length,
        itemBuilder: (context, index) {
          final batch = batches[index];
          return Dismissible(
            key: ValueKey(batch.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                  SizedBox(height: 4),
                  Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            confirmDismiss: (_) async {
              await onDelete(batch);
              return false;
            },
            child: _BatchTile(batch: batch),
          );
        },
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final Batch batch;
  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final initials = batch.name.isNotEmpty
        ? batch.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'B';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          tag: 'batch_avatar_${batch.id}',
          child: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF004D40),
            child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        title: Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF004D40)),
                const SizedBox(width: 4),
                Text(batch.timing, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                color: batch.teacherId != null ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: batch.teacherId != null ? Colors.green.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Text(
                batch.teacherId != null ? 'Assigned' : 'Unassigned',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: batch.teacherId != null ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
        onTap: () => context.push('/admin/batches/${batch.id}'),
          ),
        ),
      ),
    );
  }
}
