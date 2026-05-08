// lib/models/jadwal.dart
// v2.1.0 — Tambah kelasId, kodeKelas, dosenNama, slotMulai, slotSelesai, modePengganti
// Sesuai schema JadwalItem dari backend FastAPI (app/schemas/home.py)

/// Model satu mata kuliah dalam jadwal mahasiswa.
class JadwalModel {
  final String matakuliahId;
  final String kode;
  final String nama;
  final int    sks;

  // Jadwal reguler
  final String? hari;
  final String? jamMulai;    // format "HH:MM"
  final String? jamSelesai;  // format "HH:MM"
  final String? ruangan;

  // Status presensi hari ini
  // Nilai: 'hadir' | 'terlambat' | 'absen' | null
  final String? statusPresensi;

  // Flag sesi aktif
  final bool    adaSesiAktif;
  final String? sesiId;

  // ── [BARU v2.1.0] Kelas ───────────────────────────────────
  /// UUID kelas yang diambil mahasiswa ini
  final String? kelasId;

  /// Kode kelas (A/B/C)
  final String? kodeKelas;

  /// Nama dosen pengampu kelas ini
  final String? dosenNama;

  /// Slot mulai (1-12) — untuk SlotLabel widget
  final int? slotMulai;

  /// Slot selesai (1-12) — untuk SlotLabel widget
  final int? slotSelesai;

  // ── [BARU v2.1.0] Jadwal Pengganti ───────────────────────
  /// Flag: apakah ada jadwal pengganti untuk pertemuan terdekat
  final bool    adaJadwalPengganti;
  final String? jamMulaiPengganti;
  final String? jamSelesaiPengganti;
  final String? ruanganPengganti;

  /// Mode efektif dari jadwal pengganti (offline/online)
  /// null jika tidak ada jadwal pengganti
  final String? modePengganti;

  // ── [BARU v2.1.0] Tamu ───────────────────────────────────
  /// True jika mahasiswa masuk kelas ini sebagai tamu
  final bool isTamu;

  /// Nama kelas asal jika adalah tamu
  final String? kelasAsalNama;

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
    // Baru
    this.kelasId,
    this.kodeKelas,
    this.dosenNama,
    this.slotMulai,
    this.slotSelesai,
    this.adaJadwalPengganti = false,
    this.jamMulaiPengganti,
    this.jamSelesaiPengganti,
    this.ruanganPengganti,
    this.modePengganti,
    this.isTamu = false,
    this.kelasAsalNama,
  });

  factory JadwalModel.fromJson(Map<String, dynamic> json) {
    return JadwalModel(
      matakuliahId      : json['matakuliah_id']          as String,
      kode              : json['kode']                   as String,
      nama              : json['nama']                   as String,
      sks               : json['sks']                    as int,
      hari              : json['hari']                   as String?,
      jamMulai          : json['jam_mulai']              as String?,
      jamSelesai        : json['jam_selesai']            as String?,
      ruangan           : json['ruangan']                as String?,
      statusPresensi    : json['status_presensi']        as String?,
      adaSesiAktif      : json['ada_sesi_aktif']         as bool? ?? false,
      sesiId            : json['sesi_id']                as String?,
      // Baru
      kelasId           : json['kelas_id']               as String?,
      kodeKelas         : json['kode_kelas']             as String?,
      dosenNama         : json['dosen_nama']             as String?,
      slotMulai         : json['slot_mulai']             as int?,
      slotSelesai       : json['slot_selesai']           as int?,
      adaJadwalPengganti: json['ada_jadwal_pengganti']   as bool? ?? false,
      jamMulaiPengganti : json['jam_mulai_pengganti']    as String?,
      jamSelesaiPengganti: json['jam_selesai_pengganti'] as String?,
      ruanganPengganti  : json['ruangan_pengganti']      as String?,
      modePengganti     : json['mode_pengganti']         as String?,
      isTamu            : json['is_tamu']                as bool? ?? false,
      kelasAsalNama     : json['kelas_asal_nama']        as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'matakuliah_id'      : matakuliahId,
    'kode'               : kode,
    'nama'               : nama,
    'sks'                : sks,
    'hari'               : hari,
    'jam_mulai'          : jamMulai,
    'jam_selesai'        : jamSelesai,
    'ruangan'            : ruangan,
    'status_presensi'    : statusPresensi,
    'ada_sesi_aktif'     : adaSesiAktif,
    'sesi_id'            : sesiId,
    'kelas_id'           : kelasId,
    'kode_kelas'         : kodeKelas,
    'dosen_nama'         : dosenNama,
    'slot_mulai'         : slotMulai,
    'slot_selesai'       : slotSelesai,
    'ada_jadwal_pengganti': adaJadwalPengganti,
    'jam_mulai_pengganti' : jamMulaiPengganti,
    'jam_selesai_pengganti': jamSelesaiPengganti,
    'ruangan_pengganti'   : ruanganPengganti,
    'mode_pengganti'      : modePengganti,
    'is_tamu'             : isTamu,
    'kelas_asal_nama'     : kelasAsalNama,
  };

  // ── Helper getters ─────────────────────────────────────────

  /// Label jam efektif (prioritas jadwal pengganti)
  String get labelJam {
    if (adaJadwalPengganti) {
      final mulai   = jamMulaiPengganti   ?? jamMulai   ?? '?';
      final selesai = jamSelesaiPengganti ?? jamSelesai ?? '?';
      return '$mulai – $selesai';
    }
    final mulai   = jamMulai   ?? '-';
    final selesai = jamSelesai ?? '-';
    return '$mulai – $selesai';
  }

  /// Ruangan efektif (prioritas jadwal pengganti)
  String get ruanganEfektif {
    if (adaJadwalPengganti && ruanganPengganti != null) {
      return ruanganPengganti!;
    }
    return ruangan ?? '-';
  }

  /// Mode efektif kelas (null jika tidak ada pengganti)
  String? get modeEfektif => modePengganti;

  /// Apakah mahasiswa sudah presensi?
  bool get sudahPresensi =>
      statusPresensi == 'hadir' || statusPresensi == 'terlambat';

  /// Apakah mahasiswa tercatat ketidakhadiran?
  bool get ketidakhadiran =>
      statusPresensi == 'absen' ||
      statusPresensi == 'izin'  ||
      statusPresensi == 'sakit';

  /// Label status yang user-friendly
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

  /// Label slot waktu "Slot 1–3"
  String get labelSlot {
    if (slotMulai == null) return '';
    final selesai = slotSelesai ?? slotMulai;
    return 'Slot $slotMulai–$selesai';
  }

  /// Label kelas jika ada
  String get labelKelas => kodeKelas != null ? 'Kelas $kodeKelas' : '';

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
// Model jadwal mingguan
// ─────────────────────────────────────────────────────────────

class JadwalMingguanModel {
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

  static const List<String> urutan = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  List<JadwalModel> hariIni(String namaHari) => perHari[namaHari] ?? [];

  int get totalMatakuliah =>
      perHari.values.fold(0, (sum, list) => sum + list.length);
}