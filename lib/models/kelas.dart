// lib/models/kelas.dart
// v2.1.0 — Model Kelas per Matakuliah dan Slot Waktu
// Sesuai Fase B backend: kelas_matakuliah + slot_utils.py

// ══════════════════════════════════════════════════════════════
// MODEL: SLOT WAKTU (dari /kelas/slot-options)
// ══════════════════════════════════════════════════════════════

/// Satu slot waktu perkuliahan (50 menit per slot)
/// Slot 1 = 07:00–07:50, Slot 2 = 07:50–08:40, dst.
class SlotOption {
  final int    slot;
  final String jamMulai;    // "07:00"
  final String jamSelesai;  // "07:50"
  final String label;       // "Slot 1 | 07:00–07:50"

  const SlotOption({
    required this.slot,
    required this.jamMulai,
    required this.jamSelesai,
    required this.label,
  });

  factory SlotOption.fromJson(Map<String, dynamic> json) {
    return SlotOption(
      slot      : json['slot']       as int,
      jamMulai  : json['jam_mulai']  as String,
      jamSelesai: json['jam_selesai'] as String,
      label     : json['label']      as String? ??
                  'Slot ${json['slot']} | ${json['jam_mulai']}–${json['jam_selesai']}',
    );
  }

  Map<String, dynamic> toJson() => {
    'slot'       : slot,
    'jam_mulai'  : jamMulai,
    'jam_selesai': jamSelesai,
    'label'      : label,
  };

  /// Contoh: "07:00 – 09:30" untuk slot 1–3
  static String rangeLabel(int slotMulai, int slotSelesai,
      List<SlotOption> options) {
    final mulai = options.firstWhere(
      (s) => s.slot == slotMulai,
      orElse: () => SlotOption(
        slot: slotMulai, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    final selesai = options.firstWhere(
      (s) => s.slot == slotSelesai,
      orElse: () => SlotOption(
        slot: slotSelesai, jamMulai: '?', jamSelesai: '?', label: '?'),
    );
    return '${mulai.jamMulai} – ${selesai.jamSelesai}';
  }

  @override
  String toString() => label;
}

// ── Slot default (hardcoded fallback jika API belum ada) ──────
class SlotDefaults {
  static const List<Map<String, dynamic>> data = [
    {'slot': 1,  'jam_mulai': '07:00', 'jam_selesai': '07:50', 'label': 'Slot 1  |  07:00 – 07:50'},
    {'slot': 2,  'jam_mulai': '07:50', 'jam_selesai': '08:40', 'label': 'Slot 2  |  07:50 – 08:40'},
    {'slot': 3,  'jam_mulai': '08:40', 'jam_selesai': '09:30', 'label': 'Slot 3  |  08:40 – 09:30'},
    {'slot': 4,  'jam_mulai': '09:30', 'jam_selesai': '10:20', 'label': 'Slot 4  |  09:30 – 10:20'},
    {'slot': 5,  'jam_mulai': '10:20', 'jam_selesai': '11:10', 'label': 'Slot 5  |  10:20 – 11:10'},
    {'slot': 6,  'jam_mulai': '11:10', 'jam_selesai': '12:00', 'label': 'Slot 6  |  11:10 – 12:00'},
    {'slot': 7,  'jam_mulai': '13:00', 'jam_selesai': '13:50', 'label': 'Slot 7  |  13:00 – 13:50'},
    {'slot': 8,  'jam_mulai': '13:50', 'jam_selesai': '14:40', 'label': 'Slot 8  |  13:50 – 14:40'},
    {'slot': 9,  'jam_mulai': '14:40', 'jam_selesai': '15:30', 'label': 'Slot 9  |  14:40 – 15:30'},
    {'slot': 10, 'jam_mulai': '15:30', 'jam_selesai': '16:20', 'label': 'Slot 10 |  15:30 – 16:20'},
    {'slot': 11, 'jam_mulai': '16:20', 'jam_selesai': '17:10', 'label': 'Slot 11 |  16:20 – 17:10'},
    {'slot': 12, 'jam_mulai': '17:10', 'jam_selesai': '18:00', 'label': 'Slot 12 |  17:10 – 18:00'},
  ];

  static List<SlotOption> get all =>
      data.map((d) => SlotOption.fromJson(d)).toList();

  /// Ambil jam mulai dari nomor slot
  static String jamMulai(int slot) {
    final found = data.firstWhere(
      (d) => d['slot'] == slot,
      orElse: () => {'jam_mulai': '?', 'jam_selesai': '?'},
    );
    return found['jam_mulai'] as String;
  }

  /// Ambil jam selesai dari nomor slot
  static String jamSelesai(int slot) {
    final found = data.firstWhere(
      (d) => d['slot'] == slot,
      orElse: () => {'jam_mulai': '?', 'jam_selesai': '?'},
    );
    return found['jam_selesai'] as String;
  }

  /// Label range dari slotMulai ke slotSelesai: "07:00 – 09:30"
  static String rangeLabel(int slotMulai, int slotSelesai) {
    return '${jamMulai(slotMulai)} – ${jamSelesai(slotSelesai)}';
  }
}

// ══════════════════════════════════════════════════════════════
// MODEL: KELAS MATAKULIAH (dari /admin/matakuliah/{id}/kelas)
// ══════════════════════════════════════════════════════════════

/// Satu kelas dalam matakuliah (Kelas A, B, C, dst.)
class KelasModel {
  final String  id;
  final String  matakuliahId;
  final String  kodeKelas;      // 'A', 'B', 'C', dst.
  final String? dosenId;
  final String? dosenNama;
  final String? dosenNidn;
  final String? ruanganId;
  final String? ruanganNama;
  final String? ruanganKode;
  final String? hari;
  final int?    slotMulai;
  final int?    slotSelesai;
  final String? jamMulai;       // Dihitung otomatis dari slot
  final String? jamSelesai;     // Dihitung otomatis dari slot
  final bool    izinTamu;
  final int     jumlahMahasiswa;
  final int     enrolled;        // Alias jumlahMahasiswa (dari backend response)

  const KelasModel({
    required this.id,
    required this.matakuliahId,
    required this.kodeKelas,
    this.dosenId,
    this.dosenNama,
    this.dosenNidn,
    this.ruanganId,
    this.ruanganNama,
    this.ruanganKode,
    this.hari,
    this.slotMulai,
    this.slotSelesai,
    this.jamMulai,
    this.jamSelesai,
    this.izinTamu    = false,
    this.jumlahMahasiswa = 0,
    this.enrolled    = 0,
  });

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    final slot1 = json['slot_mulai']   as int?;
    final slot2 = json['slot_selesai'] as int?;
    // Hitung jam otomatis dari slot jika tidak ada di response
    final jamMulaiRaw   = json['jam_mulai']   as String?
        ?? (slot1 != null ? SlotDefaults.jamMulai(slot1) : null);
    final jamSelesaiRaw = json['jam_selesai'] as String?
        ?? (slot2 != null ? SlotDefaults.jamSelesai(slot2) : null);

    final enrolled = json['enrolled']          as int?
                  ?? json['jumlah_mahasiswa']   as int?
                  ?? 0;

    return KelasModel(
      id               : json['id']           as String,
      matakuliahId     : json['matakuliah_id'] as String? ?? '',
      kodeKelas        : json['kode_kelas']    as String? ?? '',
      dosenId          : json['dosen_id']      as String?,
      dosenNama        : json['dosen_nama']    as String?,
      dosenNidn        : json['dosen_nidn']    as String?,
      ruanganId        : json['ruangan_id']    as String?,
      ruanganNama      : json['ruangan_nama']  as String?,
      ruanganKode      : json['ruangan_kode']  as String?,
      hari             : json['hari']          as String?,
      slotMulai        : slot1,
      slotSelesai      : slot2,
      jamMulai         : jamMulaiRaw,
      jamSelesai       : jamSelesaiRaw,
      izinTamu         : json['izin_tamu']     as bool? ?? false,
      jumlahMahasiswa  : enrolled,
      enrolled         : enrolled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id'              : id,
    'matakuliah_id'   : matakuliahId,
    'kode_kelas'      : kodeKelas,
    'dosen_id'        : dosenId,
    'dosen_nama'      : dosenNama,
    'ruangan_id'      : ruanganId,
    'ruangan_nama'    : ruanganNama,
    'hari'            : hari,
    'slot_mulai'      : slotMulai,
    'slot_selesai'    : slotSelesai,
    'jam_mulai'       : jamMulai,
    'jam_selesai'     : jamSelesai,
    'izin_tamu'       : izinTamu,
    'jumlah_mahasiswa': jumlahMahasiswa,
  };

  // ── Helper getters ─────────────────────────────────────────

  /// Label jam: "07:00 – 09:30"
  String get labelJam {
    if (jamMulai == null && jamSelesai == null) return '-';
    return '${jamMulai ?? "?"} – ${jamSelesai ?? "?"}';
  }

  /// Label slot: "Slot 1–3"
  String get labelSlot {
    if (slotMulai == null) return '';
    final selesai = slotSelesai ?? slotMulai;
    return 'Slot $slotMulai–$selesai';
  }

  /// Label lengkap: "Slot 1–3 | 07:00–09:30"
  String get labelSlotLengkap {
    if (slotMulai == null) return labelJam;
    return '$labelSlot  |  $labelJam';
  }

  @override
  String toString() => 'KelasModel(Kelas $kodeKelas, $hari $labelJam)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KelasModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════════
// MODEL: MAHASISWA DALAM KELAS (dari /kelas/mahasiswa/{kelas_id})
// ══════════════════════════════════════════════════════════════

class MahasiswaKelasModel {
  final String  mahasiswaId;
  final String  nim;
  final String  namaLengkap;
  final String  programStudi;
  final bool    isTamu;
  final String? kelasAsal;     // Nama kelas asal jika tamu

  const MahasiswaKelasModel({
    required this.mahasiswaId,
    required this.nim,
    required this.namaLengkap,
    required this.programStudi,
    required this.isTamu,
    this.kelasAsal,
  });

  factory MahasiswaKelasModel.fromJson(Map<String, dynamic> json) {
    return MahasiswaKelasModel(
      mahasiswaId : json['mahasiswa_id']  as String,
      nim         : json['nim']           as String,
      namaLengkap : json['nama_lengkap']  as String,
      programStudi: json['program_studi'] as String? ?? '',
      isTamu      : json['is_tamu']       as bool?   ?? false,
      kelasAsal   : json['kelas_asal']    as String?,
    );
  }

  /// Inisial nama untuk avatar (maks 2 huruf)
  String get inisial {
    final parts = namaLengkap.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (namaLengkap.isNotEmpty) return namaLengkap[0].toUpperCase();
    return '?';
  }
}