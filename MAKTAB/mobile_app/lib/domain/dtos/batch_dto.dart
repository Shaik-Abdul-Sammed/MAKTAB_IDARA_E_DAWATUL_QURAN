class BatchDTO {
  final int? id;
  final String name;
  final String timing;
  final int? teacherId;

  BatchDTO({
    this.id,
    required this.name,
    required this.timing,
    this.teacherId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'timing': timing,
    'teacher_id': teacherId,
  };

  factory BatchDTO.fromMap(Map<String, dynamic> map) => BatchDTO(
    id: map['id'],
    name: map['name'],
    timing: map['timing'],
    teacherId: map['teacher_id'],
  );
}