import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/providers/auth_provider.dart';

class HasilScreen extends StatelessWidget {
  /// data map berisi:
  /// - success   : bool
  /// - status    : String ('hadir'|'terlambat'|'absen')
  /// - akurasi   : double
  /// - waktu     : String (ISO datetime)
  /// - mode      : String ('offline'|'online')
  /// - pesan     : String
  final Map<String, dynamic> data;

  const HasilScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool   success = data['success'] as bool? ?? false;
    final String status  = data['status']  as String? ?? '';
    final double akurasi = (data['akurasi'] as num?)?.toDouble() ?? 0.0;
    final String waktuRaw= data['waktu']   as String? ?? '';
    final String mode    = data['mode']    as String? ?? '';
    final String pesan   = data['pesan']   as String? ?? '';
    final user           = context.read<AuthProvider>().currentUser;

    // Format waktu
    String waktuFormatted = '-';
    if (waktuRaw.isNotEmpty) {
      try {
        final dt = DateTime.parse(waktuRaw).toLocal();
        waktuFormatted = DateFormat('dd MMM yyyy, HH:mm:ss').format(dt);
      } catch (_) {
        waktuFormatted = waktuRaw;
      }
    }

    // Warna & ikon berdasarkan status
    Color  statusColor;
    Color  bgColor;
    IconData statusIcon;
    String statusLabel;

    if (!success) {
      statusColor = Colors.red.shade400;
      bgColor     = Colors.red.shade900.withOpacity(0.3);
      statusIcon  = Icons.cancel_rounded;
      statusLabel = 'Presensi Gagal';
    } else {
      switch (status.toLowerCase()) {
        case 'hadir':
          statusColor = Colors.greenAccent;
          bgColor     = Colors.green.shade900.withOpacity(0.3);
          statusIcon  = Icons.check_circle_rounded;
          statusLabel = 'HADIR';
          break;
        case 'terlambat':
          statusColor = Colors.orangeAccent;
          bgColor     = Colors.orange.shade900.withOpacity(0.3);
          statusIcon  = Icons.access_time_rounded;
          statusLabel = 'TERLAMBAT';
          break;
        default:
          statusColor = Colors.blueAccent;
          bgColor     = Colors.blue.shade900.withOpacity(0.3);
          statusIcon  = Icons.info_rounded;
          statusLabel = status.toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ── Ikon hasil utama ──────────────────────────
              Container(
                width : 110,
                height: 110,
                decoration: BoxDecoration(
                  color       : bgColor,
                  shape       : BoxShape.circle,
                  border      : Border.all(color: statusColor, width: 3),
                ),
                child: Icon(statusIcon, color: statusColor, size: 60),
              ),
              const SizedBox(height: 20),

              // Status label
              Text(
                statusLabel,
                style: TextStyle(
                  color     : statusColor,
                  fontSize  : 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),

              // Pesan
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 36),

              // ── Card detail ───────────────────────────────
              Container(
                padding   : const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color        : Colors.white.withOpacity(0.06),
                  borderRadius : BorderRadius.circular(16),
                  border       : Border.all(color: Colors.white12),
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
                    if (success) ...[
                      _Divider(),
                      _DetailRow(
                        icon : Icons.face_retouching_natural_rounded,
                        label: 'Akurasi Wajah',
                        value: '${akurasi.toStringAsFixed(1)}%',
                        valueColor: akurasi >= 85
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                    ],
                    _Divider(),
                    _DetailRow(
                      icon : mode == 'online'
                          ? Icons.video_call_rounded
                          : Icons.location_on_rounded,
                      label: 'Mode Kelas',
                      value: mode == 'online' ? '💻 Online' : '📍 Offline (Tatap Muka)',
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Tombol aksi ───────────────────────────────
              SizedBox(
                width : double.infinity,
                height: 54,
                child : ElevatedButton.icon(
                  onPressed: () => context.go('/scan'),
                  icon : const Icon(Icons.home_rounded),
                  label: const Text(
                    'Kembali ke Beranda',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    shape          : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go('/riwayat'),
                child: const Text(
                  'Lihat Riwayat Kehadiran',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Baris detail ──────────────────────────────────────────────

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
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color     : valueColor ?? Colors.white,
                fontSize  : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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