import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/student.dart';
import 'package:url_launcher/url_launcher.dart';

/// A 3×2 quick-action grid shown at the top of TeacherHomeScreen.
/// Extracted into its own widget to keep TeacherHomeScreen under 400 lines.
class TeacherQuickActions extends StatelessWidget {
  final int teacherId;
  final List<Student> students; // Scoped to this teacher's batches

  const TeacherQuickActions({
    super.key,
    required this.teacherId,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.2 : 0.95,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) => _QuickActionTile(
        icon: actions[i].icon,
        label: actions[i].label,
        color: actions[i].color,
        onTap: actions[i].onTap,
      ),
    );
  }

  List<_ActionItem> _buildActions(BuildContext context) {
    return [
      _ActionItem(
        icon: Icons.how_to_reg_rounded,
        label: 'Take\nAttendance',
        color: AppColors.primaryTeal,
        onTap: () => context.push('/teacher/attendance'),
      ),
      _ActionItem(
        icon: Icons.menu_book_rounded,
        label: 'Log Quran\nProgress',
        color: const Color(0xFF1565C0),
        onTap: () => context.push('/teacher/quran_progress'),
      ),
      _ActionItem(
        icon: Icons.checklist_rounded,
        label: 'Submit\nChecklist',
        color: const Color(0xFF388E3C),
        onTap: () => context.push('/teacher/checklist'),
      ),
      _ActionItem(
        icon: Icons.phone_in_talk_rounded,
        label: 'Contact\nParents',
        color: const Color(0xFFE65100),
        onTap: () => _showParentContactSheet(context),
      ),
      _ActionItem(
        icon: Icons.campaign_rounded,
        label: 'Announce-\nments',
        color: const Color(0xFF6A1B9A),
        onTap: () => context.push('/teacher/announcements'),
      ),
      _ActionItem(
        icon: Icons.groups_rounded,
        label: 'My\nBatches',
        color: AppColors.goldAccent,
        onTap: () => context.push('/teacher/batches'),
      ),
    ];
  }

  void _showParentContactSheet(BuildContext context) {
    // Students with a guardian phone number
    final contactable = students
        .where((s) =>
            (s.guardianPhone?.isNotEmpty ?? false) ||
            (s.phone?.isNotEmpty ?? false))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParentContactSheet(students: contactable),
    );
  }
}

// ── Internal tile widget ─────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Parent contact bottom sheet ──────────────────────────────────────────────

class _ParentContactSheet extends StatelessWidget {
  final List<Student> students;

  const _ParentContactSheet({required this.students});

  Future<void> _dial(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot dial $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded,
                        color: AppColors.primaryTeal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Parent Contacts (${students.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: students.isEmpty
                    ? const Center(
                        child: Text(
                          'No contact numbers available\nfor your students.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: students.length,
                        itemBuilder: (ctx, i) {
                          final s = students[i];
                          final phone =
                              s.guardianPhone?.isNotEmpty == true
                                  ? s.guardianPhone!
                                  : s.phone ?? '';
                          final contactName = s.guardianName?.isNotEmpty == true
                              ? s.guardianName!
                              : s.fatherName ?? 'Guardian';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryTeal
                                  .withValues(alpha: 0.12),
                              child: Text(
                                s.name.isNotEmpty
                                    ? s.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('$contactName • $phone'),
                            trailing: IconButton(
                              icon: const Icon(Icons.call_rounded,
                                  color: Color(0xFF388E3C)),
                              onPressed: () => _dial(ctx, phone),
                              tooltip: 'Call $phone',
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Internal data class ──────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
