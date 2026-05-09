// lib/services/sesi_detect_service.dart
// v2.1.0 — Auto-detect sesi aktif berdasarkan jadwal mahasiswa
// Ini adalah perubahan INTI dari v2.1.0: mahasiswa tidak lagi pilih mode manual.
// Sistem otomatis deteksi sesi aktif dan mode (offline/online).

import 'dart:convert';
import 'package:presensi_app/core/api_client.dart';

// ══════════════════════════════════════════════════════════════
// MODEL HASIL DETEKSI
// ══════════════════════════════════════════════════════════════

enum SesiDetectStatus {
  /// Sesi ditemukan dan siap presensi
  found,

  /// Tidak ada sesi aktif untuk jadwal mahasiswa ini
  notFound,

  /// Error saat fetch (network, server error)
  error,
}

class SesiDetectResult {
  final SesiDetectStatus status;

  // Diisi jika status == found
  final String?  sesiId;
  final String?  matakuliahNama;
  final String?  matakuliahKode;
  final String?  kelasId;
  final String?  kodeKelas;
  final String?  dosenNama;
  final String?  mode;           // 'offline' | 'online'
  final String?  ruangan;
  final int?     pertemuanKe;
  final int?     detikTersisa;   // Hanya untuk online
  final double?  koordinatLat;   // Koordinat kelas untuk geofencing
  final double?  koordinatLng;

  // Diisi jika status == error
  final String? errorMessage;

  const SesiDetectResult({
    required this.status,
    this.sesiId,
    this.matakuliahNama,
    this.matakuliahKode,
    this.kelasId,
    this.kodeKelas,
    this.dosenNama,
    this.mode,
    this.ruangan,
    this.pertemuanKe,
    this.detikTersisa,
    this.koordinatLat,
    this.koordinatLng,
    this.errorMessage,
  });

  // ── Factory constructors ──────────────────────────────────
  factory SesiDetectResult.notFound() => const SesiDetectResult(
    status: SesiDetectStatus.notFound,
  );

  factory SesiDetectResult.error(String message) => SesiDetectResult(
    status      : SesiDetectStatus.error,
    errorMessage: message,
  );

  factory SesiDetectResult.fromJson(Map<String, dynamic> json) {
    final sesi = json['sesi'] as Map<String, dynamic>?;
    if (sesi == null) return SesiDetectResult.notFound();

    return SesiDetectResult(
      status         : SesiDetectStatus.found,
      sesiId         : sesi['sesi_id']        as String?,
      matakuliahNama : sesi['matakuliah_nama'] as String?,
      matakuliahKode : sesi['matakuliah_kode'] as String?,
      kelasId        : sesi['kelas_id']        as String?,
      kodeKelas      : sesi['kode_kelas']      as String?,
      dosenNama      : sesi['dosen_nama']      as String?,
      mode           : sesi['mode']            as String?,
      ruangan        : sesi['ruangan']         as String?,
      pertemuanKe    : sesi['pertemuan_ke']    as int?,
      detikTersisa   : sesi['detik_tersisa']   as int?,
      koordinatLat   : (sesi['koordinat_lat']  as num?)?.toDouble(),
      koordinatLng   : (sesi['koordinat_lng']  as num?)?.toDouble(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  bool get isFound    => status == SesiDetectStatus.found;
  bool get isNotFound => status == SesiDetectStatus.notFound;
  bool get isError    => status == SesiDetectStatus.error;
  bool get isOnline   => mode == 'online';
  bool get isOffline  => mode == 'offline';

  String get labelMode => isOnline ? '💻 Online' : '📍 Tatap Muka';

  String get labelInfo {
    if (!isFound) return '';
    final mk    = matakuliahNama ?? '';
    final kelas = kodeKelas != null ? ' · Kelas $kodeKelas' : '';
    return '$mk$kelas';
  }

  @override
  String toString() => 'SesiDetectResult($status, $mode, $matakuliahNama)';
}

// ══════════════════════════════════════════════════════════════
// SERVICE
// ══════════════════════════════════════════════════════════════

class SesiDetectService {
  // Singleton
  SesiDetectService._();
  static final SesiDetectService _instance = SesiDetectService._();
  factory SesiDetectService() => _instance;

  // ── Deteksi sesi aktif ────────────────────────────────────
  /// Cek sesi aktif berdasarkan jadwal mahasiswa yang login.
  ///
  /// Flow:
  /// 1. Panggil GET /sesi/aktif
  /// 2. Backend mengembalikan sesi yang cocok dengan jadwal mahasiswa sekarang
  /// 3. Jika ada → return SesiDetectResult dengan mode (offline/online)
  /// 4. Jika tidak ada → return SesiDetectResult.notFound()
  /// 5. Jika error → return SesiDetectResult.error(message)
  Future<SesiDetectResult> detectSesiAktif() async {
    try {
      final response = await ApiClient()
          .get('/sesi/aktif')
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Backend mengembalikan {sesi: {...}} jika ada sesi aktif
        // atau {sesi: null} / {} jika tidak ada
        final sesiData = data['sesi'] as Map<String, dynamic>?;
        if (sesiData == null || sesiData.isEmpty) {
          return SesiDetectResult.notFound();
        }

        return SesiDetectResult.fromJson(data);

      } else if (response.statusCode == 404) {
        return SesiDetectResult.notFound();

      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = body['detail'] as String? ?? 'Gagal cek sesi aktif';
        return SesiDetectResult.error(detail);
      }

    } on ApiException catch (e) {
      return SesiDetectResult.error(e.message);
    } catch (e) {
      return SesiDetectResult.error('Tidak dapat terhubung ke server');
    }
  }

  // ── Fetch sesi tersedia untuk tamu ────────────────────────
  /// Ambil list sesi aktif yang bisa diikuti mahasiswa sebagai tamu.
  /// Endpoint: GET /sesi/aktif-tamu
  ///
  /// Sesi masuk daftar jika:
  /// - Dosen sudah daftarkan mahasiswa ini manual, ATAU
  /// - izin_tamu = true di kelas tersebut
  Future<List<Map<String, dynamic>>> getSesiAktifTamu() async {
    try {
      final response = await ApiClient()
          .get('/sesi/aktif-tamu')
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['sesi_list'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}