class AuthDTO {
  final String token;
  final String role;
  final String expiry;

  AuthDTO({
    required this.token,
    required this.role,
    required this.expiry,
  });

  Map<String, dynamic> toMap() => {
    'token': token,
    'role': role,
    'expiry': expiry,
  };

  factory AuthDTO.fromMap(Map<String, dynamic> map) => AuthDTO(
    token: map['token'],
    role: map['role'],
    expiry: map['expiry'],
  );
}