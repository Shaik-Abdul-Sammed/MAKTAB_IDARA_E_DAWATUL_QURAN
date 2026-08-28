class Attendance {
  final int? id;
  final int studentId;
  final String date; // YYYY-MM-DD
  final String status; // 'Present', 'Absent', 'Leave', 'Late'
  final String? remarks;
  final String? time; // e.g. "08:30 AM"

  Attendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
    this.time,
  });

  Attendance copyWith({
    int? id,
    int? studentId,
    String? date,
    String? status,
    String? remarks,
    String? time,
  }) {
    return Attendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'date': date,
      'status': status,
      'remarks': remarks,
      'time': time,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    int? rawId;
    if (map['id'] != null) {
      rawId = int.tryParse(map['id'].toString());
    }
    int sId = 0;
    final rawStudentId = map['student_id'] ?? map['studentId'];
    if (rawStudentId != null) {
      sId = int.tryParse(rawStudentId.toString()) ?? 0;
    }

    String rawDate = (map['date'] ?? DateTime.now().toIso8601String()).toString().trim();
    if (rawDate.length >= 10) {
      rawDate = rawDate.substring(0, 10);
    }

    return Attendance(
      id: rawId,
      studentId: sId,
      date: rawDate,
      status: (map['status'] ?? 'Present').toString(),
      remarks: map['remarks']?.toString(),
      time: map['time']?.toString(),
    );
  }
}
