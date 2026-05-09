// lib/widgets/slot_label.dart
// v2.1.0 — Widget label slot ke jam (07:00-09:30)
// Dipakai di JadwalScreen, BerandaDosenScreen, JadwalDosenScreen

import 'package:flutter/material.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/models/kelas.dart';

/// Widget label slot waktu yang mengkonversi slot → jam
/// Contoh output: "Slot 1–3  |  07:00 – 09:30"
class SlotLabel extends StatelessWidget {
  final int?   slotMulai;
  final int?   slotSelesai;

  /// Tampilkan icon jam (default: true)
  final bool   showIcon;

  /// Tampilkan nomor slot (default: true)
  final bool   showSlotNumber;

  /// Ukuran font (default: 12)
  final double fontSize;

  /// Warna teks (default: kTextSecondary)
  final Color? color;

  const SlotLabel({
    super.key,
    this.slotMulai,
    this.slotSelesai,
    this.showIcon      = true,
    this.showSlotNumber = true,
    this.fontSize      = 12,
    this.color,
  });

  String _buildLabel() {
    if (slotMulai == null) return '-';

    final selesai = slotSelesai ?? slotMulai!;
    final jamMulai    = SlotDefaults.jamMulai(slotMulai!);
    final jamSelesai  = SlotDefaults.jamSelesai(selesai);

    if (showSlotNumber) {
      if (slotMulai == selesai) {
        return 'Slot $slotMulai  |  $jamMulai – $jamSelesai';
      }
      return 'Slot $slotMulai–$selesai  |  $jamMulai – $jamSelesai';
    }
    return '$jamMulai – $jamSelesai';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.kTextSecondary;

    if (!showIcon) {
      return Text(
        _buildLabel(),
        style: AppTypography.label.copyWith(
          color   : textColor,
          fontSize: fontSize,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size : fontSize + 1,
          color: textColor,
        ),
        const SizedBox(width: 4),
        Text(
          _buildLabel(),
          style: AppTypography.label.copyWith(
            color   : textColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}

/// Versi compact — hanya jam tanpa slot number dan icon
/// Contoh: "07:00 – 09:30"
class SlotLabelCompact extends StatelessWidget {
  final int? slotMulai;
  final int? slotSelesai;
  final double fontSize;
  final Color? color;

  const SlotLabelCompact({
    super.key,
    this.slotMulai,
    this.slotSelesai,
    this.fontSize = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SlotLabel(
      slotMulai      : slotMulai,
      slotSelesai    : slotSelesai,
      showIcon       : false,
      showSlotNumber : false,
      fontSize       : fontSize,
      color          : color,
    );
  }
}

/// Label jam dari string langsung (jika backend sudah kirim jam_mulai/jam_selesai)
class JamLabel extends StatelessWidget {
  final String? jamMulai;
  final String? jamSelesai;
  final bool    showIcon;
  final double  fontSize;
  final Color?  color;

  const JamLabel({
    super.key,
    this.jamMulai,
    this.jamSelesai,
    this.showIcon = true,
    this.fontSize = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.kTextSecondary;
    final mulai     = jamMulai   ?? '-';
    final selesai   = jamSelesai ?? '-';
    final label     = '$mulai – $selesai';

    if (!showIcon) {
      return Text(
        label,
        style: AppTypography.label.copyWith(
          color   : textColor,
          fontSize: fontSize,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded, size: fontSize + 1, color: textColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.label.copyWith(
            color   : textColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}