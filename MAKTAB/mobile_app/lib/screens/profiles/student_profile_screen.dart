import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../services/ai_service.dart';
import '../../utils/permission_helper.dart';

class StudentProfileScreen extends StatefulWidget {
  final Student student;

  const StudentProfileScreen({super.key, required this.student});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String? _aiAnalysis;
  bool _isLoadingAi = false;
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _fetchAiInsights();
  }

  Future<void> _fetchAiInsights() async {
    setState(() => _isLoadingAi = true);
    final performanceData = {
      'attendance_rate': '85%',
      'last_juz': 'Juz 30',
      'recent_grades': ['A', 'B+', 'A-'],
      'behavior': 'Excellent'
    };
    
    final summary = await _aiService.generateStudentReportSummary(widget.student.name, performanceData);
    
    if (mounted) {
      setState(() {
        _aiAnalysis = summary;
        _isLoadingAi = false;
      });
    }
  }

  Future<void> _callParent() async {
    final phone = widget.student.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number on file.')));
      return;
    }

    final granted = await PermissionHelper.requestPermissionWithRationale(
      context: context,
      permission: Permission.phone,
      title: 'Phone Permission',
      rationale: 'Maktab App requires phone call permission to call the student guardian directly.',
    );
    if (!granted) return;

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling $phone...')));
      }
    } catch (_) {}
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.student.phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number on file.')));
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('Assalamu Alaikum, update regarding student ${widget.student.name} from Maktab.');
    final url = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp for $phone')));
      }
    } catch (_) {}
  }

  Future<void> _showEditStudentDialog() async {
    final nameCtrl = TextEditingController(text: widget.student.name);
    final arabicCtrl = TextEditingController(text: widget.student.arabicName ?? '');
    final phoneCtrl = TextEditingController(text: widget.student.phone ?? '');
    final fatherCtrl = TextEditingController(text: widget.student.fatherName ?? '');
    final feesCtrl = TextEditingController(text: widget.student.feesAmount?.toString() ?? '0');
    final notesCtrl = TextEditingController(text: widget.student.teacherNotes ?? '');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF004D40)),
            SizedBox(width: 8),
            Text('Edit Student Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Name', icon: Icon(Icons.person))),
              const SizedBox(height: 8),
              TextField(controller: arabicCtrl, decoration: const InputDecoration(labelText: 'Arabic Name', icon: Icon(Icons.translate))),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', icon: Icon(Icons.phone))),
              const SizedBox(height: 8),
              TextField(controller: fatherCtrl, decoration: const InputDecoration(labelText: 'Father Name', icon: Icon(Icons.person_outline))),
              const SizedBox(height: 8),
              TextField(controller: feesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fees Amount (₹)', icon: Icon(Icons.attach_money))),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Teacher Notes', icon: Icon(Icons.note))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
            onPressed: () async {
              final newStudent = widget.student.copyWith(
                name: nameCtrl.text.trim(),
                arabicName: arabicCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                fatherName: fatherCtrl.text.trim(),
                feesAmount: int.tryParse(feesCtrl.text.trim()) ?? widget.student.feesAmount,
                teacherNotes: notesCtrl.text.trim(),
              );
              final repo = StudentRepository();
              await repo.updateStudent(newStudent);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student details updated successfully!'), backgroundColor: Color(0xFF004D40)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(
        title: const Text('Student Profile'),
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Student Details',
            onPressed: _showEditStudentDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF004D40),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 40, color: Color(0xFF004D40), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.student.name,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (widget.student.arabicName != null)
                    Text(
                      widget.student.arabicName!,
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    'Admission: ${widget.student.admissionNumber}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _callParent,
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat_bubble, size: 16),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(CupertinoIcons.sparkles, color: Colors.amber),
                              SizedBox(width: 10),
                              Text('AI Performance Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 10),
                          _isLoadingAi
                              ? const Center(child: CircularProgressIndicator())
                              : Text(
                                  _aiAnalysis ?? 'Analysis unavailable.',
                                  style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildProfileItem(CupertinoIcons.person_2_fill, 'Father Name', widget.student.fatherName ?? 'N/A'),
                  const SizedBox(height: 10),
                  _buildProfileItem(CupertinoIcons.phone_fill, 'Phone', widget.student.phone ?? 'N/A'),
                  const SizedBox(height: 10),
                  _buildProfileItem(CupertinoIcons.calendar, 'DOB', widget.student.dob ?? 'N/A'),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FBE7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF004D40)),
            ),
            title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
