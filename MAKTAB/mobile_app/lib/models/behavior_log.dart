class BehaviorLog {
  final int? id;
  final int studentId;
  final int teacherId;
  final String date;
  final String incident;
  final String? actionTaken;

  BehaviorLog({this.id, required this.studentId, required this.teacherId, required this.date, required this.incident, this.actionTaken});

  Map<String, dynamic> toMap() => {'id': id, 'student_id': studentId, 'teacher_id': teacherId, 'date': date, 'incident': incident, 'action_taken': actionTaken};
  factory BehaviorLog.fromMap(Map<String, dynamic> map) => BehaviorLog(
    id: map['id'], studentId: map['student_id'], teacherId: map['teacher_id'], date: map['date'], incident: map['incident'], actionTaken: map['action_taken']
  );
}