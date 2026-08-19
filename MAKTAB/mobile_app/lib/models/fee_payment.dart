class FeePayment {
  final int? id;
  final int studentId;
  final int amount;
  final String mode;
  final String timestamp;
  final String? notes;
  final String? voiceNotePath;

  FeePayment({
    this.id,
    required this.studentId,
    required this.amount,
    required this.mode,
    required this.timestamp,
    this.notes,
    this.voiceNotePath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'amount': amount,
      'mode': mode,
      'timestamp': timestamp,
      if (notes != null) 'notes': notes,
      if (voiceNotePath != null) 'voice_note_path': voiceNotePath,
    };
  }

  factory FeePayment.fromMap(Map<String, dynamic> map) {
    return FeePayment(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      amount: map['amount'] as int,
      mode: map['mode'] as String,
      timestamp: map['timestamp'] as String,
      notes: map['notes'] as String?,
      voiceNotePath: map['voice_note_path'] as String?,
    );
  }

  FeePayment copyWith({
    int? id,
    int? studentId,
    int? amount,
    String? mode,
    String? timestamp,
    String? notes,
    String? voiceNotePath,
  }) {
    return FeePayment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
    );
  }
}
