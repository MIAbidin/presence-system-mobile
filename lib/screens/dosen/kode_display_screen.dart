// lib/screens/dosen/kode_display_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';

class KodeDisplayScreen extends StatefulWidget {
  /// sesiData berisi response dari POST /sesi/buka
  /// field: id, kode_sesi, detik_tersisa, mode, matakuliah, pertemuan_ke, dll
  final Map<String, dynamic> sesiData;

  const KodeDisplayScreen({super.key, required this.sesiData});

  @override
  State<KodeDisplayScreen> createState() => _KodeDisplayScreenState();
}

class _KodeDisplayScreenState extends State<KodeDisplayScreen> {
  // ── Data sesi ─────────────────────────────────────────────
  late String _sesiId;
  late String _kode;
  late int    _detikTersisa;

  // ── Countdown timer ───────────────────────────────────────
  Timer? _countdownTimer;
  bool   _isExpired = false;

  // ── State operasi ─────────────────────────────────────────
  bool _isExtending  = false;
  bool _isRegening   = false;
  bool _isClosing    = false;

  @override
  void initState() {
    super.initState();
    _sesiId       = widget.sesiData['id']            as String? ?? '';
    _kode         = widget.sesiData['kode_sesi']     as String? ?? '------';
    _detikTersisa = widget.sesiData['detik_tersisa'] as int?    ?? 1800;

    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_detikTersisa > 0) {
          _detikTersisa--;
        } else {
          _isExpired = true;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  String get _timerLabel {
    final mnt = _detikTersisa ~/ 60;
    final dtk = _detikTersisa % 60;
    return '${mnt.toString().padLeft(2, '0')}:${dtk.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_detikTersisa > 300) return Colors.greenAccent;
    if (_detikTersisa > 60)  return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ── POST /sesi/extend ─────────────────────────────────────
  Future<void> _extendKode(int tambahanMenit) async {
    setState(() => _isExtending = true);
    try {
      final response = await ApiClient().post(
        '/sesi/extend',
        body: {'sesi_id': _sesiId, 'tambahan_menit': tambahanMenit},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _detikTersisa = data['detik_tersisa'] as int? ?? _detikTersisa + tambahanMenit * 60;
          _isExpired    = false;
        });
        _startCountdown();
        _showSnack('Durasi diperpanjang +$tambahanMenit menit ✓');
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal perpanjang', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isExtending = false);
    }
  }

  // ── POST /sesi/regen-kode ─────────────────────────────────
  Future<void> _regenKode() async {
    final confirm = await _showConfirmDialog(
      title  : 'Generate Kode Baru?',
      content: 'Kode lama ($_kode) akan langsung hangus.\n'
               'Mahasiswa yang belum presensi harus pakai kode baru.',
      okLabel: 'Ya, Generate',
      okColor: Colors.orange.shade700,
    );
    if (!confirm) return;

    setState(() => _isRegening = true);
    try {
      final response = await ApiClient().post(
        '/sesi/regen-kode?sesi_id=$_sesiId&durasi_menit=30',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _kode         = data['kode_sesi']     as String? ?? _kode;
          _detikTersisa = data['detik_tersisa'] as int?    ?? 1800;
          _isExpired    = false;
        });
        _startCountdown();
        _showSnack('Kode baru: $_kode (berlaku 30 menit)');
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal regenerasi kode', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isRegening = false);
    }
  }

  // ── POST /sesi/tutup ──────────────────────────────────────
  Future<void> _tutupSesi() async {
    final confirm = await _showConfirmDialog(
      title  : 'Akhiri Sesi?',
      content: 'Sesi akan ditutup dan kode langsung hangus.\n'
               'Mahasiswa yang belum presensi akan dicatat Absen.',
      okLabel: 'Ya, Akhiri Sesi',
      okColor: Colors.red.shade700,
    );
    if (!confirm) return;

    setState(() => _isClosing = true);
    try {
      final response = await ApiClient().post('/sesi/tutup?sesi_id=$_sesiId');
      if (response.statusCode == 200) {
        if (!mounted) return;
        _countdownTimer?.cancel();
        context.go('/dosen/rekap/$_sesiId');
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal tutup sesi', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String okLabel,
    required Color  okColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title  : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: okColor),
            child: Text(okLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _copyKode() {
    Clipboard.setData(ClipboardData(text: _kode));
    _showSnack('Kode "$_kode" disalin ke clipboard');
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Kode Sesi Online'),
        elevation      : 0,
        actions: [
          // Tombol ke dashboard
          IconButton(
            icon   : const Icon(Icons.dashboard_rounded),
            tooltip: 'Monitor Kehadiran',
            onPressed: () => context.go('/dosen/dashboard',
              extra: {'sesi_id': _sesiId}),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ── Label ─────────────────────────────────────
              Text(
                'Bagikan kode ini ke mahasiswa',
                style: TextStyle(
                  color    : Colors.white.withOpacity(0.7),
                  fontSize : 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'via Zoom / Meet / WhatsApp',
                style: TextStyle(
                  color    : Colors.white.withOpacity(0.5),
                  fontSize : 13,
                ),
              ),
              const SizedBox(height: 32),

              // ── Kode besar ────────────────────────────────
              GestureDetector(
                onTap: _copyKode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
                  decoration: BoxDecoration(
                    color       : _isExpired
                        ? Colors.grey.shade800
                        : const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(24),
                    border      : Border.all(
                      color: _isExpired ? Colors.grey : Colors.blueAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (!_isExpired)
                        BoxShadow(
                          color     : Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _kode,
                        style: TextStyle(
                          color       : _isExpired ? Colors.grey : Colors.white,
                          fontSize    : 52,
                          fontWeight  : FontWeight.w900,
                          letterSpacing: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            color: Colors.white.withOpacity(0.5),
                            size : 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap untuk copy',
                            style: TextStyle(
                              color  : Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Countdown Timer ───────────────────────────
              Container(
                padding   : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color       : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border      : Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                      color: _isExpired ? Colors.grey : _timerColor,
                      size : 28,
                    ),
                    const SizedBox(width: 12),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color     : _isExpired ? Colors.grey : _timerColor,
                        fontSize  : 42,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      child: Text(_isExpired ? 'EXPIRED' : _timerLabel),
                    ),
                  ],
                ),
              ),

              if (_isExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Kode sudah tidak aktif. Perpanjang atau generate kode baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                  ),
                ),

              const Spacer(flex: 2),

              // ── Tombol Perpanjang ─────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label    : '+15 mnt',
                      icon     : Icons.more_time_rounded,
                      color    : Colors.blue.shade700,
                      isLoading: _isExtending,
                      onPressed: () => _extendKode(15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label    : '+30 mnt',
                      icon     : Icons.more_time_rounded,
                      color    : Colors.indigo.shade700,
                      isLoading: _isExtending,
                      onPressed: () => _extendKode(30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Tombol Regen Kode ─────────────────────────
              SizedBox(
                width : double.infinity,
                child : _ActionButton(
                  label    : 'Generate Kode Baru',
                  icon     : Icons.refresh_rounded,
                  color    : Colors.orange.shade700,
                  isLoading: _isRegening,
                  onPressed: _regenKode,
                ),
              ),
              const SizedBox(height: 10),

              // ── Tombol Akhiri Sesi ────────────────────────
              SizedBox(
                width : double.infinity,
                child : _ActionButton(
                  label    : 'Akhiri Sesi',
                  icon     : Icons.stop_circle_rounded,
                  color    : Colors.red.shade700,
                  isLoading: _isClosing,
                  onPressed: _tutupSesi,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable action button ────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     isLoading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon : isLoading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding        : const EdgeInsets.symmetric(vertical: 14),
        shape          : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}