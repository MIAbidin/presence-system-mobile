// lib/widgets/empty_error_state.dart
// v2.1.0 — Widget empty state & error state konsisten seluruh app
// Dipakai di TamuSesiListScreen, RiwayatScreen, JadwalScreen, dll.

import 'package:flutter/material.dart';
import 'package:presensi_app/core/theme.dart';

// ══════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════

/// Empty state standar — tampil saat list/data kosong
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final Widget?  action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Container(
              width     : 72,
              height    : 72,
              decoration: BoxDecoration(
                color       : AppColors.kSoftGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: AppColors.kTextSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style    : AppTypography.heading3.copyWith(
                fontSize: 16,
                color   : AppColors.kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style    : AppTypography.body2,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state khusus "Tidak ada jadwal aktif" di ScanScreen
class NoJadwalAktifState extends StatelessWidget {
  final VoidCallback? onIkutTamu;

  const NoJadwalAktifState({super.key, this.onIkutTamu});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Container(
              width     : 80,
              height    : 80,
              decoration: BoxDecoration(
                color       : AppColors.kNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size : 40,
                color: AppColors.kNavy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tidak Ada Kelas Aktif',
              style    : AppTypography.heading3.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak ada sesi presensi yang aktif untuk jadwal Anda saat ini.',
              style    : AppTypography.body2,
              textAlign: TextAlign.center,
            ),
            if (onIkutTamu != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: onIkutTamu,
                  icon     : const Icon(Icons.person_add_outlined, size: 18),
                  label    : const Text('Ikut sebagai Tamu'),
                  style    : OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kNavy,
                    side: const BorderSide(color: AppColors.kNavy, width: 1.5),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ikut kelas yang tidak ada di jadwal Anda',
                style: AppTypography.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state khusus sesi tamu kosong
class NoSesiTamuState extends StatelessWidget {
  const NoSesiTamuState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon    : Icons.person_search_outlined,
      title   : 'Tidak Ada Sesi Tersedia',
      subtitle:
          'Tidak ada sesi yang bisa Anda ikuti sebagai tamu saat ini.\n\n'
          'Minta dosen untuk menambahkan Anda sebagai tamu, atau tunggu dosen mengaktifkan izin tamu.',
      action  : null,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ERROR STATE
// ══════════════════════════════════════════════════════════════

/// Error state standar — tampil saat network/server error
class ErrorState extends StatelessWidget {
  final String?      message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Container(
              width     : 72,
              height    : 72,
              decoration: BoxDecoration(
                color       : AppColors.kDanger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size : 36,
                color: AppColors.kDanger,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tidak Dapat Terhubung',
              style    : AppTypography.heading3.copyWith(
                fontSize: 16,
                color   : AppColors.kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Periksa koneksi internet Anda dan coba lagi.',
              style    : AppTypography.body2,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon     : const Icon(Icons.refresh_rounded, size: 18),
                  label    : const Text('Coba Lagi'),
                  style    : ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kNavy,
                    foregroundColor: Colors.white,
                    minimumSize    : const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// INFO BOX / BANNER
// ══════════════════════════════════════════════════════════════

/// Info box kuning — peringatan jadwal pengganti
class JadwalPenggantiAlert extends StatelessWidget {
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final String? mode;

  const JadwalPenggantiAlert({
    super.key,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color       : AppColors.kGold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border      : Border(
          left: BorderSide(color: AppColors.kGold, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded,
              size: 18, color: AppColors.kWarning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children          : [
                Text(
                  'Jadwal Diganti',
                  style: AppTypography.label.copyWith(
                    color     : AppColors.kWarning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _buildDetail(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildDetail() {
    final parts = <String>[];
    if (jamMulai != null && jamSelesai != null) {
      parts.add('$jamMulai – $jamSelesai');
    }
    if (ruangan != null) parts.add(ruangan!);
    if (mode != null) {
      parts.add(mode!.toLowerCase() == 'online' ? 'Online' : 'Tatap Muka');
    }
    return parts.join(' · ');
  }
}

/// Info box neutral — notif informatif
class InfoBanner extends StatelessWidget {
  final String  message;
  final IconData? icon;
  final Color?  color;

  const InfoBanner({
    super.key,
    required this.message,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.kNavy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color       : c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(color: c.withOpacity(0.20), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}