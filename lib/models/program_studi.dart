// lib/models/program_studi.dart
// v2.1.0 — Model Program Studi terstruktur (Fase D backend)
// Endpoint: GET /program-studi/aktif

class ProgramStudiModel {
  final String  id;
  final String  kode;
  final String  nama;
  final String  fakultas;
  final String  jenjang;    // 'D3' | 'D4' | 'S1' | 'S2' | 'S3'
  final bool    isActive;

  const ProgramStudiModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.fakultas,
    required this.jenjang,
    required this.isActive,
  });

  factory ProgramStudiModel.fromJson(Map<String, dynamic> json) {
    return ProgramStudiModel(
      id      : json['id']       as String,
      kode    : json['kode']     as String? ?? '',
      nama    : json['nama']     as String? ?? '',
      fakultas: json['fakultas'] as String? ?? '',
      jenjang : json['jenjang']  as String? ?? 'S1',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id'      : id,
    'kode'    : kode,
    'nama'    : nama,
    'fakultas': fakultas,
    'jenjang' : jenjang,
    'is_active': isActive,
  };

  /// Label lengkap untuk dropdown: "S1 - Teknik Informatika"
  String get labelDropdown => '$jenjang – $nama';

  /// Label singkat: "TIF (S1)"
  String get labelSingkat => '$kode ($jenjang)';

  @override
  String toString() => labelDropdown;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramStudiModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}