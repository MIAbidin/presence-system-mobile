// lib/main.dart
// v2.1.0 — Update: tema UMS, FCM setup, locale Indonesia

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/router.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';           // ← BARU v2.1.0
import 'package:presensi_app/services/fcm_service.dart'; // ← BARU v2.1.0

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Intl locale
import 'package:intl/date_symbol_data_local.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📬 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale Indonesia untuk intl/DateFormat
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Setup background handler FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Setup foreground notification handler (v2.1.0)
  await FcmService.setupForegroundHandler();

  // Listen token refresh agar FCM token selalu sinkron ke backend
  FcmService().listenTokenRefresh();

  runApp(const PresensiApp());
}

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

            // ── v2.1.0: Tema UMS terpusat ─────────────────────
            theme: AppTheme.lightTheme,

            routerConfig: router,
          );
        },
      ),
    );
  }
}