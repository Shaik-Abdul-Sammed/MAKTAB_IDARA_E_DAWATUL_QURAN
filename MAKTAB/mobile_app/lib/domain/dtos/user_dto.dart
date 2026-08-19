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
  );
}