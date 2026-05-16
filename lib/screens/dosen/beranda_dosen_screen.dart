// lib/screens/dosen/beranda_dosen_screen.dart
// Fase 6.1 UPDATE:
// - HAPUS: Section "Semua Matakuliah" — dipindah ke JadwalDosenScreen
// - TAMBAH: Card sesi aktif yang sedang berjalan di bagian atas
// - UPDATE: Badge kelas (A/B/C) dan SlotLabel di setiap kartu jadwal
// - UPDATE: Bottom sheet Buka Sesi — dropdown pilih kelas jika multi-kelas,
//           kirim kelas_id ke POST /sesi/buka
//
// BUGFIX: _ActionBtn tidak lagi pakai minimumSize: Size(double.infinity, ...)
//   karena menyebabkan BoxConstraints forces infinite width crash ketika
//   tombol dipakai di dalam Row tanpa Expanded wrapper.
//   Fix: ganti minimumSize ke Size(0, 44) dan biarkan parent (Expanded) yang
//   mengatur width. Semua kasus _buildActions() yang sebelumnya menempatkan
//   _ActionBtn tanpa Expanded sekarang sudah dibungkus Expanded.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/slot_label.dart';

// ─── Model ────────────────────────────────────────────────────

class JadwalHariIniItem {
  final String  matakuliahId;
  final String  kode;
  final String  nama;
  final int     sks;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final bool    izinTamu;
  final int     jumlahMahasiswa;
  final String  statusSesi;
  final String? sesiId;
  final int?    pertemuanKe;
  final String? kodeSesi;
  final int?    detikTersisa;
  final bool    adaJadwalPengganti;
  final String? jamMulaiPengganti;
  final String? jamSelesaiPengganti;
  final String? ruanganPengganti;
  // ── [BARU Fase 6.1] ──────────────────────────────────────
  final String? kodeKelas;   // 'A', 'B', 'C'
  final String? kelasId;
  final int?    slotMulai;
  final int?    slotSelesai;
  final List<Map<String, dynamic>> kelasList; // Multi-kelas untuk dropdown

  const JadwalHariIniItem({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    required this.izinTamu,
    required this.jumlahMahasiswa,
    required this.statusSesi,
    this.sesiId,
    this.pertemuanKe,
    this.kodeSesi,
    this.detikTersisa,
    this.adaJadwalPengganti  = false,
    this.jamMulaiPengganti,
    this.jamSelesaiPengganti,
    this.ruanganPengganti,
    this.kodeKelas,
    this.kelasId,
    this.slotMulai,
    this.slotSelesai,
    this.kelasList           = const [],
  });

  factory JadwalHariIniItem.fromJson(Map<String, dynamic> j) =>
      JadwalHariIniItem(
        matakuliahId       : j['matakuliah_id']         as String,
        kode               : j['kode']                  as String,
        nama               : j['nama']                  as String,
        sks                : j['sks']                   as int,
        hari               : j['hari']                  as String?,
        jamMulai           : j['jam_mulai']             as String?,
        jamSelesai         : j['jam_selesai']            as String?,
        ruangan            : j['ruangan']               as String?,
        izinTamu           : j['izin_tamu']             as bool?   ?? false,
        jumlahMahasiswa    : j['jumlah_mahasiswa']      as int?    ?? 0,
        statusSesi         : j['status_sesi']           as String? ?? 'belum_mulai',
        sesiId             : j['sesi_id']               as String?,
        pertemuanKe        : j['pertemuan_ke']          as int?,
        kodeSesi           : j['kode_sesi']             as String?,
        detikTersisa       : j['detik_tersisa']         as int?,
        adaJadwalPengganti : j['ada_jadwal_pengganti']  as bool?   ?? false,
        jamMulaiPengganti  : j['jam_mulai_pengganti']   as String?,
        jamSelesaiPengganti: j['jam_selesai_pengganti'] as String?,
        ruanganPengganti   : j['ruangan_pengganti']     as String?,
        kodeKelas          : j['kode_kelas']            as String?,
        kelasId            : j['kelas_id']              as String?,
        slotMulai          : j['slot_mulai']            as int?,
        slotSelesai        : j['slot_selesai']          as int?,
        kelasList          : (j['kelas_list'] as List<dynamic>?)
                                ?.cast<Map<String, dynamic>>() ?? [],
      );

  String get labelJam {
    final mulai   = (adaJadwalPengganti && jamMulaiPengganti != null)
        ? jamMulaiPengganti! : (jamMulai   ?? '-');
    final selesai = (adaJadwalPengganti && jamSelesaiPengganti != null)
        ? jamSelesaiPengganti! : (jamSelesai ?? '-');
    return '$mulai – $selesai';
  }

  String get labelRuangan =>
      (adaJadwalPengganti && ruanganPengganti != null)
          ? ruanganPengganti! : (ruangan ?? '-');
}

// ─── BerandaDosenScreen ───────────────────────────────────────

class BerandaDosenScreen extends StatefulWidget {
  final void Function(String? sesiId)? onGoToMonitor;
  final void Function(bool)? onSesiAktifChanged;

  const BerandaDosenScreen({
    super.key,
    this.onGoToMonitor,
    this.onSesiAktifChanged,
  });

  @override
  State<BerandaDosenScreen> createState() => _BerandaDosenScreenState();
}

class _BerandaDosenScreenState extends State<BerandaDosenScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  String  _namaDosen  = '';
  String  _nidn       = '';
  String  _hariIni    = '';
  bool    _isLoading  = true;
  String? _error;
  bool    _isFetching = false;

  List<JadwalHariIniItem> _jadwalHariIni = [];

  // Sesi-sesi yang sedang aktif (dari _jadwalHariIni)
  List<JadwalHariIniItem> get _sesiAktifList =>
      _jadwalHariIni.where((j) => j.statusSesi == 'aktif').toList();

  Timer?           _countdownTimer;
  final Map<String, int> _countdownMap = {};

  @override
  void initState() {
    super.initState();
    _fetchBeranda();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBeranda() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient().get('/dosen/beranda');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;

      final jadwal = (data['jadwal_hari_ini'] as List<dynamic>? ?? [])
          .map((e) => JadwalHariIniItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final adaAktif = jadwal.any((j) => j.statusSesi == 'aktif');
      widget.onSesiAktifChanged?.call(adaAktif);

      final newMap = <String, int>{};
      for (final j in jadwal) {
        if (j.sesiId != null && j.detikTersisa != null &&
            j.statusSesi == 'aktif') {
          newMap[j.sesiId!] = j.detikTersisa!;
        }
      }

      if (mounted) {
        setState(() {
          _namaDosen     = data['nama_dosen'] as String? ?? '';
          _nidn          = data['nidn']       as String? ?? '';
          _hariIni       = data['hari_ini']   as String? ?? '';
          _jadwalHariIni = jadwal;
          _isLoading     = false;
          _countdownMap
            ..clear()
            ..addAll(newMap);
        });
        _startCountdown();
      }

    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    } finally {
      _isFetching = false;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_countdownMap.isEmpty) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        for (final key in _countdownMap.keys.toList()) {
          if (_countdownMap[key]! > 0) _countdownMap[key] = _countdownMap[key]! - 1;
        }
      });
    });
  }

  String _formatCountdown(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showBukaSesiSheet(JadwalHariIniItem jadwal) {
    showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => _BukaSesiBottomSheet(
        jadwal    : jadwal,
        onBerhasil: (sesiData) {
          Navigator.pop(ctx);
          _fetchBeranda();
          final mode   = sesiData['mode']  as String? ?? '';
          final sesiId = sesiData['id']    as String?;
          if (mode == 'online') {
            context.go('/dosen/kode', extra: sesiData);
          } else {
            widget.onGoToMonitor?.call(sesiId);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: RefreshIndicator(
        onRefresh: _fetchBeranda,
        color    : AppColors.kNavy,
        child    : _isLoading
            ? const _LoadingView()
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _fetchBeranda)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final namaDepan = _namaDosen.split(' ').first;

    return CustomScrollView(
      slivers: [
        // ── AppBar ─────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 150,
          pinned        : true,
          backgroundColor: AppColors.kNavy,
          automaticallyImplyLeading: false,
          elevation     : 0,
          flexibleSpace : FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.kNavyGradient,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 60, 16),
                  child  : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment : MainAxisAlignment.center,
                          children: [
                            Text(_getSapaan(),
                              style: AppTypography.heroSubtitle),
                            const SizedBox(height: 4),
                            Text(namaDepan,
                              style  : AppTypography.hero.copyWith(fontSize: 22),
                              overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(_nidn,
                              style: AppTypography.heroSubtitle
                                  .copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius         : 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child          : Text(
                          namaDepan.isNotEmpty
                              ? namaDepan[0].toUpperCase() : 'D',
                          style: AppTypography.hero.copyWith(fontSize: 22)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          title: Text('Beranda',
            style: AppTypography.hero.copyWith(fontSize: 18)),
          titleSpacing: 20,
          actions: [
            IconButton(
              icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchBeranda,
              tooltip  : 'Refresh',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2,
                color: AppColors.kGold.withOpacity(0.5)),
          ),
        ),

        // Sub-header: tanggal
        SliverToBoxAdapter(
          child: Container(
            color  : AppColors.kNavy,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child  : Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                  color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(DateTime.now()),
                  style: AppTypography.heroSubtitle.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver : SliverList(
            delegate: SliverChildListDelegate([

              // ── [BARU Fase 6.1] Card sesi aktif di bagian atas ──
              if (_sesiAktifList.isNotEmpty) ...[
                _SectionHeader(
                  title   : '🔴 Sesi Berlangsung',
                  subtitle: '${_sesiAktifList.length} sesi aktif',
                ),
                const SizedBox(height: 10),
                ..._sesiAktifList.map((j) => _SesiAktifCard(
                  jadwal         : j,
                  countdownDetik : _countdownMap[j.sesiId ?? ''],
                  formatCountdown: _formatCountdown,
                  onMonitor      : () => widget.onGoToMonitor?.call(j.sesiId),
                  onTampilKode   : () {
                    if (j.sesiId == null) return;
                    context.go('/dosen/kode', extra: {
                      'id'           : j.sesiId,
                      'sesi_id'      : j.sesiId,
                      'kode_sesi'    : j.kodeSesi ?? '',
                      'detik_tersisa': _countdownMap[j.sesiId!]
                                       ?? j.detikTersisa ?? 0,
                      'mode'         : 'online',
                    });
                  },
                )),
                const SizedBox(height: 20),
              ],

              // ── Jadwal Hari Ini ────────────────────────────────
              _SectionHeader(
                title   : '📅 Jadwal $_hariIni',
                subtitle: '${_jadwalHariIni.length} matakuliah',
              ),
              const SizedBox(height: 10),

              if (_jadwalHariIni.isEmpty)
                _EmptyCard(
                  icon : Icons.event_available_outlined,
                  pesan: 'Tidak ada jadwal $_hariIni',
                  sub  : 'Nikmati hari libur mengajar 🎉',
                )
              else
                ..._jadwalHariIni.map((j) => _JadwalCard(
                  jadwal         : j,
                  countdownDetik : _countdownMap[j.sesiId ?? ''],
                  formatCountdown: _formatCountdown,
                  onBukaSesi     : () => _showBukaSesiSheet(j),
                  onMonitor      : () =>
                      widget.onGoToMonitor?.call(j.sesiId),
                  onRekap        : () {
                    if (j.sesiId != null) {
                      context.go('/dosen/rekap/${j.sesiId}');
                    }
                  },
                  onTampilKode: () {
                    if (j.sesiId == null) return;
                    context.go('/dosen/kode', extra: {
                      'id'           : j.sesiId,
                      'sesi_id'      : j.sesiId,
                      'kode_sesi'    : j.kodeSesi ?? '',
                      'detik_tersisa': _countdownMap[j.sesiId!]
                                       ?? j.detikTersisa ?? 0,
                      'mode'         : 'online',
                    });
                  },
                  onDetailMatakuliah: () =>
                      context.go('/dosen/matakuliah/${j.matakuliahId}'),
                )),

              // ── [Fase 6.1] Info: Semua MK telah dipindah ──────
              const SizedBox(height: 16),
              _InfoPindahCard(),
            ]),
          ),
        ),
      ],
    );
  }

  String _getSapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat Pagi';
    if (jam < 15) return 'Selamat Siang';
    if (jam < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }
}

// ══════════════════════════════════════════════════════════════
// [BARU Fase 6.1] WIDGET: Card Sesi Aktif (ringkas di atas)
// ══════════════════════════════════════════════════════════════

class _SesiAktifCard extends StatelessWidget {
  final JadwalHariIniItem    jadwal;
  final int?                 countdownDetik;
  final String Function(int) formatCountdown;
  final VoidCallback         onMonitor;
  final VoidCallback         onTampilKode;

  const _SesiAktifCard({
    required this.jadwal,
    required this.countdownDetik,
    required this.formatCountdown,
    required this.onMonitor,
    required this.onTampilKode,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline  = jadwal.kodeSesi != null;
    final sisiWaktu = countdownDetik;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.kGreen.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color    : AppColors.kGreen.withOpacity(0.10),
            blurRadius: 10,
            offset   : const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Pulse dot
            _PulseDot(color: AppColors.kGreen),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama MK + badge kelas
                  Row(
                    children: [
                      Expanded(
                        child: Text(jadwal.nama,
                          style   : AppTypography.bodyBold.copyWith(
                            color: AppColors.kNavy, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      ),
                      if (jadwal.kodeKelas != null) ...[
                        const SizedBox(width: 6),
                        KelasBadge(kodeKelas: jadwal.kodeKelas!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Pertemuan + mode + jam
                  Row(
                    children: [
                      if (jadwal.pertemuanKe != null)
                        Text('Pertemuan ${jadwal.pertemuanKe}  · ',
                          style: AppTypography.caption),
                      ModeBadge(
                        mode    : isOnline ? 'online' : 'offline',
                        fontSize: 10,
                      ),
                      const SizedBox(width: 6),
                      if (jadwal.slotMulai != null)
                        SlotLabelCompact(
                          slotMulai  : jadwal.slotMulai,
                          slotSelesai: jadwal.slotSelesai,
                          fontSize   : 11,
                        )
                      else
                        Text(jadwal.labelJam,
                          style: AppTypography.caption),
                    ],
                  ),

                  // Kode sesi + countdown (online)
                  if (isOnline && jadwal.kodeSesi != null &&
                      sisiWaktu != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded,
                          size: 13, color: AppColors.kNavy),
                        const SizedBox(width: 4),
                        Text(jadwal.kodeSesi!,
                          style: AppTypography.kodeSmall.copyWith(fontSize: 15)),
                        const Spacer(),
                        Icon(Icons.timer_outlined,
                          size: 12,
                          color: sisiWaktu < 300
                              ? AppColors.kDanger : AppColors.kGreen),
                        const SizedBox(width: 3),
                        Text(formatCountdown(sisiWaktu),
                          style: AppTypography.label.copyWith(
                            color: sisiWaktu < 300
                                ? AppColors.kDanger : AppColors.kGreen,
                            fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Tombol aksi
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtnSmall(
                  label    : 'Monitor',
                  icon     : Icons.bar_chart_rounded,
                  color    : AppColors.kNavy,
                  onPressed: onMonitor,
                ),
                if (isOnline) ...[
                  const SizedBox(height: 6),
                  _ActionBtnSmall(
                    label    : 'Kode',
                    icon     : Icons.vpn_key_rounded,
                    color    : AppColors.kNavyLight,
                    onPressed: onTampilKode,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtnSmall extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onPressed;

  const _ActionBtnSmall({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
              style: AppTypography.badge.copyWith(
                color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// [Fase 6.1] WIDGET: Info card "Semua MK telah dipindah"
// ══════════════════════════════════════════════════════════════

class _InfoPindahCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : AppColors.kNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: AppColors.kNavy.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded,
            color: AppColors.kNavy.withOpacity(0.6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Semua Matakuliah',
                  style: AppTypography.label.copyWith(
                    color     : AppColors.kNavy,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Lihat jadwal mingguan & semua MK di tab Jadwal',
                  style: AppTypography.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
            color: AppColors.kNavy.withOpacity(0.4), size: 18),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Jadwal Card — UPDATE dengan badge kelas & slot label
// ══════════════════════════════════════════════════════════════

class _JadwalCard extends StatelessWidget {
  final JadwalHariIniItem    jadwal;
  final int?                 countdownDetik;
  final String Function(int) formatCountdown;
  final VoidCallback         onBukaSesi;
  final VoidCallback         onMonitor;
  final VoidCallback         onRekap;
  final VoidCallback         onTampilKode;
  final VoidCallback         onDetailMatakuliah;

  const _JadwalCard({
    required this.jadwal,
    required this.countdownDetik,
    required this.formatCountdown,
    required this.onBukaSesi,
    required this.onMonitor,
    required this.onRekap,
    required this.onTampilKode,
    required this.onDetailMatakuliah,
  });

  Color get _statusColor {
    switch (jadwal.statusSesi) {
      case 'aktif'  : return AppColors.kGreen;
      case 'selesai': return AppColors.kTextSecondary;
      default       : return AppColors.kNavy;
    }
  }

  String get _statusLabel {
    switch (jadwal.statusSesi) {
      case 'aktif'  : return 'AKTIF';
      case 'selesai': return 'SELESAI';
      default       : return 'BELUM MULAI';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAktif   = jadwal.statusSesi == 'aktif';
    final isSelesai = jadwal.statusSesi == 'selesai';

    return Container(
      margin    : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : isAktif
            ? Border.all(color: AppColors.kGreen.withOpacity(0.4), width: 1.5)
            : isSelesai
                ? Border.all(color: Colors.grey.shade200)
                : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header — tap ke detail matakuliah
          InkWell(
            onTap       : onDetailMatakuliah,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bar status warna
                  Container(
                    width: 4, height: 64,
                    decoration: BoxDecoration(
                      color       : _statusColor,
                      borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: kode + kelas badge + sks + status badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.kNavy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6)),
                              child: Text(jadwal.kode,
                                style: AppTypography.badge.copyWith(
                                  color   : AppColors.kNavy,
                                  fontSize: 11)),
                            ),
                            const SizedBox(width: 6),

                            // [BARU Fase 6.1] Badge kelas
                            if (jadwal.kodeKelas != null) ...[
                              KelasBadge(kodeKelas: jadwal.kodeKelas!),
                              const SizedBox(width: 6),
                            ],

                            Text('${jadwal.sks} SKS',
                              style: AppTypography.caption),
                            const Spacer(),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAktif) ...[
                                    _PulseDot(color: _statusColor),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(_statusLabel,
                                    style: AppTypography.badge.copyWith(
                                      color: _statusColor, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Nama MK
                        Row(
                          children: [
                            Expanded(
                              child: Text(jadwal.nama,
                                style  : AppTypography.bodyBold.copyWith(
                                  color: AppColors.kNavy, fontSize: 15),
                                overflow: TextOverflow.ellipsis),
                            ),
                            Icon(Icons.info_outline_rounded,
                              size : 16,
                              color: Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Jam: slot atau jam biasa
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            jadwal.slotMulai != null
                                ? SlotLabel(
                                    slotMulai      : jadwal.slotMulai,
                                    slotSelesai    : jadwal.slotSelesai,
                                    showIcon       : false,
                                    showSlotNumber : true,
                                    fontSize       : 12,
                                  )
                                : Text(jadwal.labelJam,
                                    style: AppTypography.body2
                                        .copyWith(fontSize: 12)),
                            const SizedBox(width: 10),
                            Icon(Icons.room_outlined,
                              size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(jadwal.labelRuangan,
                                style: AppTypography.body2
                                    .copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sub-info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (jadwal.pertemuanKe != null)
                  _InfoChip(
                    label: 'Pertemuan ${jadwal.pertemuanKe}',
                    color: Colors.blue.shade700,
                    bg   : Colors.blue.shade50),
                if (jadwal.pertemuanKe != null)
                  const SizedBox(width: 6),
                if (jadwal.adaJadwalPengganti)
                  _InfoChip(
                    label: '⟳ Jadwal Pengganti',
                    color: AppColors.kWarning,
                    bg   : AppColors.kWarning.withOpacity(0.1)),
                const Spacer(),
                Icon(Icons.people_outline_rounded,
                  size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('${jadwal.jumlahMahasiswa} mhs',
                  style: AppTypography.caption),
                if (jadwal.izinTamu) ...[
                  const SizedBox(width: 6),
                  _InfoChip(
                    label: 'Tamu OK',
                    color: AppColors.kGreen,
                    bg   : AppColors.kGreen.withOpacity(0.1)),
                ],
              ],
            ),
          ),

          // Countdown kode (online + aktif)
          if (isAktif && jadwal.kodeSesi != null &&
              countdownDetik != null)
            Container(
              margin   : const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding  : const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.kNavy.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.kNavy.withOpacity(0.1))),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded,
                    size: 16, color: AppColors.kNavy),
                  const SizedBox(width: 8),
                  Text('Kode: ',
                    style: AppTypography.body2.copyWith(fontSize: 13)),
                  Text(jadwal.kodeSesi!,
                    style: AppTypography.kodeSmall),
                  const Spacer(),
                  Icon(Icons.timer_outlined,
                    size : 14,
                    color: countdownDetik! < 300
                        ? AppColors.kDanger : AppColors.kGreen),
                  const SizedBox(width: 4),
                  Text(
                    formatCountdown(countdownDetik!),
                    style: AppTypography.label.copyWith(
                      color: countdownDetik! < 300
                          ? AppColors.kDanger : AppColors.kGreen,
                      fontWeight: FontWeight.bold,
                      fontSize  : 13)),
                ],
              ),
            ),

          const Divider(height: 1),

          // Tombol aksi
          Padding(
            padding: const EdgeInsets.all(12),
            child  : _buildActions(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (jadwal.statusSesi == 'aktif') {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _ActionBtn(
              label    : 'Monitor Live',
              icon     : Icons.bar_chart_rounded,
              color    : AppColors.kNavy,
              filled   : true,
              onPressed: onMonitor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: jadwal.kodeSesi != null
                ? _ActionBtn(
                    label    : 'Kode',
                    icon     : Icons.vpn_key_rounded,
                    color    : const Color(0xFF7C3AED),
                    filled   : false,
                    onPressed: onTampilKode)
                : _ActionBtn(
                    label    : 'Rekap',
                    icon     : Icons.summarize_rounded,
                    color    : AppColors.kNavy,
                    filled   : false,
                    onPressed: onRekap),
          ),
        ],
      );
    }

    if (jadwal.statusSesi == 'selesai') {
      // BUGFIX: Kedua tombol dibungkus Expanded agar tidak infinite width
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _ActionBtn(
              label    : 'Lihat Rekap',
              icon     : Icons.summarize_rounded,
              color    : Colors.blue.shade700,
              filled   : true,
              onPressed: onRekap),
          ),
          const SizedBox(width: 8),
          Expanded(
            // BUGFIX: Sebelumnya tombol Detail tidak dibungkus Expanded,
            // menyebabkan BoxConstraints infinite width crash.
            child: _ActionBtn(
              label    : 'Detail',
              icon     : Icons.school_outlined,
              color    : AppColors.kNavy,
              filled   : false,
              onPressed: onDetailMatakuliah),
          ),
        ],
      );
    }

    // belum_mulai
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _ActionBtn(
            label    : 'Buka Sesi',
            icon     : Icons.play_circle_rounded,
            color    : AppColors.kNavy,
            filled   : true,
            onPressed: onBukaSesi),
        ),
        const SizedBox(width: 8),
        Expanded(
          // BUGFIX: Expanded ditambahkan agar width terbatas
          child: _ActionBtn(
            label    : 'Detail',
            icon     : Icons.school_outlined,
            color    : AppColors.kNavy,
            filled   : false,
            onPressed: onDetailMatakuliah),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Bottom Sheet Buka Sesi — dengan dropdown kelas
// ══════════════════════════════════════════════════════════════

class _BukaSesiBottomSheet extends StatefulWidget {
  final JadwalHariIniItem                   jadwal;
  final void Function(Map<String, dynamic>) onBerhasil;

  const _BukaSesiBottomSheet({
    required this.jadwal,
    required this.onBerhasil,
  });

  @override
  State<_BukaSesiBottomSheet> createState() =>
      _BukaSesiBottomSheetState();
}

class _BukaSesiBottomSheetState extends State<_BukaSesiBottomSheet> {
  String _mode            = 'offline';
  int?   _batasTerlambat  = 15;
  int    _durasiKode      = 30;
  bool   _mulaiDariJadwal = true;
  bool   _isLoading       = false;

  Map<String, dynamic>? _selectedKelas;

  final List<int?> _opsiTerlambat = [null, 0, 10, 15, 30];
  final List<int>  _opsiDurasi    = [15, 30, 60, 90];

  bool get _hasMultiKelas => widget.jadwal.kelasList.length > 1;

  String _labelTerlambat(int? val) {
    if (val == null) return 'Tidak ada batas';
    if (val == 0)   return 'Langsung';
    return '$val mnt';
  }

  @override
  void initState() {
    super.initState();
    if (widget.jadwal.kelasList.length == 1) {
      _selectedKelas = widget.jadwal.kelasList.first;
    }
  }

  Future<void> _bukaSesi() async {
    final pertemuanKe = widget.jadwal.pertemuanKe;
    if (pertemuanKe == null) {
      _showSnack('Tidak dapat menentukan nomor pertemuan');
      return;
    }

    if (_hasMultiKelas && _selectedKelas == null) {
      _showSnack('Pilih kelas terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'matakuliah_id'        : widget.jadwal.matakuliahId,
        'mode'                 : _mode,
        'pertemuan_ke'         : pertemuanKe,
        'batas_terlambat_menit': _batasTerlambat,
        'mulai_dari_jam_jadwal': _mulaiDariJadwal,
      };

      final kelasId = _selectedKelas?['id'] as String?
                   ?? widget.jadwal.kelasId;
      if (kelasId != null && kelasId.isNotEmpty) {
        body['kelas_id'] = kelasId;
      }

      if (_mode == 'online') body['durasi_menit'] = _durasiKode;

      final response = await ApiClient().post('/sesi/buka', body: body);
      final data     = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      widget.onBerhasil(data);

    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('Gagal buka sesi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: AppColors.kDanger,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left  : 24, right: 24, top: 8,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize      : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width : 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color       : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Text('Buka Sesi Presensi',
              style: AppTypography.heading3),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.jadwal.nama}  ·  ${widget.jadwal.kode}',
                    style  : AppTypography.body2,
                    overflow: TextOverflow.ellipsis),
                ),
                if (widget.jadwal.kodeKelas != null && !_hasMultiKelas) ...[
                  const SizedBox(width: 6),
                  KelasBadge(kodeKelas: widget.jadwal.kodeKelas!),
                ],
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Dropdown kelas jika multi-kelas
            if (_hasMultiKelas) ...[
              Text('Kelas',
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.kNavy, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color       : AppColors.kBgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.kSoftGray, width: 1)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value      : _selectedKelas,
                    isExpanded : true,
                    hint       : Text('Pilih kelas...',
                      style: AppTypography.body2),
                    items: widget.jadwal.kelasList.map((kelas) {
                      final kodeKls = kelas['kode_kelas'] as String? ?? '';
                      final dosen   = kelas['dosen_nama'] as String? ?? '-';
                      final ruangan = kelas['ruangan_nama'] as String? ?? '';
                      return DropdownMenuItem(
                        value: kelas,
                        child: Row(
                          children: [
                            KelasBadge(kodeKelas: kodeKls, showPrefix: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(dosen,
                                    style  : AppTypography.body2
                                        .copyWith(fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                  if (ruangan.isNotEmpty)
                                    Text(ruangan,
                                      style  : AppTypography.caption,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedKelas = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _SheetInfoRow(
              label: 'Pertemuan ke',
              value: widget.jadwal.pertemuanKe != null
                  ? '${widget.jadwal.pertemuanKe}' : 'Tidak tersedia',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Waktu Mulai',
                        style: AppTypography.bodyBold.copyWith(
                          color: AppColors.kNavy, fontSize: 13)),
                      Text(
                        _mulaiDariJadwal
                            ? 'Dari jam jadwal '
                              '(${widget.jadwal.jamMulai ?? "-"})'
                            : 'Dari sekarang',
                        style: AppTypography.body2.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value    : _mulaiDariJadwal,
                  onChanged: (v) => setState(() => _mulaiDariJadwal = v),
                  activeColor: AppColors.kNavy,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Mode Kelas',
              style: AppTypography.bodyBold.copyWith(
                color: AppColors.kNavy, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetModeChip(
                    label   : '📍 Tatap Muka',
                    selected: _mode == 'offline',
                    color   : AppColors.kNavy,
                    onTap   : () => setState(() => _mode = 'offline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetModeChip(
                    label   : '💻 Online',
                    selected: _mode == 'online',
                    color   : const Color(0xFF7C3AED),
                    onTap   : () => setState(() => _mode = 'online'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Toleransi Terlambat',
              style: AppTypography.bodyBold.copyWith(
                color: AppColors.kNavy, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: _opsiTerlambat.map((v) => ChoiceChip(
                label    : Text(_labelTerlambat(v),
                  style: AppTypography.caption),
                selected : _batasTerlambat == v,
                onSelected: (_) =>
                    setState(() => _batasTerlambat = v),
                selectedColor: AppColors.kNavy,
                labelStyle: TextStyle(
                  color: _batasTerlambat == v
                      ? Colors.white : AppColors.kTextPrimary),
              )).toList(),
            ),
            const SizedBox(height: 16),

            if (_mode == 'online') ...[
              Text('Durasi Kode Aktif',
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.kNavy, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: _opsiDurasi.map((v) => ChoiceChip(
                  label    : Text('$v mnt',
                    style: AppTypography.caption),
                  selected : _durasiKode == v,
                  onSelected: (_) =>
                      setState(() => _durasiKode = v),
                  selectedColor: const Color(0xFF7C3AED),
                  labelStyle: TextStyle(
                    color: _durasiKode == v
                        ? Colors.white : AppColors.kTextPrimary),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              height: 52,
              child : ElevatedButton.icon(
                onPressed: (_isLoading ||
                    widget.jadwal.pertemuanKe == null ||
                    (_hasMultiKelas && _selectedKelas == null))
                    ? null : _bukaSesi,
                icon : _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_circle_rounded, size: 22),
                label: Text(
                  _isLoading
                      ? 'Membuka...'
                      : _mode == 'online'
                          ? 'Buka Sesi & Generate Kode'
                          : 'Buka Sesi Tatap Muka',
                  style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _mode == 'online'
                          ? const Color(0xFF7C3AED) : AppColors.kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET HELPERS (shared)
// ══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: AppTypography.sectionTitle),
      const Spacer(),
      Text(subtitle, style: AppTypography.caption),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;
  const _InfoChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
      style: AppTypography.badge.copyWith(color: color, fontSize: 11)),
  );
}

// ══════════════════════════════════════════════════════════════
// BUGFIX: _ActionBtn — minimumSize TIDAK boleh double.infinity
// karena menyebabkan BoxConstraints infinite width crash ketika
// widget dipakai di Row tanpa Expanded.
// Fix: gunakan Size(0, 44) — width diatur oleh parent (Expanded).
// ══════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     filled;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  @override
  Widget build(BuildContext context) {
    // BUGFIX: minimumSize: Size(0, 44) — jangan pakai double.infinity
    // Width dikontrol oleh Expanded di parent Row.
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon : Icon(icon, size: 16),
        label: Text(label, style: AppTypography.buttonSmall),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize    : const Size(0, 44),  // ← FIX: bukan double.infinity
          padding        : const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape          : _shape,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon : Icon(icon, size: 16),
      label: Text(label, style: AppTypography.buttonSmall),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side           : BorderSide(color: color.withOpacity(0.4)),
        minimumSize    : const Size(0, 44),  // ← FIX: bukan double.infinity
        padding        : const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape          : _shape,
      ),
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: AppTypography.body2),
      Text(value,
        style: AppTypography.bodyBold.copyWith(
          color: AppColors.kNavy, fontSize: 13)),
    ],
  );
}

class _SheetModeChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _SheetModeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration : const Duration(milliseconds: 200),
      padding  : const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? color : Colors.grey.shade300)),
      child: Text(label,
        textAlign: TextAlign.center,
        style: AppTypography.button.copyWith(
          color: selected ? Colors.white : AppColors.kTextPrimary,
          fontSize: 13)),
    ),
  );
}

// ── Pulse Dot ─────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: widget.color, shape: BoxShape.circle)),
  );
}

// ── Empty Card ────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String   pesan;
  final String   sub;

  const _EmptyCard({
    required this.icon,
    required this.pesan,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding    : const EdgeInsets.all(28),
    decoration : BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, size: 52, color: Colors.grey.shade200),
        const SizedBox(height: 12),
        Text(pesan,
          style: AppTypography.bodyBold.copyWith(
            color: AppColors.kNavy, fontSize: 14)),
        const SizedBox(height: 6),
        Text(sub,
          textAlign: TextAlign.center,
          style: AppTypography.caption),
      ],
    ),
  );
}

// ── Loading & Error ───────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.kNavy),
        SizedBox(height: 16),
        Text('Memuat beranda...',
          style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
            size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Gagal memuat beranda',
            style: AppTypography.heading3.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: AppTypography.body2),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon : const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kNavy,
              foregroundColor: Colors.white),
          ),
        ],
      ),
    ),
  );
}