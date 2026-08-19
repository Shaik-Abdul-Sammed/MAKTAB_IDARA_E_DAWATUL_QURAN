import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/dtos/user_dto.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../providers/teacher_detail_provider.dart';
import '../../repositories/teacher_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../utils/whatsapp_utility.dart';

class TeacherDetailsScreen extends StatefulWidget {
  final int teacherId;
  const TeacherDetailsScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  late final TeacherDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = TeacherDetailProvider(TeacherRepository());
    _provider.fetchTeacher(widget.teacherId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _onEdit(UserDTO teacher) async {
    final updated = await context.push<bool>(
      '/admin/teachers/${teacher.id}/edit',
      extra: teacher,
    );
    if (updated == true) {
      _provider.fetchTeacher(widget.teacherId);
    }
  }

  Future<void> _onDelete(UserDTO teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Teacher',
        message: 'Permanently remove "${teacher.name}"? This cannot be undone.',
      ),
    );
    if (confirmed == true) {
      try {
        await _provider.deleteCurrentTeacher();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher deleted.'), backgroundColor: Color(0xFF004D40)),
        );
        context.pop();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete. Please retry.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onToggleActive() async {
    try {
      await _provider.toggleActiveStatus();
      if (!mounted) return;
      final isActive = _provider.teacher?.isActive ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Teacher activated.' : 'Teacher deactivated.'),
          backgroundColor: isActive ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status.'), backgroundColor: Colors.red),
      );
    }
  }

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _showResetPinDialog(UserDTO teacher) {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final userRepo = UserRepository();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset PIN for ${teacher.name}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: pinController,
              decoration: InputDecoration(
                labelText: 'New 4-Digit PIN',
                prefixIcon: const Icon(Icons.lock_reset, color: Color(0xFF004D40)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (val) {
                if (val == null || val.length != 4) return 'PIN must be exactly 4 digits';
                if (int.tryParse(val) == null) return 'PIN must be numeric';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (teacher.id == null) return;
                  await userRepo.updateUserPin(teacher.id!, _hashPin(pinController.text));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PIN successfully updated for ${teacher.name}'))
                    );
                    
                    if (teacher.mobile != null && teacher.mobile!.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Share PIN'),
                          content: const Text('Do you want to send the new PIN to the teacher via WhatsApp?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                WhatsAppUtility.sendTeacherCredentials(context, teacher.mobile!, teacher.name, pinController.text);
                              },
                              child: const Text('Yes, Send'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save & Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<TeacherDetailProvider>(
        builder: (context, p, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FBE7),
            appBar: CustomAppBar(
              title: p.teacher?.name ?? 'Teacher Details',
              actions: p.hasTeacher
                  ? [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () => _onEdit(p.teacher!),
                      ),
                      if (p.teacher?.mobile != null && p.teacher!.mobile!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.message_outlined, color: Colors.green),
                          tooltip: 'Send/Reset PIN via WhatsApp',
                          onPressed: () => _showResetPinDialog(p.teacher!),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _onDelete(p.teacher!),
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
                          onRetry: () => _provider.fetchTeacher(widget.teacherId),
                        )
                      : _TeacherDetailContent(
                          key: ValueKey(p.teacher?.id),
                          teacher: p.teacher!,
                          onEdit: () => _onEdit(p.teacher!),
                          onDelete: () => _onDelete(p.teacher!),
                          onToggleActive: _onToggleActive,
                        ),
            ),
          );
        },
      ),
    );
  }
}

// ── Detail Content ──────────────────────────────────────────

class _TeacherDetailContent extends StatelessWidget {
  final UserDTO teacher;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  const _TeacherDetailContent({
    super.key,
    required this.teacher,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final initials = teacher.name.isNotEmpty
        ? teacher.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'T';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Card
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
                  tag: 'teacher_avatar_${teacher.id}',
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(teacher.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    teacher.isActive ? '● Active' : '○ Inactive',
                    style: TextStyle(
                      color: teacher.isActive ? Colors.greenAccent.shade200 : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Metadata grid
          _buildMetaSection('Account Information', [
            _MetaRow(icon: Icons.badge_outlined, label: 'Teacher ID', value: 'T-${teacher.id?.toString().padLeft(4, '0') ?? '---'}'),
            _MetaRow(icon: Icons.work_outline, label: 'Role', value: teacher.role.toUpperCase()),
            _MetaRow(icon: Icons.phone_outlined, label: 'Mobile', value: teacher.mobile ?? 'Not provided'),
            _MetaRow(
                icon: Icons.calendar_today_outlined,
                label: 'Registered',
                value: _formatDate(teacher.createdAt)),
          ]),
          const SizedBox(height: 16),

          // Attendance Records
          _buildMetaSection('Attendance & Activity', [
            _ActionRow(
              icon: Icons.calendar_month_rounded,
              label: 'Attendance Registry',
              value: 'View log & stats summary',
              actionLabel: 'View Logs',
              actionColor: const Color(0xFF004D40),
              onTap: () {
                context.push('/admin/teacher-attendance/history?teacherId=${teacher.id}');
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Status & Actions
          _buildMetaSection('Account Status', [
            _ActionRow(
              icon: teacher.isActive ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
              label: 'Account Status',
              value: teacher.isActive ? 'Active' : 'Inactive',
              actionLabel: teacher.isActive ? 'Deactivate' : 'Activate',
              actionColor: teacher.isActive ? Colors.orange : Colors.green,
              onTap: onToggleActive,
            ),
          ]),
          const SizedBox(height: 28),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF004D40),
                    side: const BorderSide(color: Color(0xFF004D40)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
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

  Widget _buildMetaSection(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black45)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...rows,
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF004D40)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.actionColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF004D40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Loading / Error states ──────────────────────────────────

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
          ShimmerLoader(height: 160),
          const SizedBox(height: 16),
          ShimmerLoader(height: 100),
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
            const Text('Could not load teacher',
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
