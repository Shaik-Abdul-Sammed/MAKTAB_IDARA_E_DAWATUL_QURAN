import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/lib"

files = {
    # ---------------- UI ATOMS ----------------
    "widgets/atoms/app_icon.dart": """import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const AppIcon({
    super.key,
    required this.icon,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? const Color(0xFF004D40), // Maktab Dark Green
    );
  }
}""",

    "widgets/atoms/card_atom.dart": """import 'package:flutter/material.dart';

class CardAtom extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CardAtom({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}""",

    "widgets/atoms/custom_button.dart": """import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isSecondary;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? const Color(0xFFF9FBE7) : const Color(0xFF004D40),
          foregroundColor: isSecondary ? const Color(0xFF004D40) : const Color(0xFFFFD700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          side: isSecondary ? const BorderSide(color: Color(0xFF004D40)) : BorderSide.none,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
              )
            : Text(
                text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}""",

    "widgets/atoms/custom_text_field.dart": """import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF004D40)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFF004D40), width: 2.0),
        ),
      ),
    );
  }
}""",

    "widgets/atoms/divider_atom.dart": """import 'package:flutter/material.dart';

class DividerAtom extends StatelessWidget {
  const DividerAtom({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Colors.grey,
      height: 1.0,
      thickness: 0.5,
    );
  }
}""",

    "widgets/atoms/spacer_atom.dart": """import 'package:flutter/material.dart';

class SpacerAtom extends StatelessWidget {
  final double height;
  final double width;

  const SpacerAtom({super.key, this.height = 16.0, this.width = 0.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: width);
  }
}""",

    "widgets/atoms/status_badge.dart": """import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'leave': return Colors.orange;
      case 'a+':
      case 'a': return Colors.green;
      case 'b': return Colors.blue;
      case 'c': return Colors.orange;
      case 'needs improvement': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: _getColor()),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getColor(),
          fontWeight: FontWeight.bold,
          fontSize: 12.0,
        ),
      ),
    );
  }
}""",

    # ---------------- UI MOLECULES ----------------
    "widgets/molecules/batch_list_tile.dart": """import 'package:flutter/material.dart';
import '../atoms/card_atom.dart';

class BatchListTile extends StatelessWidget {
  final String name;
  final String timing;
  final int studentCount;
  final VoidCallback onTap;

  const BatchListTile({
    super.key,
    required this.name,
    required this.timing,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardAtom(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 4),
              Text(timing, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF9FBE7),
            ),
            child: Text(
              '$studentCount',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
            ),
          )
        ],
      ),
    );
  }
}""",

    "widgets/molecules/confirm_dialog.dart": """import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const ConfirmDialog({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(color: Color(0xFF004D40))),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
          child: const Text('Confirm', style: TextStyle(color: Color(0xFFFFD700))),
        ),
      ],
    );
  }
}""",

    "widgets/molecules/custom_app_bar.dart": """import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF004D40),
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}""",

    "widgets/molecules/empty_state.dart": """import 'package:flutter/material.dart';
import '../atoms/spacer_atom.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SpacerAtom(),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}""",

    "widgets/molecules/error_dialog.dart": """import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String error;

  const ErrorDialog({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Error', style: TextStyle(color: Colors.red)),
      content: Text(error),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}""",

    "widgets/molecules/info_row.dart": """import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}""",

    "widgets/molecules/student_list_tile.dart": """import 'package:flutter/material.dart';
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
}""",

    # ---------------- A11Y ----------------
    "widgets/a11y/semantic_button.dart": """import 'package:flutter/material.dart';
import '../atoms/custom_button.dart';

class SemanticButton extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onPressed;

  const SemanticButton({
    super.key,
    required this.label,
    required this.hint,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: CustomButton(
        text: label,
        onPressed: onPressed,
      ),
    );
  }
}""",

    "widgets/a11y/semantic_text.dart": """import 'package:flutter/material.dart';

class SemanticText extends StatelessWidget {
  final String text;
  final String semanticLabel;
  final TextStyle? style;

  const SemanticText({
    super.key,
    required this.text,
    required this.semanticLabel,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Text(text, style: style),
    );
  }
}""",

    # ---------------- SERVICES ----------------
    "services/attendance_service.dart": """import '../repositories/attendance_repository.dart';
import '../models/attendance.dart';

class AttendanceService {
  final AttendanceRepository _repository = AttendanceRepository();

  Future<void> markBatchAttendance(List<Attendance> attendanceList) async {
    for (var att in attendanceList) {
      await _repository.insertAttendance(att);
    }
  }

  Future<List<Attendance>> getStudentAttendanceHistory(int studentId) async {
    return await _repository.getAttendanceByStudent(studentId);
  }
  
  Future<Map<String, int>> getAttendanceStats(int studentId) async {
    final history = await getStudentAttendanceHistory(studentId);
    int present = 0;
    int absent = 0;
    int leave = 0;
    
    for (var att in history) {
      if (att.status == 'Present') present++;
      if (att.status == 'Absent') absent++;
      if (att.status == 'Leave') leave++;
    }
    
    return {'present': present, 'absent': absent, 'leave': leave};
  }
}""",

    "services/quran_service.dart": """import '../repositories/quran_progress_repository.dart';
import '../models/quran_progress.dart';

class QuranService {
  final QuranProgressRepository _repository = QuranProgressRepository();

  Future<void> recordProgress(QuranProgress progress) async {
    await _repository.insertQuranProgress(progress);
  }

  Future<List<QuranProgress>> getStudentProgress(int studentId) async {
    return await _repository.getProgressByStudent(studentId);
  }
  
  Future<String> getLatestSurah(int studentId) async {
    final history = await getStudentProgress(studentId);
    if (history.isEmpty) return 'None';
    // Assuming history is sorted descending by date
    return history.first.surah;
  }
}""",

    "services/reporting_service.dart": """import 'attendance_service.dart';
import 'quran_service.dart';

class ReportingService {
  final AttendanceService _attService = AttendanceService();
  final QuranService _quranService = QuranService();

  Future<Map<String, dynamic>> generateStudentReport(int studentId, String studentName) async {
    final attStats = await _attService.getAttendanceStats(studentId);
    final totalDays = (attStats['present'] ?? 0) + (attStats['absent'] ?? 0) + (attStats['leave'] ?? 0);
    double attPercentage = totalDays > 0 ? ((attStats['present'] ?? 0) / totalDays) * 100 : 0;
    
    final latestSurah = await _quranService.getLatestSurah(studentId);
    
    return {
      'studentName': studentName,
      'attendancePercentage': attPercentage.toStringAsFixed(1),
      'presentDays': attStats['present'],
      'absentDays': attStats['absent'],
      'latestSurah': latestSurah,
      'reportDate': DateTime.now().toIso8601String(),
    };
  }
}""",

    # ---------------- I18N ----------------
    "l10n/app_en.arb": """{
  "appTitle": "Maktab Idara",
  "loginTitle": "Login to Maktab",
  "adminDashboard": "Admin Dashboard",
  "teacherDashboard": "Teacher Dashboard",
  "students": "Students",
  "batches": "Batches",
  "attendance": "Attendance",
  "quranProgress": "Quran Progress"
}""",
    
    "l10n/app_ur.arb": """{
  "appTitle": "مکتب ادارہ",
  "loginTitle": "لاگ ان کریں",
  "adminDashboard": "ایڈمن ڈیش بورڈ",
  "teacherDashboard": "استاد ڈیش بورڈ",
  "students": "طلباء",
  "batches": "بیچز",
  "attendance": "حاضری",
  "quranProgress": "قرآن پیش رفت"
}""",
    
    "l10n/app_ar.arb": """{
  "appTitle": "مكتب إدارة",
  "loginTitle": "تسجيل الدخول",
  "adminDashboard": "لوحة تحكم المسؤول",
  "teacherDashboard": "لوحة تحكم المعلم",
  "students": "الطلاب",
  "batches": "الدفعات",
  "attendance": "الحضور",
  "quranProgress": "تقدم القرآن"
}"""
}

for file_path, content in files.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Filled {file_path}")
