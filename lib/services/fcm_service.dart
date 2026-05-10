// lib/services/fcm_service.dart
// v2.1.0 — Fase 5: FCM Token sinkron + foreground/background handler lengkap
//
// CATATAN PENTING (v2.1.0):
//   - Notifikasi sesi dibuka TIDAK menyertakan kode sesi.
//     Kode hanya tampil di KodeDisplayScreen dosen.
//   - FCM digunakan untuk: konfirmasi presensi, notif sesi dibuka (tanpa kode),
//     pengingat 15 menit sebelum kelas, notif sesi tutup otomatis ke dosen.
//
// Endpoint: PATCH /mahasiswa/fcm-token
// Dipanggil: setelah login, checkAuth, saat token Firebase di-rotate

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/storage.dart';
import 'package:presensi_app/services/notification_service.dart';

class FcmService {
  FcmService._();
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;

  // ── Update FCM token ke backend ───────────────────────────
  /// Ambil FCM token dari Firebase, bandingkan dengan token tersimpan,
  /// kirim ke backend hanya jika berbeda (hemat request).
  Future<void> updateToken() async {
    try {
      // Minta izin notifikasi (iOS wajib eksplisit)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert  : true,
        badge  : true,
        sound  : true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FcmService] Izin notifikasi ditolak user');
        return;
      }

      // Ambil token baru dari Firebase
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken == null || newToken.isEmpty) {
        debugPrint('[FcmService] Token Firebase null/kosong');
        return;
      }

      // Bandingkan dengan token lama
      final oldToken = await AppStorage.getFcmToken();
      if (newToken == oldToken) {
        debugPrint('[FcmService] Token tidak berubah, skip update');
        return;
      }

      // Kirim ke backend — gunakan patch (bukan post)
      await ApiClient().patch(
        '/mahasiswa/fcm-token',
        body: {'fcm_token': newToken},
      );

      // Simpan token baru ke secure storage
      await AppStorage.saveFcmToken(newToken);
      debugPrint('[FcmService] Token berhasil diperbarui ke backend');

    } on ApiException catch (e) {
      // 401 berarti user belum login — wajar saat checkAuth pertama kali
      if (e.statusCode != 401) {
        debugPrint('[FcmService] updateToken API error ${e.statusCode}: ${e.message}');
      }
    } catch (e) {
      // FCM tidak fatal — log saja
      debugPrint('[FcmService] updateToken error: $e');
    }
  }

  // ── Setup semua handler FCM (dipanggil di main()) ─────────
  /// Inisialisasi semua listener Firebase Messaging sekaligus.
  /// Wajib dipanggil setelah Firebase.initializeApp() di main().
  static Future<void> setupHandlers() async {
    // 1. Foreground — tampilkan local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FcmService] Foreground: ${message.notification?.title}');
      NotificationService().showFromRemoteMessage(message);
    });

    // 2. App dibuka dari background via notifikasi
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FcmService] openedApp: ${message.data}');
      NotificationService().handleMessageOpenedApp(message);
    });

    // 3. App terminated → dibuka dari notifikasi (handle setelah widget ready)
    // Dipanggil dari main() setelah runApp via WidgetsBinding callback
    // (lihat setupInitialMessage())
  }

  // ── Handle initial message (terminated state) ─────────────
  /// Panggil ini di main() SETELAH runApp() dan router siap,
  /// menggunakan WidgetsBinding.instance.addPostFrameCallback.
  static Future<void> setupInitialMessage() async {
    await NotificationService().handleInitialMessage();
  }

  // ── Listen token refresh ───────────────────────────────────
  /// Panggil di main() agar token otomatis diperbarui ke backend
  /// ketika Firebase me-rotate token (biasanya tiap beberapa minggu).
  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] Token dirotasi Firebase, update ke backend...');
      try {
        await ApiClient().patch(
          '/mahasiswa/fcm-token',
          body: {'fcm_token': newToken},
        );
        await AppStorage.saveFcmToken(newToken);
        debugPrint('[FcmService] Token refresh berhasil disimpan');
      } on ApiException catch (e) {
        if (e.statusCode != 401) {
          debugPrint('[FcmService] onTokenRefresh error: ${e.message}');
        }
      } catch (e) {
        debugPrint('[FcmService] onTokenRefresh error: $e');
      }
    });
  }

  // ── [Deprecated] setupForegroundHandler ───────────────────
  /// Digantikan oleh setupHandlers() yang lebih lengkap.
  /// Tetap ada untuk backward compatibility selama refactor.
  @Deprecated('Gunakan FcmService.setupHandlers() pada Fase 5')
  static Future<void> setupForegroundHandler() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FcmService] Foreground message: ${message.notification?.title}');
      NotificationService().showFromRemoteMessage(message);
    });
  }
}