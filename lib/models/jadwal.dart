// lib/models/jadwal.dart
// Model untuk data jadwal dari endpoint GET /jadwal/hari-ini dan GET /jadwal/mingguan
// Memetakan schema JadwalItem dari backend FastAPI (app/schemas/home.py)

import 'package:flutter/foundation.dart';

/// Model satu mata kuliah dalam jadwal.
/// Sesuai dengan JadwalItem di app/schemas/home.py
class JadwalModel {
  final String matakuliahId;
  final String kode;
  final String nama;
  final int sks;

  // Jadwal reguler
  final String? hari;
  final String? jamMulai;    // format "HH:MM"
  final String? jamSelesai;  // format "HH:MM"
  final String? ruangan;

  // Status presensi hari ini (null = belum ada sesi / bukan hari ini)
  // Nilai: 'hadir' | 'terlambat' | 'absen' | null
  final String? statusPresensi;

  // Flag sesi aktif — apakah dosen sudah membuka sesi sekarang
  final bool adaSesiAktif;

  // UUID sesi jika aktif (langsung bisa dipakai untuk presensi)
  final String? sesiId;

  const JadwalModel({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    this.statusPresensi,
    this.adaSesiAktif = false,
    this.sesiId,
  });

  // ── Factory dari JSON response backend ─────────────────────
  factory JadwalModel.fromJson(Map<String, dynamic> json) {
    return JadwalModel(
      matakuliahId   : json['matakuliah_id']  as String,
      kode           : json['kode']           as String,
      nama           : json['nama']           as String,
      sks            : json['sks']            as int,
      hari           : json['hari']           as String?,
      jamMulai       : json['jam_mulai']      as String?,
      jamSelesai     : json['jam_selesai']    as String?,
      ruangan        : json['ruangan']        as String?,
      statusPresensi : json['status_presensi'] as String?,
      adaSesiAktif   : json['ada_sesi_aktif'] as bool? ?? false,
      sesiId         : json['sesi_id']        as String?,
    );
  }

  // ── Serialisasi ke Map (untuk keperluan debugging/cache) ───
  Map<String, dynamic> toJson() => {
    'matakuliah_id'  : matakuliahId,
    'kode'           : kode,
    'nama'           : nama,
    'sks'            : sks,
    'hari'           : hari,
    'jam_mulai'      : jamMulai,
    'jam_selesai'    : jamSelesai,
    'ruangan'        : ruangan,
    'status_presensi': statusPresensi,
    'ada_sesi_aktif' : adaSesiAktif,
    'sesi_id'        : sesiId,
  };

  // ── Helper getters ─────────────────────────────────────────

  /// Label jam lengkap, contoh: "08:00 – 09:40"
  String get labelJam {
    if (jamMulai == null && jamSelesai == null) return '-';
    final mulai   = jamMulai   ?? '?';
    final selesai = jamSelesai ?? '?';
    return '$mulai – $selesai';
  }

  /// Apakah mahasiswa sudah presensi di sesi hari ini?
  bool get sudahPresensi =>
      statusPresensi == 'hadir' || statusPresensi == 'terlambat';

  /// Apakah mahasiswa tercatat absen / izin / sakit?
  bool get ketidakhadiran =>
      statusPresensi == 'absen' ||
      statusPresensi == 'izin'  ||
      statusPresensi == 'sakit';

  /// Tampilkan label status presensi yang ramah pengguna
  String get labelStatus {
    switch (statusPresensi) {
      case 'hadir'    : return 'Hadir';
      case 'terlambat': return 'Terlambat';
      case 'absen'    : return 'Absen';
      case 'izin'     : return 'Izin';
      case 'sakit'    : return 'Sakit';
      default         : return adaSesiAktif ? 'Belum Presensi' : 'Belum Ada Sesi';
    }
  }

  @override
  String toString() => 'JadwalModel($kode – $nama, $hari $labelJam)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JadwalModel &&
          runtimeType == other.runtimeType &&
          matakuliahId == other.matakuliahId;

  @override
  int get hashCode => matakuliahId.hashCode;
}

// ─────────────────────────────────────────────────────────────
// Model untuk response GET /jadwal/mingguan
// Backend mengembalikan Map<String, List<JadwalItem>> dikelompokkan per hari
// ─────────────────────────────────────────────────────────────

class JadwalMingguanModel {
  /// Key: nama hari ('Senin', 'Selasa', dst.)
  /// Value: list matakuliah di hari tersebut
  final Map<String, List<JadwalModel>> perHari;

  const JadwalMingguanModel({required this.perHari});

  factory JadwalMingguanModel.fromJson(Map<String, dynamic> json) {
    final map = <String, List<JadwalModel>>{};
    for (final entry in json.entries) {
      final list = (entry.value as List<dynamic>)
          .map((item) => JadwalModel.fromJson(item as Map<String, dynamic>))
          .toList();
      map[entry.key] = list;
    }
    return JadwalMingguanModel(perHari: map);
  }

  /// Urutan hari yang benar (Senin → Minggu)
  static const List<String> urutan = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  /// Jadwal untuk hari tertentu (default: list kosong jika tidak ada)
  List<JadwalModel> hariIni(String namaHari) => perHari[namaHari] ?? [];

  /// Total matakuliah di semua hari
  int get totalMatakuliah =>
      perHari.values.fold(0, (sum, list) => sum + list.length);
}