// lib/core/constants.dart
// v2.1.0 — Update Fase 1: tambah key kelas, slot, program studi, tamu

class AppConstants {
  AppConstants._();

  // ── Backend URL ───────────────────────────────────────────
  // Dev emulator Android : 10.0.2.2 = localhost laptop
  // Dev HP fisik         : ganti dengan IP jaringan laptop (ipconfig/ifconfig)
  // Production           : ganti dengan URL Render/Railway
  static const String baseUrl = 'http://10.92.83.91:8000';

  // ── Face Recognition ─────────────────────────────────────
  static const double faceAccuracyThreshold = 85.0;
  /// Jumlah foto minimum registrasi — default 8, bisa diambil dari API
  static const int    minFotoRegistrasi     = 8;
  static const int    maxFotoRegistrasi     = 8; // override via /face/status

  // ── GPS Geofencing ───────────────────────────────────────
  /// Radius geofencing default — bisa di-override dari konfigurasi sistem
  static const double radiusGeofencingMeter = 100.0;

  // ── Session ──────────────────────────────────────────────
  static const int kodeSessionLength    = 6;
  static const int pollingIntervalDetik = 5;

  // ── Secure Storage Keys ───────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData     = 'user_data';

  // ── [BARU v2.1.0] Kelas ───────────────────────────────────
  /// Key untuk menyimpan kelas_id user yang sedang aktif
  static const String keyKelasId    = 'kelas_id';
  static const String keyKodeKelas  = 'kode_kelas';

  // ── [BARU v2.1.0] Program Studi ───────────────────────────
  static const String keyProgramStudiId = 'program_studi_id';

  // ── [BARU v2.1.0] Slot Waktu Cache ────────────────────────
  /// Key cache slot options dari /kelas/slot-options
  static const String keySlotOptionsCache = 'slot_options_cache';
  static const Duration slotOptionsCacheDuration = Duration(hours: 12);

  // ── [BARU v2.1.0] Sesi Detect ────────────────────────────
  /// Timeout untuk auto-detect sesi aktif
  static const Duration sesiDetectTimeout = Duration(seconds: 15);

  // ── [BARU v2.1.0] Tamu ───────────────────────────────────
  static const String keyIsTamu    = 'is_tamu';
  static const String keyKelasAsal = 'kelas_asal';

  // ── [BARU v2.1.0] FCM ────────────────────────────────────
  static const String keyFcmToken     = 'fcm_token';
  static const String keyFcmLastUpdate = 'fcm_last_update';

  // ── Hari dalam seminggu ───────────────────────────────────
  static const List<String> hariList = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static String namaHariDariWeekday(int weekday) {
    const map = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
      5: 'Jumat', 6: 'Sabtu', 7: 'Minggu',
    };
    return map[weekday] ?? 'Senin';
  }

  // ── Status Presensi ───────────────────────────────────────
  static const String statusHadir     = 'hadir';
  static const String statusTerlambat = 'terlambat';
  static const String statusAbsen     = 'absen';
  static const String statusIzin      = 'izin';
  static const String statusSakit     = 'sakit';

  // ── Mode Kelas ────────────────────────────────────────────
  static const String modeOffline = 'offline';
  static const String modeOnline  = 'online';

  // ── Role ──────────────────────────────────────────────────
  static const String roleMahasiswa = 'mahasiswa';
  static const String roleDosen     = 'dosen';
  static const String roleAdmin     = 'admin';
}