class AppRoutes {
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';

  // Admin Routes
  static const String adminDashboard = '/admin';
  static const String adminTeachers = '/admin/teachers';
  static const String adminTeacherAdd = '/admin/teachers/add';
  static const String adminTeacherStats = '/admin/teachers/stats';

  static const String adminStudents = '/admin/students';
  static const String adminStudentAdd = '/admin/students/add';
  static const String adminStudentStats = '/admin/students/stats';
  static const String adminPastStudents = '/admin/students/past';

  static const String adminBatches = '/admin/batches';
  static const String adminBatchAdd = '/admin/batches/add';
  static const String adminBatchSchedule = '/admin/batches/schedule';

  static const String adminFees = '/admin/fees';
  static const String adminFeeHistory = '/admin/fees/history';

  static const String adminToolsWhatsApp = '/admin/tools/whatsapp';
  static const String adminToolsCalendar = '/admin/tools/calendar';
  static const String adminToolsContacts = '/admin/tools/contacts';

  static const String adminAttendance = '/admin/attendance';
  static const String adminQuranProgress = '/admin/quran_progress';
  static const String adminReports = '/admin/reports';
  static const String adminReportsAcademic = '/admin/reports/academic';
  static const String adminReportsAttendanceLog = '/admin/reports/attendance_log';
  static const String adminSyllabus = '/admin/syllabus';
  static const String adminSyllabusGuidelines = '/admin/syllabus/guidelines';
  static const String adminSyllabusCharts = '/admin/syllabus/charts';
  static const String adminChecklist = '/admin/checklist';
  static const String adminChecklistConfig = '/admin/checklist/config';
  static const String adminChecklistSubmissions = '/admin/checklist/submissions';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminTeacherActivity = '/admin/teacher-activity';
  static const String adminStudentPromotion = '/admin/students/promotion';
  static const String adminNotifications = '/admin/notifications';
  static const String adminMessages = '/admin/messages';
  static const String adminSupport = '/admin/support';
  static const String adminProfile = '/admin/profile';
  static const String adminSettings = '/admin/settings';
  static const String adminBackups = '/admin/settings/backups';
  static const String adminExportConfig = '/admin/settings/export_config';

  // Teacher Routes
  static const String teacherDashboard = '/teacher';
  static const String teacherAttendance = '/teacher/attendance';
  static const String teacherQuranProgress = '/teacher/quran_progress';
  static const String teacherReports = '/teacher/reports';
  static const String teacherChecklist = '/teacher/checklist';
  static const String teacherSyllabusTracker = '/teacher/syllabus-tracker';
  static const String teacherHealth = '/teacher/health';
  static const String teacherBehavior = '/teacher/behavior';
  static const String teacherChecklistEntry = '/teacher/checklist-entry';
  static const String teacherChecklistHistory = '/teacher/checklist-history';
  static const String teacherNotifications = '/teacher/notifications';
  static const String teacherMessages = '/teacher/messages';
  static const String teacherSupport = '/teacher/support';
  static const String teacherProfile = '/teacher/profile';
  static const String teacherSettings = '/teacher/settings';
}
