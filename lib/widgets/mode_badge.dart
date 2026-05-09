// lib/widgets/mode_badge.dart
// v2.1.0 — Badge mode Online/Offline reusable
// Dipakai di seluruh app: JadwalScreen, RiwayatScreen, RekapScreen, dll.

import 'package:flutter/material.dart';
import 'package:presensi_app/core/theme.dart';

/// Badge mode presensi: Online (biru navy) atau Offline/Tatap Muka (hijau)
class ModeBadge extends StatelessWidget {
  final String mode;

  /// Tampilkan icon (default: true)
  final bool showIcon;

  /// Ukuran font (default: 10)
  final double fontSize;

  /// Padding custom
  final EdgeInsets? padding;

  const ModeBadge({
    super.key,
    required this.mode,
    this.showIcon = true,
    this.fontSize = 10,
    this.padding,
  });

  bool get _isOnline => mode.toLowerCase() == 'online';

  Color get _color => AppColors.modeColor(mode);

  String get _label => _isOnline ? 'Online' : 'Tatap Muka';

  IconData get _icon =>
      _isOnline ? Icons.laptop_outlined : Icons.location_on_outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color       : _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: _color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_icon, size: fontSize + 1, color: _color),
            const SizedBox(width: 4),
          ],
          Text(
            _label,
            style: AppTypography.badge.copyWith(
              color   : _color,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Versi besar dengan label lebih panjang + background lebih prominent
class ModeBadgeLarge extends StatelessWidget {
  final String mode;

  const ModeBadgeLarge({super.key, required this.mode});

  bool get _isOnline => mode.toLowerCase() == 'online';
  Color get _color   => AppColors.modeColor(mode);
  String get _label  => _isOnline ? '💻 Online' : '📍 Tatap Muka';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color       : _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: _color.withOpacity(0.40), width: 1.5),
      ),
      child: Text(
        _label,
        style: AppTypography.badge.copyWith(
          color    : _color,
          fontSize : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Badge status tamu
class TamuBadge extends StatelessWidget {
  const TamuBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color       : AppColors.kWarning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(
          color: AppColors.kWarning.withOpacity(0.40), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined,
              size: 10, color: AppColors.kWarning),
          const SizedBox(width: 3),
          Text(
            'Tamu',
            style: AppTypography.badge.copyWith(
              color   : AppColors.kWarning,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge status presensi: hadir, terlambat, absen, izin, sakit
class StatusPresensiiBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusPresensiiBadge({
    super.key,
    required this.status,
    this.fontSize = 10,
  });

  Color get _color => AppColors.statusColor(status);

  String get _label {
    switch (status.toLowerCase()) {
      case 'hadir'    : return 'Hadir';
      case 'terlambat': return 'Terlambat';
      case 'absen'    : return 'Absen';
      case 'izin'     : return 'Izin';
      case 'sakit'    : return 'Sakit';
      default         : return status;
    }
  }

  IconData get _icon {
    switch (status.toLowerCase()) {
      case 'hadir'    : return Icons.check_circle_outline;
      case 'terlambat': return Icons.watch_later_outlined;
      case 'absen'    : return Icons.cancel_outlined;
      case 'izin'     : return Icons.info_outline;
      case 'sakit'    : return Icons.local_hospital_outlined;
      default         : return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color       : _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: _color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: fontSize + 1, color: _color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: AppTypography.badge.copyWith(
              color   : _color,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}