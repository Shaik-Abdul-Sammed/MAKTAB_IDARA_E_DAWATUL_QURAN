import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/repositories/batch_repository.dart';

/// Admin screen: toggle-assign batches to a specific teacher.
/// Each Batch shows a checkbox. Checking assigns; unchecking revokes.
class TeacherAssignedBatchesScreen extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherAssignedBatchesScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherAssignedBatchesScreen> createState() =>
      _TeacherAssignedBatchesScreenState();
}

class _TeacherAssignedBatchesScreenState
    extends State<TeacherAssignedBatchesScreen> {
  final _batchRepo = BatchRepository();

  List<Batch> _allBatches = [];
  Set<int> _assignedBatchIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await _batchRepo.getAllBatches();
    final mine = await _batchRepo.fetchTeacherBatches(widget.teacherId);
    if (!mounted) return;
    setState(() {
      _allBatches = all;
      _assignedBatchIds = mine
          .where((b) => b.id != null)
          .map((b) => b.id!)
          .toSet();
      _isLoading = false;
    });
  }

  Future<void> _toggle(Batch batch, bool assign) async {
    if (batch.id == null) return;
    setState(() => _isSaving = true);
    try {
      if (assign) {
        await _batchRepo.assignTeacherToBatch(batch.id!, widget.teacherId);
        _assignedBatchIds.add(batch.id!);
      } else {
        // Only unassign if this teacher is currently the owner
        if (batch.teacherId == widget.teacherId) {
          await _batchRepo.removeTeacherFromBatch(batch.id!);
        }
        _assignedBatchIds.remove(batch.id!);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Batch> get _filtered {
    if (_search.trim().isEmpty) return _allBatches;
    return _allBatches
        .where(
          (b) => b.name.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final assignedCount = _assignedBatchIds.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign Batches',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
            Text(
              widget.teacherName,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : Column(
              children: [
                // ── Summary banner ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: AppColors.primaryTeal.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primaryTeal, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$assignedCount of ${_allBatches.length} batches assigned to ${widget.teacherName}.',
                          style: const TextStyle(
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search batches...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.primaryTeal),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                ),

                // ── Batch list ───────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primaryTeal,
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No batches found.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final batch = filtered[i];
                              final isAssigned = batch.id != null &&
                                  _assignedBatchIds.contains(batch.id);
                              final isOwnedByOther = batch.teacherId != null &&
                                  batch.teacherId != widget.teacherId;

                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isAssigned
                                        ? AppColors.primaryTeal
                                            .withValues(alpha: 0.4)
                                        : Colors.black.withValues(alpha: 0.06),
                                    width: isAssigned ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    if (isAssigned)
                                      BoxShadow(
                                        color: AppColors.primaryTeal
                                            .withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: isAssigned,
                                      onChanged: isOwnedByOther
                                          ? null // Disable if another teacher owns it
                                          : (val) =>
                                              _toggle(batch, val ?? false),
                                      activeColor: AppColors.primaryTeal,
                                      controlAffinity:
                                          ListTileControlAffinity.trailing,
                                      title: Text(
                                        batch.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryTeal,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('⏰ ${batch.timing}',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          if (isOwnedByOther)
                                            const Text(
                                              '⚠ Assigned to another teacher',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange),
                                            ),
                                        ],
                                      ),
                                      secondary: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isAssigned
                                              ? AppColors.primaryTeal
                                                  .withValues(alpha: 0.12)
                                              : Colors.black
                                                  .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.class_rounded,
                                          color: isAssigned
                                              ? AppColors.primaryTeal
                                              : Colors.black38,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
