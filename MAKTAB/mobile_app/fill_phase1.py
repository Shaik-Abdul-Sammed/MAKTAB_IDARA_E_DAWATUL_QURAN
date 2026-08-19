import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/lib"

files = {
    # ---------------- DTOs ----------------
    "domain/dtos/user_dto.dart": """class UserDTO {
  final int? id;
  final String name;
  final String pinHash;
  final String role;
  final String createdAt;

  UserDTO({
    this.id,
    required this.name,
    required this.pinHash,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pin_hash': pinHash,
    'role': role,
    'created_at': createdAt,
  };

  factory UserDTO.fromMap(Map<String, dynamic> map) => UserDTO(
    id: map['id'],
    name: map['name'],
    pinHash: map['pin_hash'],
    role: map['role'],
    createdAt: map['created_at'],
  );
}""",
    
    "domain/dtos/student_dto.dart": """class StudentDTO {
  final int? id;
  final String admissionNumber;
  final String name;
  final String? arabicName;
  final String? dob;
  final String? gender;
  final String? fatherName;
  final String? phone;
  final int? batchId;
  final String createdAt;

  StudentDTO({
    this.id,
    required this.admissionNumber,
    required this.name,
    this.arabicName,
    this.dob,
    this.gender,
    this.fatherName,
    this.phone,
    this.batchId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'admission_number': admissionNumber,
    'name': name,
    'arabic_name': arabicName,
    'dob': dob,
    'gender': gender,
    'father_name': fatherName,
    'phone': phone,
    'batch_id': batchId,
    'created_at': createdAt,
  };

  factory StudentDTO.fromMap(Map<String, dynamic> map) => StudentDTO(
    id: map['id'],
    admissionNumber: map['admission_number'],
    name: map['name'],
    arabicName: map['arabic_name'],
    dob: map['dob'],
    gender: map['gender'],
    fatherName: map['father_name'],
    phone: map['phone'],
    batchId: map['batch_id'],
    createdAt: map['created_at'],
  );
}""",

    "domain/dtos/batch_dto.dart": """class BatchDTO {
  final int? id;
  final String name;
  final String timing;
  final int? teacherId;

  BatchDTO({
    this.id,
    required this.name,
    required this.timing,
    this.teacherId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'timing': timing,
    'teacher_id': teacherId,
  };

  factory BatchDTO.fromMap(Map<String, dynamic> map) => BatchDTO(
    id: map['id'],
    name: map['name'],
    timing: map['timing'],
    teacherId: map['teacher_id'],
  );
}""",

    "domain/dtos/attendance_dto.dart": """class AttendanceDTO {
  final int? id;
  final int studentId;
  final String date;
  final String status;
  final String? remarks;

  AttendanceDTO({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'date': date,
    'status': status,
    'remarks': remarks,
  };

  factory AttendanceDTO.fromMap(Map<String, dynamic> map) => AttendanceDTO(
    id: map['id'],
    studentId: map['student_id'],
    date: map['date'],
    status: map['status'],
    remarks: map['remarks'],
  );
}""",

    "domain/dtos/quran_progress_dto.dart": """class QuranProgressDTO {
  final int? id;
  final int studentId;
  final String date;
  final String surah;
  final int ayahFrom;
  final int ayahTo;
  final String grade;
  final String? remarks;

  QuranProgressDTO({
    this.id,
    required this.studentId,
    required this.date,
    required this.surah,
    required this.ayahFrom,
    required this.ayahTo,
    required this.grade,
    this.remarks,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'date': date,
    'surah': surah,
    'ayah_from': ayahFrom,
    'ayah_to': ayahTo,
    'grade': grade,
    'remarks': remarks,
  };

  factory QuranProgressDTO.fromMap(Map<String, dynamic> map) => QuranProgressDTO(
    id: map['id'],
    studentId: map['student_id'],
    date: map['date'],
    surah: map['surah'],
    ayahFrom: map['ayah_from'],
    ayahTo: map['ayah_to'],
    grade: map['grade'],
    remarks: map['remarks'],
  );
}""",

    "domain/dtos/auth_dto.dart": """class AuthDTO {
  final String token;
  final String role;
  final String expiry;

  AuthDTO({
    required this.token,
    required this.role,
    required this.expiry,
  });

  Map<String, dynamic> toMap() => {
    'token': token,
    'role': role,
    'expiry': expiry,
  };

  factory AuthDTO.fromMap(Map<String, dynamic> map) => AuthDTO(
    token: map['token'],
    role: map['role'],
    expiry: map['expiry'],
  );
}""",

    "domain/dtos/sync_dto.dart": """class SyncDTO {
  final String lastSyncDate;
  final int pendingItems;
  final bool isSyncing;

  SyncDTO({
    required this.lastSyncDate,
    this.pendingItems = 0,
    this.isSyncing = false,
  });

  Map<String, dynamic> toMap() => {
    'lastSyncDate': lastSyncDate,
    'pendingItems': pendingItems,
    'isSyncing': isSyncing,
  };

  factory SyncDTO.fromMap(Map<String, dynamic> map) => SyncDTO(
    lastSyncDate: map['lastSyncDate'],
    pendingItems: map['pendingItems'] ?? 0,
    isSyncing: map['isSyncing'] ?? false,
  );
}""",

    # ---------------- INTERFACES ----------------
    "domain/interfaces/i_user_repository.dart": """import '../dtos/user_dto.dart';

abstract class IUserRepository {
  Future<int> insertUser(UserDTO user);
  Future<List<UserDTO>> getAllTeachers();
  Future<UserDTO?> getUserById(int id);
  Future<int> updateUser(UserDTO user);
  Future<int> deleteUser(int id);
}""",

    "domain/interfaces/i_student_repository.dart": """import '../dtos/student_dto.dart';

abstract class IStudentRepository {
  Future<int> insertStudent(StudentDTO student);
  Future<List<StudentDTO>> getStudentsByBatch(int batchId);
  Future<StudentDTO?> getStudentById(int id);
  Future<int> updateStudent(StudentDTO student);
  Future<int> deleteStudent(int id);
}""",

    "domain/interfaces/i_batch_repository.dart": """import '../dtos/batch_dto.dart';

abstract class IBatchRepository {
  Future<int> insertBatch(BatchDTO batch);
  Future<List<BatchDTO>> getAllBatches();
  Future<List<BatchDTO>> getBatchesByTeacher(int teacherId);
  Future<int> updateBatch(BatchDTO batch);
  Future<int> deleteBatch(int id);
}""",

    "domain/interfaces/i_attendance_repository.dart": """import '../dtos/attendance_dto.dart';

abstract class IAttendanceRepository {
  Future<int> insertAttendance(AttendanceDTO attendance);
  Future<List<AttendanceDTO>> getAttendanceByDateAndBatch(String date, int batchId);
  Future<List<AttendanceDTO>> getAttendanceByStudent(int studentId);
  Future<int> updateAttendance(AttendanceDTO attendance);
}""",

    "domain/interfaces/i_quran_progress_repository.dart": """import '../dtos/quran_progress_dto.dart';

abstract class IQuranProgressRepository {
  Future<int> insertQuranProgress(QuranProgressDTO progress);
  Future<List<QuranProgressDTO>> getProgressByStudent(int studentId);
  Future<int> updateQuranProgress(QuranProgressDTO progress);
  Future<int> deleteQuranProgress(int id);
}""",

    "domain/interfaces/i_auth_service.dart": """abstract class IAuthService {
  Future<bool> login(String pin);
  Future<void> logout();
  Future<bool> changePin(String oldPin, String newPin);
  Future<bool> verifyAdminPin(String pin);
}""",

    "domain/interfaces/i_backup_service.dart": """abstract class IBackupService {
  Future<String> createLocalBackup();
  Future<bool> restoreFromLocalBackup(String path);
  Future<bool> shareBackupFile(String path);
  Future<bool> verifyBackupIntegrity(String path);
}""",

    "domain/interfaces/i_notification_service.dart": """abstract class INotificationService {
  Future<void> showNotification({required String title, required String body});
  Future<void> scheduleNotification({required String title, required String body, required DateTime scheduledDate});
  Future<void> cancelAllNotifications();
}""",
}

for file_path, content in files.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Filled {file_path}")
