class FeeHandover {
  final int? id;
  final int teacherId; // who handed over
  final int? managerId; // who received (null/0 if not yet known)
  final int amount; // in rupees
  final String mode; // Cash | UPI | Bank Transfer | Cheque | Online
  final String timestamp; // ISO-8601, user-editable
  final String? reference; // UTR / cheque no. / receipt no.
  final String? notes;
  final int receiptSent; // 0/1
  final String? receiptSentAt;
  final int isSynced; // 0/1

  FeeHandover({
    this.id,
    required this.teacherId,
    this.managerId,
    required this.amount,
    required this.mode,
    required this.timestamp,
    this.reference,
    this.notes,
    this.receiptSent = 0,
    this.receiptSentAt,
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'teacher_id': teacherId,
      if (managerId != null) 'manager_id': managerId,
      'amount': amount,
      'mode': mode,
      'timestamp': timestamp,
      if (reference != null) 'reference': reference,
      if (notes != null) 'notes': notes,
      'receipt_sent': receiptSent,
      if (receiptSentAt != null) 'receipt_sent_at': receiptSentAt,
      'is_synced': isSynced,
    };
  }

  factory FeeHandover.fromMap(Map<String, dynamic> map) {
    return FeeHandover(
      id: map['id'] as int?,
      teacherId: map['teacher_id'] as int,
      managerId: map['manager_id'] as int?,
      amount: map['amount'] as int,
      mode: (map['mode'] ?? 'Cash') as String,
      timestamp: (map['timestamp'] ?? DateTime.now().toIso8601String()) as String,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      receiptSent: (map['receipt_sent'] as int?) ?? 0,
      receiptSentAt: map['receipt_sent_at'] as String?,
      isSynced: (map['is_synced'] as int?) ?? 0,
    );
  }

  FeeHandover copyWith({
    int? id,
    int? teacherId,
    int? managerId,
    int? amount,
    String? mode,
    String? timestamp,
    String? reference,
    String? notes,
    int? receiptSent,
    String? receiptSentAt,
    int? isSynced,
  }) {
    return FeeHandover(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      managerId: managerId ?? this.managerId,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      timestamp: timestamp ?? this.timestamp,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      receiptSent: receiptSent ?? this.receiptSent,
      receiptSentAt: receiptSentAt ?? this.receiptSentAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
