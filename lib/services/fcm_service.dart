// lib/services/fcm_service.dart
// v2.1.0 — Sinkronisasi FCM Token ke backend
// Dipanggil: setelah login, setiap kali app resume, saat profil dimuat
// Endpoint: PATCH /mahasiswa/fcm-token

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/constants.dart';
import 'package:presensi_app/core/storage.dart';

class FcmService {
  FcmService._();
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;

  // ── Update FCM token ke backend ───────────────────────────
  /// Ambil FCM token dari Firebase, bandingkan dengan token tersimpan,
  /// kirim ke backend jika berbeda atau belum pernah dikirim.
  Future<void> updateToken() async {
    try {
      // Minta izin notifikasi (iOS perlu eksplisit)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert  : true,
        badge  : true,
        sound  : true,
      );

      // Jika ditolak, tidak perlu lanjut
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // Ambil token baru dari Firebase
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken == null || newToken.isEmpty) return;

      // Ambil token lama dari storage
      final oldToken = await AppStorage.getFcmToken();

      // Hanya update jika token berubah
      if (newToken == oldToken) return;

      // Kirim ke backend
      await ApiClient().patch(
        '/mahasiswa/fcm-token',
        body: {'fcm_token': newToken},
      );

      // Simpan token baru
      await AppStorage.saveFcmToken(newToken);

    } catch (e) {
      // FCM tidak fatal — log saja, jangan throw
      // ignore: avoid_print
      print('[FcmService] updateToken error: $e');
    }
  }

  // ── Subscribe to token refresh ────────────────────────────
  /// Panggil di main() atau AuthProvider agar token otomatis
  /// diperbarui ke backend ketika Firebase me-rotate token.
  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await ApiClient().patch(
          '/mahasiswa/fcm-token',
          body: {'fcm_token': newToken},
        );
        await AppStorage.saveFcmToken(newToken);
      } catch (e) {
        // ignore: avoid_print
        print('[FcmService] onTokenRefresh error: $e');
      }
    });
  }

  // ── Setup foreground notification handler ─────────────────
  /// Dipanggil di main() setelah Firebase init.
  /// Menggunakan flutter_local_notifications untuk tampilkan
  /// notifikasi ketika app di foreground.
  static Future<void> setupForegroundHandler() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Tampilkan notifikasi lokal saat app di foreground
      // Implementasi detail ada di NotificationService jika diperlukan
      // ignore: avoid_print
      print('[FcmService] Foreground message: ${message.notification?.title}');
    });
  }
}

// ── Extension AppStorage untuk FCM Token ─────────────────────
extension AppStorageFcmExtension on AppStorage {
  static Future<void> saveFcmToken(String token) async {
    await AppStorage.saveString(AppConstants.keyFcmToken, token);
  }

  static Future<String?> getFcmToken() async {
    return await AppStorage.getString(AppConstants.keyFcmToken);
  }
}

// ── Extension AppStorage untuk string generic ─────────────────
extension on AppStorage {
  static Future<void> saveString(String key, String value) async {
    // Gunakan flutter_secure_storage yang sudah ada di AppStorage
    // Implementasi delegasi ke FlutterSecureStorage
    await _AppStorageHelper.write(key, value);
  }

  static Future<String?> getString(String key) async {
    return await _AppStorageHelper.read(key);
  }
}

class _AppStorageHelper {
  static Future<void> write(String key, String value) async {
    const storage = _SecureStorageAccess();
    await storage.write(key, value);
  }

  static Future<String?> read(String key) async {
    const storage = _SecureStorageAccess();
    return await storage.read(key);
  }
}

class _SecureStorageAccess {
  const _SecureStorageAccess();

  Future<void> write(String key, String value) async {
    // Delegate ke AppStorage static method
    // Ini adalah bridge agar FcmService bisa tulis ke secure storage
    // tanpa import langsung flutter_secure_storage
    await AppStorage.saveRaw(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await AppStorage.getRaw(key: key);
  }
}