// lib/router.dart
// v2.1.0 — Update route /kode-sesi: terima SesiDetectResult dari ScanScreen

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/providers/auth_provider.dart';

// Screens — Mahasiswa
import 'package:presensi_app/screens/login_screen.dart';
import 'package:presensi_app/screens/register_face_screen.dart';
import 'package:presensi_app/screens/kode_sesi_screen.dart';
import 'package:presensi_app/screens/hasil_screen.dart';
import 'package:presensi_app/screens/tamu_sesi_list_screen.dart'; // Fase 3.3
import 'package:presensi_app/widgets/bottom_nav.dart';
import 'package:presensi_app/services/sesi_detect_service.dart';

// Screens — Dosen
import 'package:presensi_app/screens/dosen/main_dosen_screen.dart';
import 'package:presensi_app/screens/dosen/kode_display_screen.dart';
import 'package:presensi_app/screens/dosen/rekap_screen.dart';
import 'package:presensi_app/screens/dosen/detail_matakuliah_screen.dart';

// Halaman loading saat cek auth
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF003366), // UMS Navy
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.face_retouching_natural,
              size : 64,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Memuat...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation  : '/splash',

    redirect: (context, state) {
      final status = authProvider.status;
      final user   = authProvider.currentUser;
      final loc    = state.matchedLocation;

      // ── Masih loading → splash ─────────────────────────
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // ── Dari splash → redirect sesuai status ───────────
      if (loc == '/splash') {
        if (status == AuthStatus.unauthenticated) return '/login';
        if (user?.isDosen == true)      return '/dosen/home';
        if (user?.isMahasiswa == true && !user!.isFaceRegistered) {
          return '/register-face';
        }
        return '/home';
      }

      // ── Belum login → paksa ke login ───────────────────
      if (status == AuthStatus.unauthenticated) {
        return loc == '/login' ? null : '/login';
      }

      // ── Mahasiswa belum daftar wajah ───────────────────
      if (user != null && user.isMahasiswa && !user.isFaceRegistered) {
        if (loc != '/register-face') return '/register-face';
        return null;
      }

      // ── Sudah login & di halaman login ─────────────────
      if (loc == '/login') {
        return user?.isDosen == true ? '/dosen/home' : '/home';
      }

      // ── Dosen tidak boleh akses route mahasiswa ─────────
      if (user?.isDosen == true) {
        const mahasiswaRoutes = [
          '/home', '/scan', '/register-face',
          '/riwayat', '/jadwal', '/profil',
        ];
        if (mahasiswaRoutes.contains(loc)) return '/dosen/home';
      }

      // ── Mahasiswa tidak boleh akses route dosen ─────────
      if (user?.isMahasiswa == true) {
        if (loc.startsWith('/dosen')) return '/home';
      }

      return null;
    },

    routes: [
      // ── Splash ────────────────────────────────────────────
      GoRoute(
        path   : '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),

      // ── Auth ──────────────────────────────────────────────
      GoRoute(
        path   : '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ─────────────────────────────────────────────────────
      // MAHASISWA — Tab navigation shell
      // ─────────────────────────────────────────────────────
      GoRoute(
        path   : '/home',
        builder: (context, state) => const MainScreen(initialIndex: 0),
      ),
      GoRoute(
        path   : '/jadwal',
        builder: (context, state) => const MainScreen(initialIndex: 1),
      ),
      GoRoute(
        path   : '/scan',
        builder: (context, state) => const MainScreen(initialIndex: 2),
      ),
      GoRoute(
        path   : '/riwayat',
        builder: (context, state) => const MainScreen(initialIndex: 3),
      ),
      GoRoute(
        path   : '/profil',
        builder: (context, state) => const MainScreen(initialIndex: 4),
      ),

      // Mahasiswa standalone screens
      GoRoute(
        path   : '/register-face',
        builder: (context, state) => const RegisterFaceScreen(),
      ),

      // ── v2.1.0: /kode-sesi — terima SesiDetectResult ─────
      // Dipanggil otomatis dari ScanScreen saat sesi online terdeteksi.
      // extra bisa berupa:
      //   - SesiDetectResult (dari ScanScreen v2.1.0) ← utama
      //   - String (sesiId lama, backward-compat) ← fallback
      //   - null (akses langsung, edge case)
      GoRoute(
        path   : '/kode-sesi',
        builder: (context, state) {
          final extra = state.extra;

          // v2.1.0: extra adalah SesiDetectResult
          if (extra is SesiDetectResult) {
            return KodeSesiScreen(sesiAktif: extra);
          }

          // Backward-compat: extra adalah String sesiId
          if (extra is String) {
            return KodeSesiScreen(sesiId: extra);
          }

          // null — akses tanpa konteks
          return const KodeSesiScreen();
        },
      ),

      GoRoute(
        path   : '/hasil',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return HasilScreen(data: args);
        },
      ),

      // ── v2.1.0: Tamu sesi list ────────────────────────────
      GoRoute(
        path   : '/mahasiswa/tamu-sesi',
        builder: (context, state) => const TamuSesiListScreen(),
      ),

      // ─────────────────────────────────────────────────────
      // DOSEN — Tab navigation shell (4 tab)
      // ─────────────────────────────────────────────────────
      GoRoute(
        path   : '/dosen/home',
        builder: (context, state) =>
            const MainDosenScreen(initialIndex: 0),
      ),
      GoRoute(
        path   : '/dosen/monitor',
        builder: (context, state) {
          final extra   = state.extra as Map<String, dynamic>?;
          final sesiId  = extra?['sesi_id'] as String?
                       ?? extra?['id']      as String?;
          return MainDosenScreen(
            initialIndex  : 1,
            monitorSesiId : sesiId,
          );
        },
      ),
      GoRoute(
        path   : '/dosen/rekap-list',
        builder: (context, state) =>
            const MainDosenScreen(initialIndex: 2),
      ),
      GoRoute(
        path   : '/dosen/profil',
        builder: (context, state) =>
            const MainDosenScreen(initialIndex: 3),
      ),

      // ── Dosen standalone screens ─────────────────────────
      GoRoute(
        path   : '/dosen/kode',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return KodeDisplayScreen(sesiData: args);
        },
      ),
      GoRoute(
        path   : '/dosen/rekap/:sesiId',
        builder: (context, state) {
          final sesiId = state.pathParameters['sesiId']!;
          return RekapScreen(sesiId: sesiId);
        },
      ),
      GoRoute(
        path   : '/dosen/matakuliah/:mkId',
        builder: (context, state) {
          final mkId = state.pathParameters['mkId']!;
          return DetailMatakuliahScreen(matakuliahId: mkId);
        },
      ),

      // ── Rute lama dosen (redirect) ───────────────────────
      GoRoute(
        path    : '/dosen/dashboard',
        redirect: (context, state) => '/dosen/monitor',
      ),
      GoRoute(
        path    : '/dosen/buka-sesi',
        redirect: (_, __) => '/dosen/home',
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Halaman tidak ditemukan: ${state.matchedLocation}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Kembali ke Login'),
            ),
          ],
        ),
      ),
    ),
  );
}