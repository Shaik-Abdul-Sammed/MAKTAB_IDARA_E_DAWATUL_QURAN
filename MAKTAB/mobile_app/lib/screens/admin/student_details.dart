import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../providers/student_detail_provider.dart';
import 'log_fee_payment_dialog.dart';
import 'package:intl/intl.dart';
import '../../repositories/student_repository.dart';
import '../../repositories/batch_repository.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/molecules/confirm_dialog.dart';
import '../../widgets/molecules/custom_app_bar.dart';

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;
  const StudentDetailsScreen({super.key, required this.studentId});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  late final StudentDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = StudentDetailProvider(StudentRepository(), BatchRepository());
    _provider.fetchStudent(widget.studentId);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _onEdit(Student student) async {
    final updated = await context.push<bool>(
      '/admin/students/${student.id}/edit',
      extra: student,
    );
    if (updated == true) {
      _provider.fetchStudent(widget.studentId);
    }
  }

  Future<void> _onDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Student',
        message: 'Permanently remove "${student.name}" (ADM: ${student.admissionNumber})?',
      ),
    );
    if (confirmed == true) {
      try {
        await _provider.deleteCurrentStudent();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student profile deleted.'), backgroundColor: Color(0xFF004D40)),
        );
        context.pop();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete student.'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<StudentDetailProvider>(
        builder: (context, p, _) {
          final s = p.student;
          return Scaffold(
            backgroundColor: const Color(0xFFF9FBE7),
            appBar: CustomAppBar(
              title: s?.name ?? 'Student Details',
              actions: p.hasStudent
                  ? [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit Profile',
                        onPressed: () => _onEdit(s!),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _onDelete(s!),
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
                          onRetry: () => _provider.fetchStudent(widget.studentId),
                        )
                      : _StudentDetailContent(
                          key: ValueKey(s?.id),
                          student: s!,
                          batchName: p.batch?.name ?? 'Unassigned',
                          onEdit: () => _onEdit(s),
                          onDelete: () => _onDelete(s),
                        ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentDetailContent extends StatelessWidget {
  final Student student;
  final String batchName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentDetailContent({
    super.key,
    required this.student,
    required this.batchName,
    required this.onEdit,
    required this.onDelete,
  });

  String _getTranslatedMessage(String language, String name, int amount) {
    switch (language) {
      case 'Urdu':
        return 'محترم سرپرست، یاد دہانی کرائی جاتی ہے کہ مکتب کے لیے $name کی ₹$amount فیس واجب الادا ہے۔ براہ کرم جلد از جلد جمع کرائیں۔';
      case 'Hindi':
        return 'प्रिय अभिभावक, एक सौम्य अनुस्मारक कि मकतब के लिए $name की ₹$amount फीस बकाया है। कृपया इसे जल्द से जल्द जमा करें।';
      case 'Telugu':
        return 'ప్రియమైన సంరక్షకులు, గమనించగలరు: $name యొక్క మక్తాబ్ ఫీజు ₹$amount చెల్లించాల్సి ఉంది. దయచేసి వీలైనంత త్వరగా చెల్లించండి.';
      case 'English':
      default:
        return 'Dear Guardian, a gentle reminder that the MAKTAB IDARA E DAWATUL QURAN fees of ₹$amount for $name are due. Please submit at your earliest convenience.';
    }
  }

  Future<void> _sendFeeReminder(BuildContext context) async {
    if (student.phone == null || student.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number available to send reminder.')),
      );
      return;
    }
    final amount = student.feesAmount ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fee amount set for this student.')),
      );
      return;
    }

    // Show Language Selection Dialog
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Reminder Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () => Navigator.pop(context, 'English'),
              ),
              ListTile(
                title: const Text('Urdu (اردو)'),
                onTap: () => Navigator.pop(context, 'Urdu'),
              ),
              ListTile(
                title: const Text('Hindi (हिन्दी)'),
                onTap: () => Navigator.pop(context, 'Hindi'),
              ),
              ListTile(
                title: const Text('Telugu (తెలుగు)'),
                onTap: () => Navigator.pop(context, 'Telugu'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedLanguage != null) {
      final message = _getTranslatedMessage(selectedLanguage, student.name, amount);
      final uri = Uri.parse('sms:${student.phone}?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch messaging app.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StudentDetailProvider>(context);
    final payments = provider.payments;

    final initials = student.name.isNotEmpty
        ? student.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Hero Banner
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
                  tag: 'student_avatar_${student.id}',
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  student.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                ),
                if (student.arabicName != null && student.arabicName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    student.arabicName!,
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontFamily: 'Traditional Arabic'),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ADM: ${student.admissionNumber} · $batchName',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Metadata Grid
          _buildMetaSection('Student & Academic Information', [
            _MetaRow(icon: Icons.confirmation_number_outlined, label: 'Admission No', value: student.admissionNumber),
            _MetaRow(icon: Icons.class_outlined, label: 'Batch / Class', value: batchName),
            _MetaRow(icon: Icons.cake_outlined, label: 'Date of Birth', value: student.dob ?? 'Not recorded'),
            _MetaRow(icon: Icons.wc_outlined, label: 'Gender', value: student.gender ?? 'Not specified'),
            _MetaRow(icon: Icons.currency_rupee, label: 'Fees Amount', value: student.feesAmount != null ? '₹${student.feesAmount}' : 'Not set'),
            _MetaRow(icon: Icons.calendar_today_outlined, label: 'Enrollment Date', value: _formatDate(student.createdAt)),
          ]),
          const SizedBox(height: 16),

          // Guardian Info Section
          _buildMetaSection('Guardian & Contact', [
            _MetaRow(icon: Icons.person_outline, label: "Father's Name", value: student.fatherName ?? 'Not provided'),
            _MetaRow(icon: Icons.phone_outlined, label: 'Contact Phone', value: student.phone ?? 'Not provided'),
          ]),
          const SizedBox(height: 28),

          // Payment History Section
          _buildMetaSection('Fee Payment History', [
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No fee payments recorded.', style: TextStyle(color: Colors.black54, fontSize: 13)),
              )
            else
              ...payments.map((p) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.currency_rupee, color: Color(0xFF004D40), size: 18),
                ),
                title: Text('₹${p.amount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                subtitle: Text('${p.mode}\\n${_formatDateTime(p.timestamp)}', style: const TextStyle(fontSize: 12)),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeletePayment(context, p.id!, provider),
                ),
              )),
          ]),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showLogPaymentDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Log Fee Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sendFeeReminder(context),
              icon: const Icon(Icons.message_outlined),
              label: const Text('Send Fee Reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Student'),
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
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black45)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...rows,
        ],
      ),
    );
  }


  void _showLogPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LogFeePaymentDialog(student: student),
    );
  }

  void _confirmDeletePayment(BuildContext context, int paymentId, StudentDetailProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deletePayment(paymentId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
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
            const Text('Could not load student profile',
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
