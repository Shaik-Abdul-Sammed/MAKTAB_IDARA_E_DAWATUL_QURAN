class UserDTO {
  final int? id;
  final String name;
  final String pinHash;
  final String role;
  final String createdAt;
  final String? mobile;
  final bool isActive;
  final String? photoPath;
  final String? dob;
  final int? monthlySalary;
  final String? upiId;
  final String? preferredPaymentMode;

  UserDTO({
    this.id,
    required this.name,
    required this.pinHash,
    required this.role,
    required this.createdAt,
    this.mobile,
    this.isActive = true,
    this.photoPath,
    this.dob,
    this.monthlySalary,
    this.upiId,
    this.preferredPaymentMode,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pin_hash': pinHash,
    'role': role,
    'created_at': createdAt,
    'mobile': mobile,
    'is_active': isActive ? 1 : 0,
    'photo_path': photoPath,
    'dob': dob,
    'monthly_salary': monthlySalary ?? 0,
    'upi_id': upiId,
    'preferred_payment_mode': preferredPaymentMode,
  };

  factory UserDTO.fromMap(Map<String, dynamic> map) => UserDTO(
    id: map['id'],
    name: map['name'],
    pinHash: map['pin_hash'],
    role: map['role'],
    createdAt: map['created_at'],
    mobile: map['mobile'],
    isActive: map['is_active'] == 1,
    photoPath: map['photo_path'],
    dob: map['dob'],
    monthlySalary: map['monthly_salary'] as int? ?? 0,
    upiId: map['upi_id'] as String?,
    preferredPaymentMode: map['preferred_payment_mode'] as String?,
  );
}