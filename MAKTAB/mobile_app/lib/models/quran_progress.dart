class QuranProgress {
  final int? id;
  final int studentId;
  final String date;
  final String surah;
  final int ayahFrom;
  final int ayahTo;
  final String grade; // 'A+', 'A', 'B', 'C'
  final String? remarks;

  QuranProgress({
    this.id,
    required this.studentId,
    required this.date,
    required this.surah,
    required this.ayahFrom,
    required this.ayahTo,
    required this.grade,
    this.remarks,
  });

  QuranProgress copyWith({
    int? id,
    int? studentId,
    String? date,
    String? surah,
    int? ayahFrom,
    int? ayahTo,
    String? grade,
    String? remarks,
  }) {
    return QuranProgress(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      surah: surah ?? this.surah,
      ayahFrom: ayahFrom ?? this.ayahFrom,
      ayahTo: ayahTo ?? this.ayahTo,
      grade: grade ?? this.grade,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date,
      'surah': surah,
      'ayah_from': ayahFrom,
      'ayah_to': ayahTo,
      'grade': grade,
      'remarks': remarks,
    };
  }

  factory QuranProgress.fromMap(Map<String, dynamic> map) {
    return QuranProgress(
      id: map['id'],
      studentId: map['student_id'],
      date: map['date'],
      surah: map['surah'],
      ayahFrom: map['ayah_from'],
      ayahTo: map['ayah_to'],
      grade: map['grade'],
      remarks: map['remarks'],
    );
  }
}
