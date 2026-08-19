import 'package:flutter/material.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/domain/dtos/user_dto.dart';
import 'package:maktab_app/screens/login_screen.dart';
import 'package:maktab_app/screens/welcome_screen.dart';
import 'package:maktab_app/screens/register_screen.dart';
import 'package:maktab_app/screens/admin_dashboard.dart';
import 'package:maktab_app/screens/teacher_dashboard.dart';
import 'package:maktab_app/screens/admin/teacher_list.dart';
import 'package:maktab_app/screens/admin/teacher_add.dart';
import 'package:maktab_app/screens/admin/teacher_edit.dart';
import 'package:maktab_app/screens/admin/teacher_details.dart';
import 'package:maktab_app/screens/admin/teacher_stats.dart';
import 'package:maktab_app/screens/admin/teacher_assigned_batches.dart';
import 'package:maktab_app/screens/admin/student_list.dart';
import 'package:maktab_app/screens/admin/student_add.dart';
import 'package:maktab_app/screens/admin/student_edit.dart';
import 'package:maktab_app/screens/admin/student_details.dart';
import 'package:maktab_app/screens/admin/student_quran_charts.dart';
import 'package:maktab_app/screens/admin/past_students_screen.dart';
import 'package:maktab_app/screens/admin/batch_list.dart';
import 'package:maktab_app/screens/admin/batch_attendance_calendar.dart';
import 'package:maktab_app/screens/admin/batch_add.dart';
import 'package:maktab_app/screens/admin/batch_edit.dart';
import 'package:maktab_app/screens/admin/batch_details.dart';
import 'package:maktab_app/screens/admin/batch_schedule.dart';
import 'package:maktab_app/screens/teacher/attendance_screen.dart';
import 'package:maktab_app/screens/teacher/attendance_entry.dart';
import 'package:maktab_app/screens/admin/admin_messages_screen.dart';
import 'package:maktab_app/screens/chat_screen.dart';
import 'package:maktab_app/screens/teacher/quran_progress_screen.dart';
import 'package:maktab_app/screens/teacher/quran_progress_entry.dart';
import 'package:maktab_app/screens/teacher/daily_checklist_screen.dart';
import 'package:maktab_app/screens/teacher/notification_center.dart';
import 'package:maktab_app/screens/teacher/message_box.dart';
import 'package:maktab_app/screens/teacher/teacher_home.dart';
import 'package:maktab_app/screens/teacher/teacher_batches.dart';
import 'package:maktab_app/screens/teacher/class_announcements.dart';
import 'package:maktab_app/screens/teacher/attendance_history.dart';
import 'package:maktab_app/screens/reports/reports_dashboard.dart';
import 'package:maktab_app/screens/reports/student_academic_history.dart';
import 'package:maktab_app/screens/admin/batch_attendance_selection.dart';
import 'package:maktab_app/screens/syllabus/syllabus_hub.dart';
import 'package:maktab_app/screens/syllabus/study_guidelines.dart';
import 'package:maktab_app/screens/syllabus/syllabus_progress_charts.dart';
import 'package:maktab_app/screens/support/support_help.dart';
import 'package:maktab_app/screens/profiles/user_profile_screen.dart';
import 'package:maktab_app/screens/profiles/student_profile_screen.dart';
import 'package:maktab_app/screens/settings/settings_screen.dart';
import 'package:maktab_app/screens/settings/backup_history_screen.dart';
import 'package:maktab_app/screens/settings/export_config_screen.dart';
import 'package:maktab_app/screens/fees/fee_management_screen.dart';
import 'package:maktab_app/screens/fees/student_payment_history_screen.dart';
import 'package:maktab_app/screens/tools/whatsapp_reminder_screen.dart';
import 'package:maktab_app/screens/tools/calendar_sync_screen.dart';
import 'package:maktab_app/screens/tools/contact_sync_screen.dart';
import 'package:maktab_app/screens/admin/teacher_attendance_screen.dart';
import 'package:maktab_app/screens/admin/teacher_attendance_history_screen.dart';
import 'package:maktab_app/screens/admin/teacher_face_attendance_screen.dart';
import 'package:maktab_app/screens/admin/excel_import_screen.dart';
import 'package:maktab_app/screens/admin/reports/animated_analytics_screen.dart';
import 'package:maktab_app/screens/admin/checklist_mgmt.dart';
import 'package:maktab_app/screens/admin/checklist_questions_config.dart';
import 'package:maktab_app/screens/admin/checklist_submission_logs.dart';
import 'package:maktab_app/screens/admin/admin_audit_logs.dart';
import 'package:maktab_app/screens/admin/teacher_activity_log.dart';
import 'package:maktab_app/screens/admin/student_promotion.dart';
import 'package:maktab_app/screens/teacher/syllabus_tracker.dart';
import 'package:maktab_app/screens/teacher/student_health_info.dart';
import 'package:maktab_app/screens/teacher/behavior_log_list.dart';
import 'package:maktab_app/screens/teacher/checklist_entry.dart';
import 'package:maktab_app/screens/teacher/checklist_history.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/screens/settings/password_vault_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final GoRouter router = GoRouter(
    initialLocation: '/welcome',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final bool isAuthenticated = authProvider.isAuthenticated;
      final bool hasRegisteredAdmin = authProvider.hasRegisteredAdminUser;

      final String currentRoute = state.uri.toString();
      final bool isWelcomeRoute = currentRoute == '/welcome';
      final bool isRegisterRoute = currentRoute == '/register';
      final bool isLoginRoute = currentRoute == '/login';

      if (!hasRegisteredAdmin) {
        if (!isWelcomeRoute && !isRegisterRoute && !isLoginRoute) {
          return '/welcome';
        }
        return null;
      }

      if (!isAuthenticated) {
        if (!isLoginRoute && !isWelcomeRoute && !isRegisterRoute) {
          return '/login';
        }
        if (isWelcomeRoute || isRegisterRoute) {
          return '/login';
        }
        return null;
      }

      if (isAuthenticated && (isLoginRoute || isWelcomeRoute || isRegisterRoute)) {
        if (authProvider.currentUser?.role == 'admin') {
          return '/admin';
        } else {
          // Allow login_screen to handle FaceVerification for teachers manually
          if (isLoginRoute) return null;
          return '/teacher';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId = int.tryParse(state.pathParameters['userId'] ?? '0') ?? 0;
          final userName = state.uri.queryParameters['name'] ?? 'Chat';
          return ChatScreen(otherUserId: userId, otherUserName: userName);
        },
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => build3DPageTransition(child: const AdminDashboard(), state: state),
        routes: [
          GoRoute(
            path: 'teachers',
            builder: (context, state) => const TeacherListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const TeacherAddScreen(),
              ),
              GoRoute(
                path: 'stats',
                builder: (context, state) => const TeacherStatsScreen(),
              ),
              GoRoute(
                path: ':teacherId',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['teacherId'] ?? '') ?? 0;
                  return TeacherDetailsScreen(teacherId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final teacher = state.extra as UserDTO;
                      return TeacherEditScreen(teacher: teacher);
                    },
                  ),
                  GoRoute(
                    path: 'assign-batches',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      final id = int.tryParse(
                              state.pathParameters['teacherId'] ?? '') ??
                          0;
                      return TeacherAssignedBatchesScreen(
                        teacherId: id,
                        teacherName: extra?['teacherName'] as String? ?? 'Teacher',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'students',
            builder: (context, state) => const StudentListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const StudentAddScreen(),
              ),
              GoRoute(
                path: 'stats',
                builder: (context, state) => const StudentQuranChartsScreen(),
              ),
              GoRoute(
                path: 'promotion',
                builder: (context, state) => const StudentPromotionScreen(),
              ),
              GoRoute(
                path: 'past',
                builder: (context, state) => const PastStudentsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) =>
                    StudentProfileScreen(student: state.extra as Student),
              ),
              GoRoute(
                path: ':studentId',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['studentId'] ?? '') ?? 0;
                  return StudentDetailsScreen(studentId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final student = state.extra as Student;
                      return StudentEditScreen(student: student);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'batches',
            builder: (context, state) => const BatchListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const BatchAddScreen(),
              ),
              GoRoute(
                path: 'schedule',
                builder: (context, state) => const BatchScheduleScreen(),
              ),
              GoRoute(
                path: ':batchId',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['batchId'] ?? '') ?? 0;
                  return BatchDetailsScreen(batchId: id);
                },
                routes: [
                  GoRoute(
                    path: 'attendance-calendar',
                    builder: (context, state) {
                      final idStr = state.pathParameters['batchId'];
                      final id = int.tryParse(idStr ?? '') ?? 0;
                      return BatchAttendanceCalendarScreen(batchId: id);
                    },
                  ),
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final batch = state.extra as Batch;
                      return BatchEditScreen(batch: batch);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'fees',
            pageBuilder: (context, state) => build3DPageTransition(child: const FeeManagementScreen(), state: state),
            routes: [
              GoRoute(
                path: 'history',
                builder: (context, state) => const StudentPaymentHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'tools',
            builder: (context, state) => const WhatsAppReminderScreen(),
            routes: [
              GoRoute(
                path: 'whatsapp',
                builder: (context, state) => const WhatsAppReminderScreen(),
              ),
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const CalendarSyncScreen(),
              ),
              GoRoute(
                path: 'contacts',
                builder: (context, state) => const ContactSyncScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'attendance',
            builder: (context, state) => const AttendanceScreen(),
            routes: [
              GoRoute(
                path: 'entry',
                builder: (context, state) {
                  final batchId = int.tryParse(state.uri.queryParameters['batchId'] ?? '') ?? 0;
                  final date = state.uri.queryParameters['date'] ?? '';
                  return AttendanceEntryScreen(batchId: batchId, date: date);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'quran_progress',
            builder: (context, state) => const QuranProgressScreen(),
            routes: [
              GoRoute(
                path: 'entry',
                builder: (context, state) {
                  final studentId = int.tryParse(state.uri.queryParameters['studentId'] ?? '') ?? 0;
                  final studentName = Uri.decodeComponent(state.uri.queryParameters['studentName'] ?? 'Student');
                  return QuranProgressEntryScreen(studentId: studentId, studentName: studentName);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => ReportsDashboard(),
            routes: [
              GoRoute(
                path: 'academic',
                builder: (context, state) => const StudentAcademicHistoryScreen(),
              ),
              GoRoute(
                path: 'attendance_log',
                builder: (context, state) => const BatchAttendanceSelectionScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'syllabus',
            builder: (context, state) => const SyllabusHubScreen(),
            routes: [
              GoRoute(
                path: 'guidelines',
                builder: (context, state) => const StudyGuidelinesScreen(),
              ),
              GoRoute(
                path: 'charts',
                builder: (context, state) => const SyllabusProgressChartsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'checklist',
            builder: (context, state) => const ChecklistMgmtScreen(),
            routes: [
              GoRoute(
                path: 'config',
                builder: (context, state) => const ChecklistQuestionsConfigScreen(),
              ),
              GoRoute(
                path: 'submissions',
                builder: (context, state) => const ChecklistSubmissionLogsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'audit-logs',
            builder: (context, state) => const AdminAuditLogsScreen(),
          ),
          GoRoute(
            path: 'teacher-activity',
            builder: (context, state) => const TeacherActivityLogScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const AdminMessagesScreen(),
          ),
          GoRoute(
            path: 'support',
            builder: (context, state) => const SupportHelpScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => UserProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => SettingsScreen(),
            routes: [
              GoRoute(
                path: 'backups',
                builder: (context, state) => const BackupHistoryScreen(),
              ),
              GoRoute(
                path: 'export_config',
                builder: (context, state) => const ExportConfigScreen(),
              ),
              GoRoute(
                path: 'vault',
                builder: (context, state) => const PasswordVaultScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'teacher-attendance',
            builder: (context, state) => const TeacherAttendanceScreen(),
            routes: [
              GoRoute(
                path: 'history',
                builder: (context, state) {
                  final teacherIdStr = state.uri.queryParameters['teacherId'];
                  final teacherId = teacherIdStr != null ? int.tryParse(teacherIdStr) : null;
                  return TeacherAttendanceHistoryScreen(initialTeacherId: teacherId);
                },
              ),
              GoRoute(
                path: 'face',
                builder: (context, state) => const TeacherFaceAttendanceScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'import-excel',
            builder: (context, state) => const ExcelImportScreen(),
          ),
          GoRoute(
            path: 'tools/contacts',
            builder: (context, state) => const ContactSyncScreen(),
          ),
          GoRoute(
            path: 'analytics-3d',
            builder: (context, state) => const AnimatedAnalyticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => TeacherDashboard(),
        routes: [
          GoRoute(
            path: 'home',
            builder: (context, state) => const TeacherHomeScreen(),
          ),
          GoRoute(
            path: 'batches',
            builder: (context, state) => const TeacherBatchesScreen(),
          ),
          GoRoute(
            path: 'announcements',
            builder: (context, state) => const ClassAnnouncementsScreen(),
          ),
          GoRoute(
            path: 'my-attendance',
            builder: (context, state) => const AttendanceHistoryScreen(),
          ),
          GoRoute(
            path: 'attendance',
            builder: (context, state) => const AttendanceScreen(),
            routes: [
              GoRoute(
                path: 'entry',
                builder: (context, state) {
                  final batchId = int.tryParse(state.uri.queryParameters['batchId'] ?? '') ?? 0;
                  final date = state.uri.queryParameters['date'] ?? '';
                  return AttendanceEntryScreen(batchId: batchId, date: date);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'quran_progress',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const QuranProgressScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                );
              },
            ),
            routes: [
              GoRoute(
                path: 'entry',
                pageBuilder: (context, state) {
                  final studentId = int.tryParse(state.uri.queryParameters['studentId'] ?? '') ?? 0;
                  final studentName = Uri.decodeComponent(state.uri.queryParameters['studentName'] ?? 'Student');
                  return CustomTransitionPage(
                    key: state.pageKey,
                    child: QuranProgressEntryScreen(studentId: studentId, studentName: studentName),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                          ),
                          child: child,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => ReportsDashboard(),
          ),
          GoRoute(
            path: 'checklist',
            builder: (context, state) => const DailyChecklistScreen(),
          ),
          GoRoute(
            path: 'syllabus-tracker',
            builder: (context, state) => const SyllabusTrackerScreen(),
          ),
          GoRoute(
            path: 'health',
            builder: (context, state) => const StudentHealthInfoScreen(),
          ),
          GoRoute(
            path: 'behavior',
            builder: (context, state) => const BehaviorLogListScreen(),
          ),
          GoRoute(
            path: 'checklist-entry',
            builder: (context, state) => const ChecklistEntryScreen(),
          ),
          GoRoute(
            path: 'checklist-history',
            builder: (context, state) => const ChecklistHistoryScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const MessageBoxScreen(),
          ),
          GoRoute(
            path: 'support',
            builder: (context, state) => const SupportHelpScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => UserProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage build3DPageTransition({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(pi / 2 * (1 - animation.value));
            
          final opacity = animation.value.clamp(0.0, 1.0);
            
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}
