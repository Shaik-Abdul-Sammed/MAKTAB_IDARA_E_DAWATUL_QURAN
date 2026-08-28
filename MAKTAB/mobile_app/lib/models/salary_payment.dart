class SalaryPayment {
  final int? id;
  final int teacherId;
  final String maktabId;
  final String salaryMonth; // Format: "YYYY-MM" (e.g. "2026-08")
  final int amount;
  final String paymentDate; // Format: "YYYY-MM-DD"
  final String paymentMode; // "UPI", "Bank Transfer", "Cash", "Other"
  final String? upiIdSnapshot;
  final String? transactionReference;
  final String status; // "PAID", "PARTIALLY PAID", "PENDING"
  final String? notes;
  final String createdAt;
  final String updatedAt;

  SalaryPayment({
    this.id,
    required this.teacherId,
    required this.maktabId,
    required this.salaryMonth,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    this.upiIdSnapshot,
    this.transactionReference,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'maktab_id': maktabId,
      'salary_month': salaryMonth,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_mode': paymentMode,
      'upi_id_snapshot': upiIdSnapshot,
      'transaction_reference': transactionReference,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory SalaryPayment.fromMap(Map<String, dynamic> map) {
    return SalaryPayment(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? ''),
      teacherId: map['teacher_id'] is int ? map['teacher_id'] : (int.tryParse(map['teacher_id']?.toString() ?? '') ?? 0),
      maktabId: map['maktab_id']?.toString() ?? 'MAKTAB-001',
      salaryMonth: map['salary_month']?.toString() ?? '',
      amount: map['amount'] is int ? map['amount'] : (int.tryParse(map['amount']?.toString() ?? '') ?? 0),
      paymentDate: map['payment_date']?.toString() ?? '',
      paymentMode: map['payment_mode']?.toString() ?? 'Cash',
      upiIdSnapshot: map['upi_id_snapshot']?.toString(),
      transactionReference: map['transaction_reference']?.toString(),
      status: map['status']?.toString() ?? 'PAID',
      notes: map['notes']?.toString(),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  SalaryPayment copyWith({
    int? id,
    int? teacherId,
    String? maktabId,
    String? salaryMonth,
    int? amount,
    String? paymentDate,
    String? paymentMode,
    String? upiIdSnapshot,
    String? transactionReference,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return SalaryPayment(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      maktabId: maktabId ?? this.maktabId,
      salaryMonth: salaryMonth ?? this.salaryMonth,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMode: paymentMode ?? this.paymentMode,
      upiIdSnapshot: upiIdSnapshot ?? this.upiIdSnapshot,
      transactionReference: transactionReference ?? this.transactionReference,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
