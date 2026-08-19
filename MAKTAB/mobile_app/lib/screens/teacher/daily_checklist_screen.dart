import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/daily_checklist_provider.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class DailyChecklistScreen extends StatelessWidget {
  const DailyChecklistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DailyChecklistProvider(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FBE7),
        appBar: CustomAppBar(
          title: 'Daily Teacher Operations',
          actions: [
            Consumer<DailyChecklistProvider>(
              builder: (context, p, _) => IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: p.resetChecklist,
                tooltip: 'Reset Checklist',
              ),
            ),
          ],
        ),
        floatingActionButton: Consumer<DailyChecklistProvider>(
          builder: (context, p, _) => FloatingActionButton.extended(
            backgroundColor: const Color(0xFF004D40),
            foregroundColor: const Color(0xFFFFD700),
            onPressed: () => _showAddChecklistDialog(context, p),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        body: Consumer<DailyChecklistProvider>(
          builder: (context, p, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Card
                  _buildProgressCard(p),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Operations Checklist',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      TextButton(
                        onPressed: p.markAllCompleted,
                        child: const Text('Mark All Done', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: p.items.length,
                    itemBuilder: (context, index) {
                      final item = p.items[index];
                      return _ChecklistTile(
                        item: item,
                        onToggle: () => p.toggleItem(item.id),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddChecklistDialog(BuildContext context, DailyChecklistProvider provider) {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Checklist Task', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                hintText: 'e.g. Verify attendance log',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g. Routine, Preparation',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              foregroundColor: const Color(0xFFFFD700),
            ),
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                provider.addItem(titleCtrl.text.trim(), categoryCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(DailyChecklistProvider p) {
    final isDone = p.completionPercentage == 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDone
              ? [Colors.green.shade800, Colors.teal.shade700]
              : [const Color(0xFF004D40), const Color(0xFF00695C)],
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
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: p.completionRatio,
                  strokeWidth: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              ),
              Text(
                '${p.completionPercentage}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDone ? 'MashaAllah! All Done 🎉' : 'Daily Maktab Readiness',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.completedCount} of ${p.totalCount} tasks completed for today',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;

  const _ChecklistTile({
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isCompleted ? Colors.green.shade300 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: item.isCompleted,
            onChanged: (_) => onToggle(),
            activeColor: const Color(0xFF004D40),
            checkColor: const Color(0xFFFFD700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted ? Colors.black45 : const Color(0xFF1A1A1A),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
