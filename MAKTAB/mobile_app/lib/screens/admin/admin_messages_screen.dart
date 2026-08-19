import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/widgets/custom_app_bar.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final UserRepository _userRepo = UserRepository();
  List<User> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final teachers = await _userRepo.getAllTeachers();
    setState(() {
      _teachers = teachers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Messaging & Bulletins'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/chat/0?name=All%20Teachers');
                    },
                    icon: const Icon(Icons.campaign),
                    label: const Text('Broadcast Announcement'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _teachers.isEmpty
                      ? const Center(child: Text('No teachers found.'))
                      : ListView.builder(
                          itemCount: _teachers.length,
                          itemBuilder: (context, index) {
                            final teacher = _teachers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF004D40),
                                child: Text(
                                  teacher.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(teacher.name),
                              subtitle: const Text('Tap to open chat'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final name = Uri.encodeComponent(teacher.name);
                                context.push('/chat/${teacher.id}?name=$name');
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
