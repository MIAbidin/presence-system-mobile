// lib/models/user.dart
// v2.1.0 — Tambah programStudiId, kelasId

class UserModel {
  final String id;
  final String nimNidn;
  final String namaLengkap;
  final String email;
  final String role;           // 'mahasiswa' | 'dosen' | 'admin' | 'super_admin'
  final String programStudi;   // String lama (backward compat)
  final bool   isFaceRegistered;

  // ── [BARU v2.1.0] ────────────────────────────────────────
  /// UUID program studi terstruktur (Fase D backend)
  final String? programStudiId;

  /// UUID kelas yang diambil mahasiswa (null jika dosen/admin)
  final String? kelasId;

  /// Kode kelas (A/B/C) yang diambil mahasiswa
  final String? kodeKelas;

  UserModel({
    required this.id,
    required this.nimNidn,
    required this.namaLengkap,
    required this.email,
    required this.role,
    required this.programStudi,
    required this.isFaceRegistered,
    // Baru
    this.programStudiId,
    this.kelasId,
    this.kodeKelas,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id               : json['id']                as String,
      nimNidn          : json['nim_nidn']           as String,
      namaLengkap      : json['nama_lengkap']       as String,
      email            : json['email']              as String,
      role             : json['role']               as String,
      programStudi     : json['program_studi']      as String? ?? '',
      isFaceRegistered : json['is_face_registered'] as bool?   ?? false,
      // Baru
      programStudiId   : json['program_studi_id']   as String?,
      kelasId          : json['kelas_id']           as String?,
      kodeKelas        : json['kode_kelas']         as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id'                : id,
    'nim_nidn'          : nimNidn,
    'nama_lengkap'      : namaLengkap,
    'email'             : email,
    'role'              : role,
    'program_studi'     : programStudi,
    'is_face_registered': isFaceRegistered,
    'program_studi_id'  : programStudiId,
    'kelas_id'          : kelasId,
    'kode_kelas'        : kodeKelas,
  };

  // ── Role helpers ──────────────────────────────────────────
  bool get isMahasiswa => role == 'mahasiswa';
  bool get isDosen     => role == 'dosen';
  bool get isAdmin     => role == 'admin';
  bool get isSuperAdmin=> role == 'super_admin';

  /// Inisial nama (maks 2 huruf) untuk avatar
  String get inisial {
    final parts = namaLengkap.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (namaLengkap.isNotEmpty) return namaLengkap[0].toUpperCase();
    return '?';
  }

  /// Nama depan saja
  String get namaDepan => namaLengkap.split(' ').first;

  // ── copyWith ──────────────────────────────────────────────
  UserModel copyWith({
    String? id,
    String? nimNidn,
    String? namaLengkap,
    String? email,
    String? role,
    String? programStudi,
    bool?   isFaceRegistered,
    String? programStudiId,
    String? kelasId,
    String? kodeKelas,
  }) {
    return UserModel(
      id               : id               ?? this.id,
      nimNidn          : nimNidn          ?? this.nimNidn,
      namaLengkap      : namaLengkap      ?? this.namaLengkap,
      email            : email            ?? this.email,
      role             : role             ?? this.role,
      programStudi     : programStudi     ?? this.programStudi,
      isFaceRegistered : isFaceRegistered ?? this.isFaceRegistered,
      programStudiId   : programStudiId   ?? this.programStudiId,
      kelasId          : kelasId          ?? this.kelasId,
      kodeKelas        : kodeKelas        ?? this.kodeKelas,
    );
  }
}