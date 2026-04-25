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

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation  : '/login',

    redirect: (context, state) {
      final status = authProvider.status;
      final user   = authProvider.currentUser;
      final loc    = state.matchedLocation;

      // Still checking auth state — don't redirect yet
      if (status == AuthStatus.unknown) return null;

      // Not logged in → go to login (unless already there)
      if (status == AuthStatus.unauthenticated) {
        return loc == '/login' ? null : '/login';
      }

      // Logged in but face not registered → force to register-face
      // (except if already going there)
      if (user != null && user.isMahasiswa && !user.isFaceRegistered) {
        if (loc != '/register-face') return '/register-face';
        return null;
      }

      // Already logged in and on login page → go to home by role
      if (loc == '/login') {
        return user?.isDosen == true ? '/dosen/dashboard' : '/home';
      }

      // Dosen trying to access mahasiswa-only routes
      if (user?.isDosen == true) {
        const mahasiswaRoutes = ['/home', '/scan', '/register-face', '/riwayat'];
        if (mahasiswaRoutes.contains(loc)) return '/dosen/dashboard';
      }

      return null;
    },

    routes: [
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