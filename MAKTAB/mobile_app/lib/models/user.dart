class User {
  final int? id;
  final String name;
  final String pinHash; // We will store hashed PIN
  final String role; // 'admin' or 'teacher'
  final bool isActive;
  final String createdAt;
  final String? mobile; // Mobile number used for registration/identity
  final String? photoPath;
  final String? dob; // Date of birth (YYYY-MM-DD)
  final int? monthlySalary;
  final String? upiId;
  final String? preferredPaymentMode;

  User({
    this.id,
    required this.name,
    required this.pinHash,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.mobile,
    this.photoPath,
    this.dob,
    this.monthlySalary,
    this.upiId,
    this.preferredPaymentMode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pin_hash': pinHash,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'mobile': mobile,
      'photo_path': photoPath,
      'dob': dob,
      'monthly_salary': monthlySalary ?? 0,
      'upi_id': upiId,
      'preferred_payment_mode': preferredPaymentMode,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    int? rawId;
    final rawIdVal = map['id'] ?? map['teacherId'] ?? map['teacher_id'];
    if (rawIdVal != null) {
      rawId = int.tryParse(rawIdVal.toString());
    }

    final activeVal = map['is_active'] ?? map['isActive'] ?? map['active'];
    final bool active = activeVal == true || activeVal == 1 || activeVal == '1';

    return User(
      id: rawId,
      name: (map['name'] ?? 'User').toString(),
      pinHash: (map['pin_hash'] ?? map['pinHash'] ?? '').toString(),
      role: (map['role'] ?? 'teacher').toString(),
      isActive: active,
      createdAt: (map['created_at'] ?? map['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      mobile: map['mobile']?.toString(),
      photoPath: (map['photo_path'] ?? map['photoPath'])?.toString(),
      dob: map['dob']?.toString(),
      monthlySalary: map['monthly_salary'] != null ? int.tryParse(map['monthly_salary'].toString()) : (map['monthlySalary'] != null ? int.tryParse(map['monthlySalary'].toString()) : 0),
      upiId: (map['upi_id'] ?? map['upiId'])?.toString(),
      preferredPaymentMode: (map['preferred_payment_mode'] ?? map['preferredPaymentMode'])?.toString(),
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? pinHash,
    String? role,
    bool? isActive,
    String? createdAt,
    String? mobile,
    String? photoPath,
    String? dob,
    int? monthlySalary,
    String? upiId,
    String? preferredPaymentMode,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      pinHash: pinHash ?? this.pinHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      mobile: mobile ?? this.mobile,
      photoPath: photoPath ?? this.photoPath,
      dob: dob ?? this.dob,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      upiId: upiId ?? this.upiId,
      preferredPaymentMode: preferredPaymentMode ?? this.preferredPaymentMode,
    );
  }
}

