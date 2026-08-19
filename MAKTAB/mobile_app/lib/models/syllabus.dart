class SyllabusItem {
  final int? id;
  final String topic;
  final String description;
  final int batchId;
  final String status; // Pending, In Progress, Completed

  SyllabusItem({this.id, required this.topic, required this.description, required this.batchId, required this.status});

  Map<String, dynamic> toMap() => {'id': id, 'topic': topic, 'description': description, 'batch_id': batchId, 'status': status};
  factory SyllabusItem.fromMap(Map<String, dynamic> map) => SyllabusItem(
    id: map['id'], topic: map['topic'], description: map['description'], batchId: map['batch_id'], status: map['status']
  );
}