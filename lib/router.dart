// lib/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/providers/auth_provider.dart';

// Screens — Mahasiswa
import 'package:presensi_app/screens/login_screen.dart';
import 'package:presensi_app/screens/register_face_screen.dart';
import 'package:presensi_app/screens/kode_sesi_screen.dart';
import 'package:presensi_app/screens/hasil_screen.dart';
import 'package:presensi_app/widgets/bottom_nav.dart';

// Screens — Dosen
import 'package:presensi_app/screens/dosen/dashboard_dosen.dart';
import 'package:presensi_app/screens/dosen/buka_sesi_screen.dart';
import 'package:presensi_app/screens/dosen/kode_display_screen.dart';
import 'package:presensi_app/screens/dosen/rekap_screen.dart';

// Halaman loading saat cek auth
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E3A5F),
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

      // Masih loading → tampilkan splash, jangan redirect ke mana-mana
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // Dari splash → redirect ke tempat yang benar setelah auth selesai
      if (loc == '/splash') {
        if (status == AuthStatus.unauthenticated) return '/login';
        // authenticated — cek role
        if (user?.isDosen == true) return '/dosen/dashboard';
        if (user?.isMahasiswa == true && !user!.isFaceRegistered) {
          return '/register-face';
        }
        return '/home';
      }

      // Belum login → paksa ke login
      if (status == AuthStatus.unauthenticated) {
        return loc == '/login' ? null : '/login';
      }

      // Mahasiswa belum daftar wajah → paksa register face
      if (user != null && user.isMahasiswa && !user.isFaceRegistered) {
        if (loc != '/register-face') return '/register-face';
        return null;
      }

      // Sudah login dan masuk halaman login → redirect ke home
      if (loc == '/login') {
        return user?.isDosen == true ? '/dosen/dashboard' : '/home';
      }

      // Dosen tidak boleh akses route mahasiswa
      if (user?.isDosen == true) {
        const mahasiswaRoutes = ['/home', '/scan', '/register-face', '/riwayat'];
        if (mahasiswaRoutes.contains(loc)) return '/dosen/dashboard';
      }

      return null;
    },

    routes: [
      // ── Splash / Loading ──────────────────────────────────
      GoRoute(
        path   : '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────
      GoRoute(
        path   : '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Mahasiswa: Main tab navigation shell ──────────────
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

      // ── Mahasiswa: standalone screens ─────────────────────
      GoRoute(
        path   : '/register-face',
        builder: (context, state) => const RegisterFaceScreen(),
      ),
      GoRoute(
        path   : '/kode-sesi',
        builder: (context, state) {
          final sesiId = state.extra as String?;
          return KodeSesiScreen(sesiId: sesiId);
        },
      ),
      GoRoute(
        path   : '/hasil',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return HasilScreen(data: args);
        },
      ),

      // ── Dosen ─────────────────────────────────────────────
      GoRoute(
        path   : '/dosen/dashboard',
        builder: (context, state) {
          final sesiData = state.extra as Map<String, dynamic>?;
          return DashboardDosen(sesiData: sesiData);
        },
      ),
      GoRoute(
        path   : '/dosen/buka-sesi',
        builder: (context, state) => const BukaSesiScreen(),
      ),
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