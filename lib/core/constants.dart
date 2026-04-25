// lib/core/constants.dart

class AppConstants {
  // ── Backend URL ───────────────────────────────────────────
  // Dev emulator Android : 10.0.2.2 = localhost laptop
  // Dev HP fisik         : ganti dengan IP jaringan laptop (ipconfig/ifconfig)
  // Production           : ganti dengan URL Render/Railway
  static const String baseUrl = 'http://10.118.168.91:8000';

  // ── Face Recognition ─────────────────────────────────────
  static const double faceAccuracyThreshold = 85.0;
  static const int    minFotoRegistrasi     = 8;

  // ── GPS Geofencing ───────────────────────────────────────
  static const double radiusGeofencingMeter = 100.0;

  // ── Session ──────────────────────────────────────────────
  static const int kodeSessionLength    = 6;
  static const int pollingIntervalDetik = 5;

  // ── Secure Storage Keys ───────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData     = 'user_data';
}