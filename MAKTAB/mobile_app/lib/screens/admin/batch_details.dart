import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../models/student.dart';
import '../../domain/dtos/user_dto.dart';
import '../../providers/batch_detail_provider.dart';
import '../../repositories/batch_repository.dart';
import '../../repositories/teacher_repository.dart';
import '../../repositories/student_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../utils/whatsapp_utility.dart';

class BatchDetailsScreen extends StatefulWidget {
  final int batchId;
  const BatchDetailsScreen({super.key, required this.batchId});

  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen> {
  late final BatchDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = BatchDetailProvider(
      BatchRepository(),
      TeacherRepository(),
      StudentRepository(),
    );
    _provider.fetchBatchDetails(widget.batchId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _onEdit(Batch batch) async {
    final updated = await context.push<bool>(
      '/admin/batches/${batch.id}/edit',
      extra: batch,
    );
    if (updated == true) {
      _provider.fetchBatchDetails(widget.batchId);
    }
  }

  Future<void> _onDelete(Batch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Batch',
        message: 'Permanently delete batch "${batch.name}"? Enrolled students will become unassigned.',
      ),
    );
    if (confirmed == true) {
      try {
        await _provider.deleteCurrentBatch();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch deleted.'), backgroundColor: Color(0xFF004D40)),
        );
        context.pop();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete batch.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _broadcastWhatsApp(Batch batch, List<Student> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students in batch.')));
      return;
    }

    await WhatsAppUtility.sendBatchNotice(
      context,
      batchName: batch.name,
      timing: batch.timing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<BatchDetailProvider>(
        builder: (context, p, _) {
          final b = p.batch;
          return Scaffold(
            backgroundColor: const Color(0xFFF9FBE7),
            appBar: CustomAppBar(
              title: b?.name ?? 'Batch Details',
              actions: p.hasBatch
                  ? [
                      IconButton(
                        icon: const Icon(Icons.chat_rounded, color: Colors.green),
                        tooltip: 'WhatsApp Broadcast',
                        onPressed: () => _broadcastWhatsApp(b!, p.students),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Batch',
                        onPressed: () => _onEdit(b!),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Batch',
                        onPressed: () => _onDelete(b!),
                      ),
                    ]
                  : null,
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: p.isLoading
                  ? const _ShimmerDetailContent(key: ValueKey('shimmer'))
                  : p.hasError
                      ? _ErrorContent(
                          key: const ValueKey('error'),
                          message: p.errorMessage,
                          onRetry: () => _provider.fetchBatchDetails(widget.batchId),
                        )
                      : _BatchDetailContent(
                          key: ValueKey(b?.id),
                          batch: b!,
                          teacher: p.teacher,
                          students: p.students,
                          onEdit: () => _onEdit(b),
                          onDelete: () => _onDelete(b),
                          onBroadcast: () => _broadcastWhatsApp(b, p.students),
                        ),
            ),
          );
        },
      ),
    );
  }
}

class _BatchDetailContent extends StatelessWidget {
  final Batch batch;
  final UserDTO? teacher;
  final List<Student> students;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBroadcast;

  const _BatchDetailContent({
    super.key,
    required this.batch,
    required this.teacher,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.onBroadcast,
  });

  @override
  Widget build(BuildContext context) {
    final initials = batch.name.isNotEmpty
        ? batch.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'B';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D40), Color(0xFF00695C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Hero(
                  tag: 'batch_avatar_${batch.id}',
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(batch.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 6),
                    Text(batch.timing,
                        style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildTeacherSection(context),
          const SizedBox(height: 16),

          _buildStudentsSection(context),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBroadcast,
                  icon: const Icon(Icons.chat_rounded, color: Colors.green),
                  label: const Text('WhatsApp Notice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade800),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Batch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF004D40),
                    side: const BorderSide(color: Color(0xFF004D40)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTeacherSection(BuildContext context) {
    return Container(
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
          const Text('Assigned Teacher',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black45)),
          const SizedBox(height: 10),
          if (teacher != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF004D40),
                child: Text(
                  teacher!.name.isNotEmpty ? teacher!.name[0].toUpperCase() : 'T',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(teacher!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(teacher!.mobile ?? 'No phone number', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: Color(0xFF004D40), size: 20),
                onPressed: () => context.push('/admin/teachers/${teacher!.id}'),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Text('No teacher assigned to this batch.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                const Spacer(),
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Assign', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsSection(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enrolled Students',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black45)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${students.length} Total',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (students.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No students currently enrolled in this batch.',
                    style: TextStyle(fontSize: 13, color: Colors.black38)),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = students[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF004D40).withValues(alpha: 0.1),
                      child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                          style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('ADM: ${s.admissionNumber}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
                    onTap: () => context.push('/admin/students/${s.id}'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ShimmerDetailContent extends StatelessWidget {
  const _ShimmerDetailContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ShimmerLoader(height: 180),
          const SizedBox(height: 16),
          ShimmerLoader(height: 100),
          const SizedBox(height: 16),
          ShimmerLoader(height: 200),
        ],
      ),
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
            const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFB0BEC5)),
            const SizedBox(height: 16),
            const Text('Could not load batch overview',
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
