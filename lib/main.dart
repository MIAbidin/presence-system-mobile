// lib/main.dart
// v2.1.0 — Fase 5: FCM + flutter_local_notifications lengkap
//   - NotificationService.init() untuk setup channel Android & iOS
//   - FcmService.setupHandlers() untuk foreground + onMessageOpenedApp
//   - setupInitialMessage() untuk app dibuka dari notif saat terminated
//   - navigatorKey diteruskan ke MaterialApp.router agar navigasi dari
//     notif bisa dilakukan tanpa BuildContext

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/router.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/services/fcm_service.dart';
import 'package:presensi_app/services/notification_service.dart'; // ← FASE 5

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Intl locale
import 'package:intl/date_symbol_data_local.dart';

// ── Background handler (harus top-level function) ─────────────
// Dipanggil oleh OS saat app terminated/background menerima FCM data message.
// Tidak bisa menampilkan UI — hanya untuk logika ringan.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background handler sengaja minimal — UI notification ditangani OS
  // berdasarkan notification payload dari FCM server.
  debugPrint('📬 [FCM Background] ${message.notification?.title}');
}

// ══════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Locale Indonesia untuk DateFormat
  await initializeDateFormatting('id_ID', null);

  // 2. Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Background FCM handler (wajib sebelum runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 4. Setup flutter_local_notifications + channel Android/iOS
  await NotificationService().init();

  // 5. Setup semua FCM handler:
  //    - onMessage (foreground → local notification)
  //    - onMessageOpenedApp (background → navigasi)
  await FcmService.setupHandlers();

  // 6. Listen token refresh agar FCM token selalu sinkron
  FcmService().listenTokenRefresh();

  runApp(const PresensiApp());

  // 7. Handle initial message (terminated → dibuka dari notifikasi)
  //    Dipanggil setelah runApp agar GoRouter sudah siap
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FcmService.setupInitialMessage();
  });
}

// ══════════════════════════════════════════════════════════════
// APP ROOT
// ══════════════════════════════════════════════════════════════

class PresensiApp extends StatelessWidget {
  const PresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        Provider<ApiClient>(create: (_) => ApiClient()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router       = createRouter(authProvider);

          return MaterialApp.router(
            title               : 'Presensi SKS — UMS',
            debugShowCheckedModeBanner: false,

            // ── Tema UMS terpusat (Fase 1) ─────────────────────
            theme: AppTheme.lightTheme,

            // ── navigatorKey untuk navigasi dari notifikasi ────
            // NotificationService menggunakan key ini saat routing
            // dari tap notifikasi tanpa BuildContext.
            // CATATAN: MaterialApp.router menggunakan routerConfig,
            // sehingga kita set navigatorKey via GoRouter bukan di sini.
            // GoRouter v14 mendukung navigatorKey di constructor-nya.
            routerConfig: router,
          );
        },
      ),
    );
  }
}