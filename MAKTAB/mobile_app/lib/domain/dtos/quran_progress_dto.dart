class QuranProgressDTO {
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
}