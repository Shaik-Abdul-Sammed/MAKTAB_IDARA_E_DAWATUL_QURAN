class TeacherAttendance {
  final int? id;
  final int teacherId;
  final String date; // yyyy-MM-dd
  final String status; // Present, Absent, Late, Leave
  final String? remarks;
  final int? markedBy; // Admin user ID
  final String? time; // e.g. "08:30 AM"

  TeacherAttendance({
    this.id,
    required this.teacherId,
    required this.date,
    required this.status,
    this.remarks,
    this.markedBy,
    this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'date': date,
      'status': status,
      'remarks': remarks,
      'marked_by': markedBy,
      'time': time,
    };
  }

  factory TeacherAttendance.fromMap(Map<String, dynamic> map) {
    return TeacherAttendance(
      id: map['id'],
      teacherId: map['teacher_id'],
      date: map['date'],
      status: map['status'],
      remarks: map['remarks'],
      markedBy: map['marked_by'],
      time: map['time'],
    );
  }

  TeacherAttendance copyWith({
    int? id,
    int? teacherId,
    String? date,
    String? status,
    String? remarks,
    int? markedBy,
    String? time,
  }) {
    return TeacherAttendance(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      markedBy: markedBy ?? this.markedBy,
      time: time ?? this.time,
    );
  }
}
