class QueueItem {
  final int? id;
  final String action; // e.g., 'INSERT_ATTENDANCE'
  final String payload; // JSON string of the data
  final String status; // 'PENDING', 'FAILED', 'COMPLETED'
  final String createdAt;

  QueueItem({
    this.id,
    required this.action,
    required this.payload,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'payload': payload,
    'status': status,
    'created_at': createdAt,
  };

  factory QueueItem.fromMap(Map<String, dynamic> map) => QueueItem(
    id: map['id'],
    action: map['action'],
    payload: map['payload'],
    status: map['status'],
    createdAt: map['created_at'],
  );
}