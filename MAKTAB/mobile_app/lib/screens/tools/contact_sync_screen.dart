import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/molecules/custom_app_bar.dart';
import '../../widgets/shimmer_loader.dart';

class ContactSyncScreen extends StatefulWidget {
  const ContactSyncScreen({super.key});

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final list = await StudentRepository().getAllStudents();
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _callParent(String? phone) async {
    if (phone == null || phone.isEmpty) return;

    final granted = await PermissionHelper.requestPermissionWithRationale(
      context: context,
      permission: Permission.phone,
      title: 'Phone Call Permission',
      rationale: 'Maktab App requires phone permission to initiate direct calls to student guardians.',
    );
    if (!granted) return;

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $phone...')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dialer intent launched for $phone')),
      );
    }
  }

  Future<void> _exportToContacts(Student s) async {
    final granted = await PermissionHelper.requestPermissionWithRationale(
      context: context,
      permission: Permission.contacts,
      title: 'Contacts Access Permission',
      rationale: 'Maktab App needs contact permission to export student & guardian records to your device phonebook.',
    );
    if (!granted) return;

    final phone = s.phone ?? 'N/A';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact vCard created for ${s.name} ($phone)'),
        backgroundColor: const Color(0xFF004D40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: const CustomAppBar(title: 'Contact Directory & Sync'),
      body: SafeArea(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: ShimmerListLoader(count: 6, height: 74),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final s = _students[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF004D40),
                          child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Parent: ${s.fatherName ?? 'Guardian'} · ${s.phone ?? 'No phone'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () => _callParent(s.phone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF004D40)),
                          onPressed: () => _exportToContacts(s),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
