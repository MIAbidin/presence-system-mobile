// lib/models/user.dart

class UserModel {
  final String id;
  final String nimNidn;
  final String namaLengkap;
  final String email;
  final String role;           // 'mahasiswa' | 'dosen' | 'admin'
  final String programStudi;
  final bool   isFaceRegistered;

  UserModel({
    required this.id,
    required this.nimNidn,
    required this.namaLengkap,
    required this.email,
    required this.role,
    required this.programStudi,
    required this.isFaceRegistered,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id              : json['id'],
      nimNidn         : json['nim_nidn'],
      namaLengkap     : json['nama_lengkap'],
      email           : json['email'],
      role            : json['role'],
      programStudi    : json['program_studi'],
      isFaceRegistered: json['is_face_registered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id'               : id,
    'nim_nidn'         : nimNidn,
    'nama_lengkap'     : namaLengkap,
    'email'            : email,
    'role'             : role,
    'program_studi'    : programStudi,
    'is_face_registered': isFaceRegistered,
  };

  // ── Role helpers ──────────────────────────────────────────
  bool get isMahasiswa => role == 'mahasiswa';
  bool get isDosen     => role == 'dosen';
  bool get isAdmin     => role == 'admin';
}