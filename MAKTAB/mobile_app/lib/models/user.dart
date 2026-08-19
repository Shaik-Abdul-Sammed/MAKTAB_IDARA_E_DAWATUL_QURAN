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
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      pinHash: map['pin_hash'],
      role: map['role'],
      isActive: map['is_active'] == 1,
      createdAt: map['created_at'],
      mobile: map['mobile'],
      photoPath: map['photo_path'],
      dob: map['dob'],
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
    );
  }
}

