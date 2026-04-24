// lib/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';

// Screens — Mahasiswa
import 'package:presensi_app/screens/login_screen.dart';
import 'package:presensi_app/screens/register_face_screen.dart';
import 'package:presensi_app/screens/scan_screen.dart';
import 'package:presensi_app/screens/kode_sesi_screen.dart';
import 'package:presensi_app/screens/hasil_screen.dart';
import 'package:presensi_app/screens/riwayat_screen.dart';

// Screens — Dosen
import 'package:presensi_app/screens/dosen/dashboard_dosen.dart';
import 'package:presensi_app/screens/dosen/buka_sesi_screen.dart';
import 'package:presensi_app/screens/dosen/kode_display_screen.dart';
import 'package:presensi_app/screens/dosen/rekap_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation  : '/login',

    // ── Redirect guard ─────────────────────────────────────
    redirect: (context, state) {
      final status = authProvider.status;
      final user   = authProvider.currentUser;
      final loc    = state.matchedLocation;

      if (status == AuthStatus.unknown) return null;

      if (status == AuthStatus.unauthenticated) {
        return loc == '/login' ? null : '/login';
      }

      // Mahasiswa belum daftar wajah → paksa ke /register-face
      if (user != null && user.isMahasiswa && !user.isFaceRegistered) {
        if (loc != '/register-face') return '/register-face';
      }

      // Sudah login dan di halaman login → redirect ke home sesuai role
      if (loc == '/login') {
        return user?.isDosen == true ? '/dosen/dashboard' : '/scan';
      }

      // Dosen mencoba akses route mahasiswa
      if (user?.isDosen == true && !loc.startsWith('/dosen')) {
        if (['/scan', '/register-face', '/riwayat'].contains(loc)) {
          return '/dosen/dashboard';
        }
      }

      return null;
    },

    routes: [
      // ── Auth ─────────────────────────────────────────────
      GoRoute(
        path   : '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Mahasiswa ─────────────────────────────────────────
      GoRoute(
        path   : '/register-face',
        builder: (context, state) => const RegisterFaceScreen(),
      ),
      GoRoute(
        path   : '/scan',
        builder: (context, state) => const ScanScreen(),
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
      GoRoute(
        path   : '/riwayat',
        builder: (context, state) => const RiwayatScreen(),
      ),

      // ── Dosen ─────────────────────────────────────────────
      GoRoute(
        path   : '/dosen/dashboard',
        builder: (context, state) {
          // extra bisa berisi Map<String, dynamic> dengan sesi_id
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
          // extra berisi response dari POST /sesi/buka
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

    // ── Error page ────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Halaman tidak ditemukan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    ),
  );
}