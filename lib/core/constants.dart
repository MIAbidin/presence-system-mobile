// lib/core/constants.dart
//
// Semua nilai konfigurasi dibaca dari --dart-define saat build.
// TIDAK ADA nilai sensitif yang di-hardcode di sini.
//
// ── Cara pakai saat development ───────────────────────────
//   flutter run --dart-define=BASE_URL=http://10.118.168.91:8000
//
// ── Cara pakai saat build release ─────────────────────────
//   Buat file .env.local (tidak di-commit), lalu:
//   flutter build apk --dart-define-from-file=.env.local
//
// ── Format .env.local ─────────────────────────────────────
//   BASE_URL=https://presensi-api.kampus.ac.id
//   (JSON format, bukan KEY=VALUE — lihat flutter docs)
//
// JANGAN ubah const String ini menjadi nilai langsung.
// JANGAN commit file .env.local ke git.

class AppConstants {
  AppConstants._(); // mencegah instantiasi

  // ── Backend URL ───────────────────────────────────────────
  // Dibaca dari --dart-define=BASE_URL=...
  // Default hanya untuk development lokal
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → localhost
  );

  // ── Face Recognition ─────────────────────────────────────
  static const double faceAccuracyThreshold = double.fromEnvironment(
    'FACE_ACCURACY_THRESHOLD',
    defaultValue: 85.0,
  );

  static const int minFotoRegistrasi = int.fromEnvironment(
    'MIN_FACE_PHOTOS',
    defaultValue: 8,
  );

  // ── GPS Geofencing ───────────────────────────────────────
  static const double radiusGeofencingMeter = double.fromEnvironment(
    'GEOFENCING_RADIUS',
    defaultValue: 100.0,
  );

  // ── Session ──────────────────────────────────────────────
  static const int kodeSessionLength    = 6;
  static const int pollingIntervalDetik = 5;

  // ── Secure Storage Keys ───────────────────────────────────
  // Nama key di keychain/keystore — bukan nilai sensitif
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData     = 'user_data';
}