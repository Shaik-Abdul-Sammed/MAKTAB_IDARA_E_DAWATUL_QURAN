import 'package:flutter/material.dart';
import '../atoms/card_atom.dart';
import '../atoms/status_badge.dart';

class StudentListTile extends StatelessWidget {
  final String name;
  final String admissionNumber;
  final String? status; // e.g. Present, Absent for today
  final VoidCallback onTap;

  const StudentListTile({
    super.key,
    required this.name,
    required this.admissionNumber,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardAtom(
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF004D40),
          child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFFFFD700))),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Adm: $admissionNumber'),
        trailing: status != null ? StatusBadge(status: status!) : const Icon(Icons.chevron_right),
      ),
    );
  }
}