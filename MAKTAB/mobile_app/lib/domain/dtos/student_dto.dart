class StudentDTO {
  final int? id;
  final String admissionNumber;
  final String name;
  final String? arabicName;
  final String? dob;
  final String? gender;
  final String? fatherName;
  final String? phone;
  final int? batchId;
  final String createdAt;

  StudentDTO({
    this.id,
    required this.admissionNumber,
    required this.name,
    this.arabicName,
    this.dob,
    this.gender,
    this.fatherName,
    this.phone,
    this.batchId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'admission_number': admissionNumber,
    'name': name,
    'arabic_name': arabicName,
    'dob': dob,
    'gender': gender,
    'father_name': fatherName,
    'phone': phone,
    'batch_id': batchId,
    'created_at': createdAt,
  };

  factory StudentDTO.fromMap(Map<String, dynamic> map) => StudentDTO(
    id: map['id'],
    admissionNumber: map['admission_number'],
    name: map['name'],
    arabicName: map['arabic_name'],
    dob: map['dob'],
    gender: map['gender'],
    fatherName: map['father_name'],
    phone: map['phone'],
    batchId: map['batch_id'],
    createdAt: map['created_at'],
  );
}