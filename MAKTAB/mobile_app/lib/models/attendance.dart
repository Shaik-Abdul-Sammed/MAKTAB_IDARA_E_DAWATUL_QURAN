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
    return Attendance(
      id: map['id'],
      studentId: map['student_id'],
      date: map['date'],
      status: map['status'],
      remarks: map['remarks'],
      time: map['time'],
    );
  }
}
