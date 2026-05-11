// lib/screens/dosen/kode_display_screen.dart
// FASE 7.3 UPDATE:
// - Tombol 'Salin & Bagikan' PROMINENT di bagian atas (bukan di bawah)
// - Instruksi share manual: 'Bagikan kode ini ke grup WhatsApp atau chat Zoom'
// - Info kelas dan mode di header (mis: 'Pemrograman Mobile — Kelas A — Online')
// - Animasi pulse pada kode saat mendekati expired (< 5 menit)
// - Indikator warna BORDER berdasarkan sisa waktu:
//     Hijau (> 10 mnt) → Kuning (3–10 mnt) → Merah (< 3 mnt)
// - Countdown timer tetap ada dan prominent

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';

class KodeDisplayScreen extends StatefulWidget {
  final Map<String, dynamic> sesiData;

  const KodeDisplayScreen({super.key, required this.sesiData});

  @override
  State<KodeDisplayScreen> createState() => _KodeDisplayScreenState();
}

class _KodeDisplayScreenState extends State<KodeDisplayScreen>
    with TickerProviderStateMixin {
  late String _sesiId;
  late String _kode;
  late int    _detikTersisa;

  // ── Info kelas & mode (BARU 7.3) ────────────────────────
  late String? _matakuliahNama;
  late String? _kodeKelas;
  late String? _mode;

  Timer? _countdownTimer;
  bool   _isExpired = false;

  bool _isExtending  = false;
  bool _isRegening   = false;
  bool _isClosing    = false;
  bool _isSharing    = false;

  // ── Animasi pulse (BARU 7.3) ────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  // Threshold: di bawah 5 menit (300 detik) mulai pulse
  bool get _shouldPulse => _detikTersisa <= 300 && !_isExpired;

  @override
  void initState() {
    super.initState();
    _sesiId          = widget.sesiData['id']             as String? ?? '';
    _kode            = widget.sesiData['kode_sesi']      as String? ?? '------';
    _detikTersisa    = widget.sesiData['detik_tersisa']  as int?    ?? 1800;

    // [BARU 7.3] Ambil info kelas & mode dari sesiData
    _matakuliahNama  = widget.sesiData['matakuliah_nama'] as String?;
    _kodeKelas       = widget.sesiData['kode_kelas']      as String?;
    _mode            = widget.sesiData['mode']            as String?;

    // Setup animasi pulse
    _pulseController = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    _updatePulse();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_detikTersisa > 0) {
          _detikTersisa--;
          _updatePulse();
        } else {
          _isExpired = true;
          _countdownTimer?.cancel();
          _pulseController.stop();
        }
      });
    });
  }

  void _updatePulse() {
    if (_shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  // ── Timer label ─────────────────────────────────────────
  String get _timerLabel {
    final mnt = _detikTersisa ~/ 60;
    final dtk = _detikTersisa % 60;
    return '${mnt.toString().padLeft(2, '0')}:${dtk.toString().padLeft(2, '0')}';
  }

  // ── Warna timer ─────────────────────────────────────────
  Color get _timerColor {
    if (_detikTersisa > 300) return Colors.greenAccent;
    if (_detikTersisa > 60)  return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ── [BARU 7.3] Warna border kode berdasarkan sisa waktu ─
  // > 10 mnt  → Hijau (600 detik)
  // 3–10 mnt  → Kuning
  // < 3 mnt   → Merah
  Color get _borderColor {
    if (_isExpired)            return Colors.grey;
    if (_detikTersisa > 600)   return Colors.greenAccent.shade400;
    if (_detikTersisa > 180)   return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ── [BARU 7.3] Glow/shadow warna sesuai border ──────────
  Color get _glowColor {
    if (_isExpired)            return Colors.transparent;
    if (_detikTersisa > 600)   return Colors.greenAccent.withOpacity(0.25);
    if (_detikTersisa > 180)   return Colors.orangeAccent.withOpacity(0.25);
    return Colors.redAccent.withOpacity(0.25);
  }

  // ── [BARU 7.3] Label header info kelas + mode ───────────
  String get _headerSubtitle {
    final parts = <String>[];
    if (_matakuliahNama != null && _matakuliahNama!.isNotEmpty) {
      parts.add(_matakuliahNama!);
    }
    if (_kodeKelas != null && _kodeKelas!.isNotEmpty) {
      parts.add('Kelas $_kodeKelas');
    }
    if (_mode != null && _mode!.isNotEmpty) {
      parts.add(_mode!.toLowerCase() == 'online' ? 'Online' : 'Tatap Muka');
    }
    return parts.join(' — ');
  }

  // ── API Actions ─────────────────────────────────────────
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
          _detikTersisa = data['detik_tersisa'] as int?
              ?? _detikTersisa + tambahanMenit * 60;
          _isExpired    = false;
        });
        _startCountdown();
        _updatePulse();
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
        _updatePulse();
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

  // ── [BARU 7.3] Salin & Bagikan via share_plus ───────────
  Future<void> _salinDanBagikan() async {
    setState(() => _isSharing = true);
    try {
      // Bangun pesan yang akan dibagikan
      final pesanBagikan = _buildPesanBagikan();

      // Copy ke clipboard juga
      await Clipboard.setData(ClipboardData(text: _kode));

      // Buka share sheet
      await Share.share(
        pesanBagikan,
        subject: 'Kode Presensi $_kode',
      );
    } catch (e) {
      // Fallback: hanya copy ke clipboard jika share gagal
      await Clipboard.setData(ClipboardData(text: _kode));
      _showSnack('Kode "$_kode" disalin ke clipboard');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _buildPesanBagikan() {
    final buffer = StringBuffer();
    buffer.writeln('📋 *Kode Presensi*');

    if (_matakuliahNama != null && _matakuliahNama!.isNotEmpty) {
      buffer.writeln('📚 $_matakuliahNama');
    }
    if (_kodeKelas != null && _kodeKelas!.isNotEmpty) {
      buffer.writeln('🏫 Kelas $_kodeKelas');
    }

    buffer.writeln();
    buffer.writeln('🔑 Kode: *$_kode*');
    buffer.writeln();
    buffer.writeln('⏱️ Berlaku $_timerLabel lagi');
    buffer.writeln();
    buffer.writeln('Masukkan kode ini di aplikasi Presensi SKS untuk absen.');

    return buffer.toString();
  }

  void _copyKode() {
    Clipboard.setData(ClipboardData(text: _kode));
    _showSnack('Kode "$_kode" disalin ke clipboard');
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title  : Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: okColor),
            child: Text(okLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError
          ? Colors.red.shade700
          : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildAppBar(),
      body  : SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child  : Column(
            children: [
              const Spacer(flex: 1),

              // ── [BARU 7.3] Info kelas + mode ──────────────
              if (_headerSubtitle.isNotEmpty)
                _buildInfoKelasHeader(),

              const SizedBox(height: 16),

              // ── Label instruksi ───────────────────────────
              const Text(
                'Bagikan kode ini ke mahasiswa',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 4),

              // ── [BARU 7.3] Instruksi share manual ─────────
              const Text(
                'via grup WhatsApp atau chat Zoom',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // ── [BARU 7.3] Tombol Salin & Bagikan PROMINENT ─
              _buildShareButton(),

              const SizedBox(height: 20),

              // ── Kode besar dengan animasi pulse + border dinamis ─
              _buildKodeCard(),

              const SizedBox(height: 20),

              // ── Countdown Timer ───────────────────────────
              _buildCountdownTimer(),

              if (_isExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Kode sudah tidak aktif. Perpanjang atau generate kode baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red.shade300, fontSize: 13),
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

              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label    : 'Generate Kode Baru',
                  icon     : Icons.refresh_rounded,
                  color    : Colors.orange.shade700,
                  isLoading: _isRegening,
                  onPressed: _regenKode,
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label    : 'Akhiri Sesi',
                  icon     : Icons.stop_circle_rounded,
                  color    : Colors.red.shade700,
                  isLoading: _isClosing,
                  onPressed: _tutupSesi,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar dengan info kelas di subtitle ────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation      : 0,
      title          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kode Sesi Online',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // [BARU 7.3] Subtitle kelas + mode di AppBar
          if (_headerSubtitle.isNotEmpty)
            Text(
              _headerSubtitle,
              style: const TextStyle(
                fontSize: 11,
                color   : Colors.white60,
                fontWeight: FontWeight.normal,
              ),
              maxLines : 1,
              overflow : TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        IconButton(
          icon   : const Icon(Icons.dashboard_rounded),
          tooltip: 'Monitor Kehadiran',
          onPressed: () => context.go('/dosen/monitor',
              extra: {'sesi_id': _sesiId}),
        ),
      ],
    );
  }

  // ── [BARU 7.3] Banner info kelas + mode ─────────────────
  Widget _buildInfoKelasHeader() {
    final isOnline = _mode?.toLowerCase() == 'online';
    final modeColor = isOnline
        ? AppColors.kModeOnline
        : AppColors.kModeOffline;
    final modeIcon  = isOnline
        ? Icons.laptop_outlined
        : Icons.location_on_outlined;
    final modeLabel = isOnline ? 'Online' : 'Tatap Muka';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Kelas badge
          if (_kodeKelas != null && _kodeKelas!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.kelasColor(_kodeKelas!)
                    .withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.kelasColor(_kodeKelas!)
                      .withOpacity(0.5)),
              ),
              child: Text(
                'Kelas $_kodeKelas',
                style: TextStyle(
                  color     : AppColors.kelasColor(_kodeKelas!),
                  fontSize  : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Nama matakuliah
          Expanded(
            child: Text(
              _matakuliahNama ?? '',
              style: const TextStyle(
                color     : Colors.white,
                fontSize  : 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Mode badge
          if (_mode != null && _mode!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: modeColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(modeIcon, size: 11, color: modeColor),
                  const SizedBox(width: 4),
                  Text(
                    modeLabel,
                    style: TextStyle(
                      color     : modeColor,
                      fontSize  : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── [BARU 7.3] Tombol Salin & Bagikan PROMINENT ─────────
  Widget _buildShareButton() {
    return SizedBox(
      width : double.infinity,
      height: 54,
      child : ElevatedButton.icon(
        onPressed: (_isSharing || _isExpired) ? null : _salinDanBagikan,
        icon : _isSharing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF002147), strokeWidth: 2.5),
              )
            : const Icon(Icons.share_rounded, size: 22),
        label: Text(
          _isSharing ? 'Membagikan...' : 'Salin & Bagikan Kode',
          style: const TextStyle(
            fontSize  : 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kGold,
          foregroundColor: AppColors.kNavyDark,
          elevation      : 0,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: AppColors.kGold.withOpacity(0.4),
        ),
      ),
    );
  }

  // ── [BARU 7.3] Kode card dengan pulse + border dinamis ──
  Widget _buildKodeCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _shouldPulse ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _copyKode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width    : double.infinity,
              padding  : const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: _isExpired
                    ? Colors.grey.shade800
                    : const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(24),
                // [BARU 7.3] Border warna dinamis
                border: Border.all(
                  color: _borderColor,
                  width: 2.5,
                ),
                boxShadow: [
                  if (!_isExpired)
                    BoxShadow(
                      color     : _glowColor,
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: Column(
                children: [
                  // [BARU 7.3] Label status waktu di atas kode
                  _buildWaktuStatusLabel(),
                  const SizedBox(height: 8),

                  // Kode utama
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _kode,
                      maxLines: 1,
                      style: AppTypography.kodeSesi.copyWith(
                        color        : _isExpired
                            ? Colors.grey
                            : Colors.white,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tap untuk copy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size : 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap untuk copy',
                        style: TextStyle(
                          color  : Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── [BARU 7.3] Label status waktu di dalam card kode ────
  Widget _buildWaktuStatusLabel() {
    if (_isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color       : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'KODE SUDAH HANGUS',
          style: TextStyle(
            color     : Colors.grey,
            fontSize  : 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );
    }

    String label;
    Color  labelColor;

    if (_detikTersisa > 600) {
      label      = '🟢 Aktif';
      labelColor = Colors.greenAccent.shade400;
    } else if (_detikTersisa > 180) {
      label      = '🟡 Segera Habis';
      labelColor = Colors.orangeAccent;
    } else {
      label      = '🔴 Hampir Habis!';
      labelColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color       : labelColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: labelColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color     : labelColor,
          fontSize  : 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Countdown Timer ──────────────────────────────────────
  Widget _buildCountdownTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border      : Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isExpired
                ? Icons.timer_off_rounded
                : Icons.timer_rounded,
            color: _isExpired ? Colors.grey : _timerColor,
            size : 28,
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color      : _isExpired ? Colors.grey : _timerColor,
              fontSize   : 42,
              fontWeight : FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: Text(_isExpired ? 'EXPIRED' : _timerLabel),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ACTION BUTTON (tidak berubah, hanya dirapikan)
// ══════════════════════════════════════════════════════════════

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
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : Icon(icon, size: 20),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold)),
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