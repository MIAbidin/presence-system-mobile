// lib/screens/hasil_screen.dart
// v2.1.0 — Fase 3 Langkah 3.4 SELESAI
//
// PERUBAHAN DARI v1.x:
// ✅ TAMBAH: field kelas_info dan is_tamu dari data map
// ✅ TAMBAH: KelasBadge di card detail jika ada info kelas
// ✅ TAMBAH: TamuBadge saat mahasiswa presensi sebagai tamu
// ✅ TAMBAH: ModeBadge yang lebih informatif (inline badge)
// ✅ UPDATE: Lottie animation untuk sukses/gagal (dengan fallback Icon)
// ✅ UPDATE: Tema UMS — Navy + Gold, tipografi konsisten

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';

class HasilScreen extends StatelessWidget {
  /// data map berisi:
  /// - success    : bool
  /// - status     : String ('hadir'|'terlambat'|'absen')
  /// - akurasi    : double
  /// - waktu      : String (ISO datetime)
  /// - mode       : String ('offline'|'online')
  /// - pesan      : String
  /// - kelas_info : String? — kode kelas (A/B/C) [BARU v2.1.0]
  /// - is_tamu    : bool    — presensi sebagai tamu [BARU v2.1.0]
  final Map<String, dynamic> data;

  const HasilScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool    success   = data['success']    as bool?   ?? false;
    final String  status    = data['status']     as String? ?? '';
    final double  akurasi   = (data['akurasi']   as num?)?.toDouble() ?? 0.0;
    final String  waktuRaw  = data['waktu']      as String? ?? '';
    final String  mode      = data['mode']       as String? ?? '';
    final String  pesan     = data['pesan']      as String? ?? '';
    // v2.1.0 — field baru
    final String? kelasInfo = data['kelas_info'] as String?;
    final bool    isTamu    = data['is_tamu']    as bool?   ?? false;

    final user = context.read<AuthProvider>().currentUser;

    // ── Format waktu ─────────────────────────────────────────
    String waktuFormatted = '-';
    if (waktuRaw.isNotEmpty) {
      try {
        final dt = DateTime.parse(waktuRaw).toLocal();
        waktuFormatted =
            DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(dt);
      } catch (_) {
        waktuFormatted = waktuRaw;
      }
    }

    // ── Warna & ikon berdasarkan status ──────────────────────
    final _StatusConfig cfg =
        _StatusConfig.fromStatus(status, success: success);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Animasi Lottie / Icon hasil ───────────────
              _buildResultAnimation(success, cfg),
              const SizedBox(height: 20),

              // ── Status label ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cfg.label,
                    style: AppTypography.heading2.copyWith(
                      color       : cfg.color,
                      letterSpacing: 1.5,
                    ),
                  ),
                  // v2.1.0: Badge tamu di samping status label
                  if (isTamu && success) ...[
                    const SizedBox(width: 8),
                    const TamuBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // ── Pesan ─────────────────────────────────────
              Text(
                pesan,
                textAlign: TextAlign.center,
                style    : AppTypography.body2.copyWith(
                  color : Colors.white70,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // ── Card detail ───────────────────────────────
              _buildDetailCard(
                user         : user,
                waktuFormatted: waktuFormatted,
                akurasi      : akurasi,
                mode         : mode,
                kelasInfo    : kelasInfo,
                isTamu       : isTamu,
                success      : success,
                cfg          : cfg,
              ),

              const SizedBox(height: 36),

              // ── Tombol kembali ke beranda ─────────────────
              SizedBox(
                width : double.infinity,
                height: 52,
                child : ElevatedButton.icon(
                  onPressed: () => context.go('/scan'),
                  icon : const Icon(Icons.home_rounded, size: 20),
                  label: Text(
                    'Kembali ke Beranda',
                    style: AppTypography.button.copyWith(
                        color: AppColors.kNavyDark),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kGold,
                    foregroundColor: AppColors.kNavyDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Link riwayat ──────────────────────────────
              TextButton(
                onPressed: () => context.go('/riwayat'),
                child: Text(
                  'Lihat Riwayat Kehadiran',
                  style: AppTypography.buttonSmall.copyWith(
                      color: Colors.white38),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lottie animation dengan fallback ke Icon ──────────────

  Widget _buildResultAnimation(bool success, _StatusConfig cfg) {
    // Path Lottie animation — sesuai pubspec.yaml assets/animations/
    final lottieAsset = success
        ? 'assets/animations/success.json'
        : 'assets/animations/error.json';

    return SizedBox(
      width : 140,
      height: 140,
      child : _LottieOrFallback(
        assetPath : lottieAsset,
        fallbackIcon: cfg.icon,
        fallbackColor: cfg.color,
        fallbackBg   : cfg.bgColor,
      ),
    );
  }

  // ── Card detail presensi ──────────────────────────────────

  Widget _buildDetailCard({
    required dynamic user,
    required String  waktuFormatted,
    required double  akurasi,
    required String  mode,
    required String? kelasInfo,
    required bool    isTamu,
    required bool    success,
    required _StatusConfig cfg,
  }) {
    return Container(
      padding   : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border      : Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon : Icons.person_rounded,
            label: 'Nama',
            value: user?.namaLengkap ?? '-',
          ),
          _Divider(),
          _DetailRow(
            icon : Icons.badge_rounded,
            label: 'NIM',
            value: user?.nimNidn ?? '-',
          ),
          _Divider(),
          _DetailRow(
            icon : Icons.access_time_rounded,
            label: 'Waktu Presensi',
            value: waktuFormatted,
          ),

          // v2.1.0: Tampilkan kelas jika ada
          if (kelasInfo != null && kelasInfo.isNotEmpty) ...[
            _Divider(),
            _DetailRowWidget(
              icon : Icons.class_outlined,
              label: 'Kelas',
              child: KelasBadge(kodeKelas: kelasInfo),
            ),
          ],

          // v2.1.0: Tampilkan badge tamu jika presensi sebagai tamu
          if (isTamu) ...[
            _Divider(),
            _DetailRowWidget(
              icon : Icons.person_add_outlined,
              label: 'Status',
              child: const TamuBadge(),
            ),
          ],

          if (success) ...[
            _Divider(),
            _DetailRow(
              icon      : Icons.face_retouching_natural_rounded,
              label     : 'Akurasi Wajah',
              value     : '${akurasi.toStringAsFixed(1)}%',
              valueColor: akurasi >= 85
                  ? AppColors.kStatusHadir
                  : AppColors.kStatusTerlambat,
            ),
          ],

          _Divider(),

          // v2.1.0: ModeBadge yang lebih informatif
          _DetailRowWidget(
            icon : mode == 'online'
                ? Icons.laptop_outlined
                : Icons.location_on_outlined,
            label: 'Mode Kelas',
            child: ModeBadgeLarge(mode: mode.isEmpty ? 'offline' : mode),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LOTTIE OR FALLBACK
// ══════════════════════════════════════════════════════════════

/// Widget yang mencoba render Lottie animation.
/// Jika asset tidak ditemukan (belum ditambah), fallback ke Icon.
class _LottieOrFallback extends StatelessWidget {
  final String   assetPath;
  final IconData fallbackIcon;
  final Color    fallbackColor;
  final Color    fallbackBg;

  const _LottieOrFallback({
    required this.assetPath,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.fallbackBg,
  });

  @override
  Widget build(BuildContext context) {
    return _LottieWidget(
      assetPath   : assetPath,
      fallbackIcon : fallbackIcon,
      fallbackColor: fallbackColor,
      fallbackBg   : fallbackBg,
    );
  }
}

class _LottieWidget extends StatelessWidget {
  final String   assetPath;
  final IconData fallbackIcon;
  final Color    fallbackColor;
  final Color    fallbackBg;

  const _LottieWidget({
    required this.assetPath,
    required this.fallbackIcon,
    required this.fallbackColor,
    required this.fallbackBg,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return Lottie.asset(
        assetPath,
        repeat: false,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } catch (_) {
      return _buildFallback();
    }
  }

  Widget _buildFallback() {
    return Container(
      width : 120,
      height: 120,
      decoration: BoxDecoration(
        color : fallbackBg,
        shape : BoxShape.circle,
        border: Border.all(color: fallbackColor, width: 3),
      ),
      child: Icon(fallbackIcon, color: fallbackColor, size: 60),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STATUS CONFIG — warna, ikon, label berdasarkan status
// ══════════════════════════════════════════════════════════════

class _StatusConfig {
  final Color    color;
  final Color    bgColor;
  final IconData icon;
  final String   label;

  const _StatusConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.label,
  });

  factory _StatusConfig.fromStatus(String status, {required bool success}) {
    if (!success) {
      return _StatusConfig(
        color  : AppColors.kStatusAbsen,
        bgColor: AppColors.kStatusAbsen.withOpacity(0.15),
        icon   : Icons.cancel_rounded,
        label  : 'PRESENSI GAGAL',
      );
    }
    switch (status.toLowerCase()) {
      case 'hadir':
        return _StatusConfig(
          color  : AppColors.kStatusHadir,
          bgColor: AppColors.kStatusHadir.withOpacity(0.15),
          icon   : Icons.check_circle_rounded,
          label  : 'HADIR',
        );
      case 'terlambat':
        return _StatusConfig(
          color  : AppColors.kStatusTerlambat,
          bgColor: AppColors.kStatusTerlambat.withOpacity(0.15),
          icon   : Icons.access_time_rounded,
          label  : 'TERLAMBAT',
        );
      default:
        return _StatusConfig(
          color  : AppColors.kInfo,
          bgColor: AppColors.kInfo.withOpacity(0.15),
          icon   : Icons.info_rounded,
          label  : status.toUpperCase(),
        );
    }
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET PENDUKUNG
// ══════════════════════════════════════════════════════════════

/// Baris detail teks (label + value string)
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child  : Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: Colors.white54),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style    : AppTypography.bodyBold.copyWith(
                color    : valueColor ?? Colors.white,
                fontSize : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris detail dengan widget kustom (badge, chip, dll.)
class _DetailRowWidget extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget   child;

  const _DetailRowWidget({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child  : Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: Colors.white54),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(color: Colors.white.withOpacity(0.08), height: 1);
}