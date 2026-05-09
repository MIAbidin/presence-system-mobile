// lib/models/sesi_tamu.dart
// v2.1.0 — Model Sesi yang tersedia untuk Mahasiswa Tamu
// Endpoint: GET /sesi/aktif-tamu
// Dipakai di TamuSesiListScreen

class SesiTamuModel {
  final String  sesiId;
  final String  matakuliahId;
  final String  matakuliahNama;
  final String  matakuliahKode;
  final String  kelasId;
  final String  kodeKelas;       // 'A', 'B', 'C'
  final String  dosenNama;
  final String  mode;            // 'offline' | 'online'
  final String? ruangan;
  final String? jamMulai;
  final String? jamSelesai;
  final int?    pertemuanKe;
  final int?    detikTersisa;    // Hanya untuk mode online
  final bool    sudahDidaftarkan; // True = dosen sudah daftarkan manual
  final bool    izinTamu;         // True = kelas punya izin_tamu=true

  const SesiTamuModel({
    required this.sesiId,
    required this.matakuliahId,
    required this.matakuliahNama,
    required this.matakuliahKode,
    required this.kelasId,
    required this.kodeKelas,
    required this.dosenNama,
    required this.mode,
    this.ruangan,
    this.jamMulai,
    this.jamSelesai,
    this.pertemuanKe,
    this.detikTersisa,
    this.sudahDidaftarkan = false,
    this.izinTamu         = false,
  });

  factory SesiTamuModel.fromJson(Map<String, dynamic> json) {
    return SesiTamuModel(
      sesiId           : json['sesi_id']           as String,
      matakuliahId     : json['matakuliah_id']      as String,
      matakuliahNama   : json['matakuliah_nama']    as String? ?? '',
      matakuliahKode   : json['matakuliah_kode']    as String? ?? '',
      kelasId          : json['kelas_id']           as String? ?? '',
      kodeKelas        : json['kode_kelas']         as String? ?? '',
      dosenNama        : json['dosen_nama']         as String? ?? '-',
      mode             : json['mode']               as String? ?? 'offline',
      ruangan          : json['ruangan']            as String?,
      jamMulai         : json['jam_mulai']          as String?,
      jamSelesai       : json['jam_selesai']        as String?,
      pertemuanKe      : json['pertemuan_ke']       as int?,
      detikTersisa     : json['detik_tersisa']      as int?,
      sudahDidaftarkan : json['sudah_didaftarkan']  as bool? ?? false,
      izinTamu         : json['izin_tamu']          as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'sesi_id'          : sesiId,
    'matakuliah_id'    : matakuliahId,
    'matakuliah_nama'  : matakuliahNama,
    'matakuliah_kode'  : matakuliahKode,
    'kelas_id'         : kelasId,
    'kode_kelas'       : kodeKelas,
    'dosen_nama'       : dosenNama,
    'mode'             : mode,
    'ruangan'          : ruangan,
    'jam_mulai'        : jamMulai,
    'jam_selesai'      : jamSelesai,
    'pertemuan_ke'     : pertemuanKe,
    'detik_tersisa'    : detikTersisa,
    'sudah_didaftarkan': sudahDidaftarkan,
    'izin_tamu'        : izinTamu,
  };

  // ── Helper ─────────────────────────────────────────────────
  bool get isOnline => mode == 'online';

  String get labelJam {
    if (jamMulai == null && jamSelesai == null) return '-';
    return '${jamMulai ?? "?"} – ${jamSelesai ?? "?"}';
  }

  String get labelMode => isOnline ? '💻 Online' : '📍 Tatap Muka';

  String get labelAlasan =>
      sudahDidaftarkan ? 'Didaftarkan dosen' : 'Izin tamu terbuka';

  @override
  String toString() =>
      'SesiTamuModel($matakuliahKode Kelas $kodeKelas, $mode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SesiTamuModel &&
          runtimeType == other.runtimeType &&
          sesiId == other.sesiId;

  @override
  int get hashCode => sesiId.hashCode;
}