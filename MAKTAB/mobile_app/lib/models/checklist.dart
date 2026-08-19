class ChecklistQuestion {
  final int? id;
  final String text;
  final String category;
  final int isActive;

  ChecklistQuestion({this.id, required this.text, required this.category, this.isActive = 1});

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'category': category, 'is_active': isActive};
  factory ChecklistQuestion.fromMap(Map<String, dynamic> map) => ChecklistQuestion(
    id: map['id'], text: map['text'], category: map['category'], isActive: map['is_active']
  );
}

class ChecklistSubmission {
  final int? id;
  final int teacherId;
  final int batchId;
  final String date;
  final String answersJson; // JSON string mapping question ID to boolean
  final String? remarks;

  ChecklistSubmission({this.id, required this.teacherId, required this.batchId, required this.date, required this.answersJson, this.remarks});

  Map<String, dynamic> toMap() => {'id': id, 'teacher_id': teacherId, 'batch_id': batchId, 'date': date, 'answers_json': answersJson, 'remarks': remarks};
  factory ChecklistSubmission.fromMap(Map<String, dynamic> map) => ChecklistSubmission(
    id: map['id'], teacherId: map['teacher_id'], batchId: map['batch_id'], date: map['date'], answersJson: map['answers_json'], remarks: map['remarks']
  );
}
