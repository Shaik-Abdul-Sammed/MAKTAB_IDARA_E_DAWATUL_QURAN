class Batch {
  final int? id;
  final String name;
  final String timing;
  final int? teacherId;

  Batch({
    this.id,
    required this.name,
    required this.timing,
    this.teacherId,
  });

  Batch copyWith({
    int? id,
    String? name,
    String? timing,
    int? teacherId,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      timing: timing ?? this.timing,
      teacherId: teacherId ?? this.teacherId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'timing': timing,
      'teacher_id': teacherId,
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'],
      name: map['name'],
      timing: map['timing'],
      teacherId: map['teacher_id'],
    );
  }
}
