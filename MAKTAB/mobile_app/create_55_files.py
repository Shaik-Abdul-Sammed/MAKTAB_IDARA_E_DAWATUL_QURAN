import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/lib"

files_to_create = {
    # 2. Architecture & Abstraction (20 Files)
    # Interfaces (8)
    "domain/interfaces/i_user_repository.dart": """abstract class IUserRepository {
  Future<int> insertUser(dynamic user);
  Future<List<dynamic>> getAllTeachers();
}""",
    "domain/interfaces/i_student_repository.dart": """abstract class IStudentRepository {
  Future<int> insertStudent(dynamic student);
  Future<List<dynamic>> getStudentsByBatch(int batchId);
}""",
    "domain/interfaces/i_batch_repository.dart": """abstract class IBatchRepository {
  Future<int> insertBatch(dynamic batch);
  Future<List<dynamic>> getAllBatches();
}""",
    "domain/interfaces/i_attendance_repository.dart": """abstract class IAttendanceRepository {
  Future<int> insertAttendance(dynamic attendance);
  Future<List<dynamic>> getAttendanceByDateAndBatch(String date, int batchId);
}""",
    "domain/interfaces/i_quran_progress_repository.dart": """abstract class IQuranProgressRepository {
  Future<int> insertQuranProgress(dynamic progress);
  Future<List<dynamic>> getProgressByStudent(int studentId);
}""",
    "domain/interfaces/i_auth_service.dart": """abstract class IAuthService {
  Future<bool> login(String pin);
  Future<void> logout();
}""",
    "domain/interfaces/i_backup_service.dart": """abstract class IBackupService {
  Future<String> createBackup();
  Future<bool> restoreBackup(String path);
}""",
    "domain/interfaces/i_notification_service.dart": """abstract class INotificationService {
  Future<void> showNotification(String title, String body);
}""",

    # DTOs (7)
    "domain/dtos/user_dto.dart": """class UserDTO {
  final int? id;
  final String name;
  UserDTO({this.id, required this.name});
}""",
    "domain/dtos/student_dto.dart": """class StudentDTO {
  final int? id;
  final String name;
  StudentDTO({this.id, required this.name});
}""",
    "domain/dtos/batch_dto.dart": """class BatchDTO {
  final int? id;
  final String name;
  BatchDTO({this.id, required this.name});
}""",
    "domain/dtos/attendance_dto.dart": """class AttendanceDTO {
  final int? id;
  final String status;
  AttendanceDTO({this.id, required this.status});
}""",
    "domain/dtos/quran_progress_dto.dart": """class QuranProgressDTO {
  final int? id;
  final String surah;
  QuranProgressDTO({this.id, required this.surah});
}""",
    "domain/dtos/auth_dto.dart": """class AuthDTO {
  final String token;
  AuthDTO({required this.token});
}""",
    "domain/dtos/sync_dto.dart": """class SyncDTO {
  final String lastSyncDate;
  SyncDTO({required this.lastSyncDate});
}""",

    # Service Layer (5)
    "services/business/attendance_service.dart": """class AttendanceService {
  Future<void> markAttendance() async {}
}""",
    "services/business/reporting_service.dart": """class ReportingService {
  Future<void> generateReport() async {}
}""",
    "services/business/student_service.dart": """class StudentService {
  Future<void> manageStudent() async {}
}""",
    "services/business/batch_service.dart": """class BatchService {
  Future<void> manageBatch() async {}
}""",
    "services/business/user_service.dart": """class UserService {
  Future<void> manageUser() async {}
}""",

    # 3. Reusable UI Components (15 Files)
    # Atoms (8)
    "widgets/atoms/custom_button.dart": """import 'package:flutter/material.dart';
class CustomButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ElevatedButton(onPressed: (){}, child: Text('Button'));
}""",
    "widgets/atoms/custom_text_field.dart": """import 'package:flutter/material.dart';
class CustomTextField extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextField();
}""",
    "widgets/atoms/typography.dart": """import 'package:flutter/material.dart';
class AppTypography {
  static const TextStyle header = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
}""",
    "widgets/atoms/status_badge.dart": """import 'package:flutter/material.dart';
class StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Chip(label: Text('Status'));
}""",
    "widgets/atoms/app_icon.dart": """import 'package:flutter/material.dart';
class AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Icon(Icons.school);
}""",
    "widgets/atoms/divider_atom.dart": """import 'package:flutter/material.dart';
class DividerAtom extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider();
}""",
    "widgets/atoms/spacer_atom.dart": """import 'package:flutter/material.dart';
class SpacerAtom extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(height: 16);
}""",
    "widgets/atoms/card_atom.dart": """import 'package:flutter/material.dart';
class CardAtom extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(child: Text('Card'));
}""",

    # Molecules (7)
    "widgets/molecules/student_list_tile.dart": """import 'package:flutter/material.dart';
class StudentListTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(title: Text('Student'));
}""",
    "widgets/molecules/batch_list_tile.dart": """import 'package:flutter/material.dart';
class BatchListTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(title: Text('Batch'));
}""",
    "widgets/molecules/error_dialog.dart": """import 'package:flutter/material.dart';
class ErrorDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text('Error'));
}""",
    "widgets/molecules/confirm_dialog.dart": """import 'package:flutter/material.dart';
class ConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text('Confirm'));
}""",
    "widgets/molecules/custom_app_bar.dart": """import 'package:flutter/material.dart';
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) => AppBar(title: Text('Title'));
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}""",
    "widgets/molecules/empty_state.dart": """import 'package:flutter/material.dart';
class EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Text('Empty'));
}""",
    "widgets/molecules/info_row.dart": """import 'package:flutter/material.dart';
class InfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [Text('Label'), Text('Value')]);
}""",

    # 4. Logging, Audit & Monitoring (10 Files)
    # Core Logger (3)
    "utils/logging/logger.dart": """class AppLogger {
  static void log(String message) {}
}""",
    "utils/logging/log_formatter.dart": """class LogFormatter {
  static String format(String message) => '[LOG]: $message';
}""",
    "utils/logging/log_rotator.dart": """class LogRotator {
  static void rotateLogs() {}
}""",

    # Offline Queue (4)
    "utils/offline/queue_manager.dart": """class QueueManager {
  void enqueue(dynamic item) {}
}""",
    "utils/offline/queue_item.dart": """class QueueItem {
  final String id;
  QueueItem(this.id);
}""",
    "utils/offline/sync_manager.dart": """class SyncManager {
  void syncData() {}
}""",
    "utils/offline/network_listener.dart": """class NetworkListener {
  void listen() {}
}""",

    # Audit Trail (3)
    "models/audit_log.dart": """class AuditLog {
  final String action;
  AuditLog(this.action);
}""",
    "repositories/audit_repository.dart": """class AuditRepository {
  Future<void> saveLog(dynamic log) async {}
}""",
    "services/audit_service.dart": """class AuditService {
  void logAction(String action) {}
}""",

    # 5. Security & Data Integrity (5 Files)
    # Encryption Utilities (3)
    "utils/security/encryption_helper.dart": """class EncryptionHelper {
  static String encrypt(String data) => 'encrypted';
}""",
    "utils/security/key_rotator.dart": """class KeyRotator {
  static void rotateKey() {}
}""",
    "utils/security/data_masker.dart": """class DataMasker {
  static String maskString(String data) => '***';
}""",

    # Validation (2)
    "utils/security/input_validator.dart": """class InputValidator {
  static bool isValid(String input) => true;
}""",
    "utils/security/sanitizer.dart": """class Sanitizer {
  static String sanitize(String input) => input;
}""",

    # 6. Internationalization (i18n) & Accessibility (5 Files)
    # Language Files (3)
    "l10n/app_en.arb": """{
  "appTitle": "Maktab"
}""",
    "l10n/app_ur.arb": """{
  "appTitle": "مکتب"
}""",
    "l10n/app_ar.arb": """{
  "appTitle": "مكتب"
}""",

    # A11y Wrappers (2)
    "widgets/a11y/semantic_button.dart": """import 'package:flutter/material.dart';
class SemanticButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(button: true, child: ElevatedButton(onPressed: (){}, child: Text('Btn')));
}""",
    "widgets/a11y/semantic_text.dart": """import 'package:flutter/material.dart';
class SemanticText extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(label: 'Text', child: Text('Text'));
}"""
}

count = 0
for file_path, content in files_to_create.items():
    full_path = os.path.join(base_dir, file_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w') as f:
        f.write(content)
    count += 1
    print(f"Created {file_path}")

print(f"Successfully created {count} files.")
