class QuranProgress {
  final int? id;
  final int studentId;
  final int? teacherId;
  final String date;
  final String surah;
  final int ayahFrom;
  final int ayahTo;
  final String grade; // 'A+', 'A', 'B', 'C'
  final String recitationType; // 'Sabaq', 'Sabaqi', 'Manzil'
  final String? remarks;

  QuranProgress({
    this.id,
    required this.studentId,
    this.teacherId,
    required this.date,
    required this.surah,
    required this.ayahFrom,
    required this.ayahTo,
    required this.grade,
    this.recitationType = 'Sabaq',
    this.remarks,
  });

  QuranProgress copyWith({
    int? id,
    int? studentId,
    int? teacherId,
    String? date,
    String? surah,
    int? ayahFrom,
    int? ayahTo,
    String? grade,
    String? recitationType,
    String? remarks,
  }) {
    return QuranProgress(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      date: date ?? this.date,
      surah: surah ?? this.surah,
      ayahFrom: ayahFrom ?? this.ayahFrom,
      ayahTo: ayahTo ?? this.ayahTo,
      grade: grade ?? this.grade,
      recitationType: recitationType ?? this.recitationType,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'date': date,
      'surah': surah,
      'ayah_from': ayahFrom,
      'ayah_to': ayahTo,
      'grade': grade,
      'recitation_type': recitationType,
      'remarks': remarks,
    };
  }

  factory QuranProgress.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return QuranProgress(
      id: parseInt(map['id']),
      studentId: parseInt(map['student_id'] ?? map['studentId']) ?? 0,
      teacherId: parseInt(map['teacher_id'] ?? map['teacherId']),
      date: (map['date'] ?? '').toString(),
      surah: (map['surah'] ?? '').toString(),
      ayahFrom: parseInt(map['ayah_from'] ?? map['ayahFrom']) ?? 1,
      ayahTo: parseInt(map['ayah_to'] ?? map['ayahTo']) ?? 1,
      grade: (map['grade'] ?? 'A').toString(),
      recitationType: (map['recitation_type'] ?? map['recitationType'] ?? 'Sabaq').toString(),
      remarks: map['remarks']?.toString(),
    );
  }
}
