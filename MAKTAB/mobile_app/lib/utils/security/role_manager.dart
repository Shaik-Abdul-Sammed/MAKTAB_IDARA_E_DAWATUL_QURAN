class RoleManager {
  static const String roleAdmin = 'admin';
  static const String roleTeacher = 'teacher';

  // Backward compatibility alias
  static const String roleAdminLegacy = roleAdmin;
  static const String roleTeacherLegacy = roleTeacher;

  static bool hasAdminPrivileges(String currentRole) {
    return currentRole == roleAdmin;
  }

  static bool canEditBatch(String currentRole, int teacherId, int batchTeacherId) {
    if (hasAdminPrivileges(currentRole)) return true;
    return teacherId == batchTeacherId;
  }
}