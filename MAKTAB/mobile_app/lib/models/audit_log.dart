class AuditLog {
  final int? id;
  final String action; // e.g. 'UPDATE_ATTENDANCE'
  final String entityType; // e.g. 'Attendance'
  final int entityId;
  final String details; // JSON of what changed
  final String timestamp;
  final String? performedBy; // Role or Teacher ID

  AuditLog({
    this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
    this.performedBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'details': details,
    'timestamp': timestamp,
    'performed_by': performedBy,
  };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'],
    action: map['action'],
    entityType: map['entity_type'],
    entityId: map['entity_id'],
    details: map['details'],
    timestamp: map['timestamp'],
    performedBy: map['performed_by'],
  );
}