// lib/widgets/kelas_badge.dart
// v2.1.0 — Badge kelas A/B/C reusable
// Dipakai di seluruh app: JadwalScreen, HomeScreen, RiwayatScreen, dll.

import 'package:flutter/material.dart';
import 'package:presensi_app/core/theme.dart';

/// Badge pill untuk kode kelas (A, B, C, D, E)
/// Warna otomatis berdasarkan kode kelas via AppColors.kelasColor()
class KelasBadge extends StatelessWidget {
  /// Kode kelas: 'A', 'B', 'C', dll.
  final String kodeKelas;

  /// Ukuran font badge (default: 10)
  final double fontSize;

  /// Padding custom (default: horizontal 8, vertical 3)
  final EdgeInsets? padding;

  /// Tampilkan prefix "Kelas " (default: true)
  final bool showPrefix;

  const KelasBadge({
    super.key,
    required this.kodeKelas,
    this.fontSize  = 10,
    this.padding,
    this.showPrefix = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.kelasColor(kodeKelas);
    final label = showPrefix ? 'Kelas $kodeKelas' : kodeKelas;

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(
          color     : color,
          fontSize  : fontSize,
        ),
      ),
    );
  }
}

/// Versi lebih besar untuk header/card featured
class KelasBadgeLarge extends StatelessWidget {
  final String kodeKelas;

  const KelasBadgeLarge({super.key, required this.kodeKelas});

  @override
  Widget build(BuildContext context) {
    return KelasBadge(
      kodeKelas : kodeKelas,
      fontSize  : 12,
      padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }
}

/// Row kelas + mode sekaligus (dipakai di card jadwal)
class KelasModeBadgeRow extends StatelessWidget {
  final String? kodeKelas;
  final String? mode;

  const KelasModeBadgeRow({
    super.key,
    this.kodeKelas,
    this.mode,
  });

  @override
  Widget build(BuildContext context) {
    if (kodeKelas == null && mode == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: [
        if (kodeKelas != null && kodeKelas!.isNotEmpty)
          KelasBadge(kodeKelas: kodeKelas!),
        if (mode != null && mode!.isNotEmpty)
          ModeBadgeInline(mode: mode!),
      ],
    );
  }
}

/// Inline mode badge (dipakai di KelasModeBadgeRow)
class ModeBadgeInline extends StatelessWidget {
  final String mode;

  const ModeBadgeInline({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isOnline = mode.toLowerCase() == 'online';
    final color    = AppColors.modeColor(mode);
    final label    = isOnline ? 'Online' : 'Offline';
    final icon     = isOnline ? Icons.laptop_outlined : Icons.location_on_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color   : color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}