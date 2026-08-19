class Student {
  final int? id;
  final String admissionNumber;
  final String name;
  final String? arabicName;
  final String? dob;
  final String? gender;
  final String? fatherName;
  final String? phone;
  final String? guardianName;
  final String? guardianPhone;
  final String? photoPath;
  final int? batchId;
  final String createdAt;
  final int? feesAmount;
  /// Private remarks entered by the assigned teacher. Not visible to other teachers.
  final String? teacherNotes;
  final bool isDeleted;
  final String? deletedAt;

  Student({
    this.id,
    required this.admissionNumber,
    required this.name,
    this.arabicName,
    this.dob,
    this.gender,
    this.fatherName,
    this.phone,
    this.guardianName,
    this.guardianPhone,
    this.photoPath,
    this.batchId,
    required this.createdAt,
    this.feesAmount,
    this.teacherNotes,
    this.isDeleted = false,
    this.deletedAt,
  });

  Student copyWith({
    int? id,
    String? admissionNumber,
    String? name,
    String? arabicName,
    String? dob,
    String? gender,
    String? fatherName,
    String? phone,
    String? guardianName,
    String? guardianPhone,
    String? photoPath,
    int? batchId,
    String? createdAt,
    int? feesAmount,
    String? teacherNotes,
    bool? isDeleted,
    String? deletedAt,
  }) {
    return Student(
      id: id ?? this.id,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      name: name ?? this.name,
      arabicName: arabicName ?? this.arabicName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      fatherName: fatherName ?? this.fatherName,
      phone: phone ?? this.phone,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      photoPath: photoPath ?? this.photoPath,
      batchId: batchId ?? this.batchId,
      createdAt: createdAt ?? this.createdAt,
      feesAmount: feesAmount ?? this.feesAmount,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'admission_number': admissionNumber,
      'name': name,
      'arabic_name': arabicName,
      'dob': dob,
      'gender': gender,
      'father_name': fatherName,
      'phone': phone,
      'guardian_name': guardianName,
      'guardian_phone': guardianPhone,
      'photo_path': photoPath,
      'batch_id': batchId,
      'created_at': createdAt,
      'fees_amount': feesAmount,
      'teacher_notes': teacherNotes,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      admissionNumber: map['admission_number'] ?? '',
      name: map['name'] ?? '',
      arabicName: map['arabic_name'],
      dob: map['dob'],
      gender: map['gender'],
      fatherName: map['father_name'],
      phone: map['phone'],
      guardianName: map['guardian_name'],
      guardianPhone: map['guardian_phone'],
      photoPath: map['photo_path'],
      batchId: map['batch_id'],
      createdAt: map['created_at'] ?? '',
      feesAmount: map['fees_amount'],
      teacherNotes: map['teacher_notes'],
      isDeleted: (map['is_deleted'] ?? 0) == 1,
      deletedAt: map['deleted_at'],
    );
  }
}
