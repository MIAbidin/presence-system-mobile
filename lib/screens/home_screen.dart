// lib/screens/home_screen.dart
// v2.1.0 FIX — Perbaikan tampilan:
// - CircularProgressIndicator tidak terpotong (pakai SizedBox yang cukup besar)
// - Badge kelas (A/B/C) tampil di samping kode MK
// - Nama dosen tampil di bawah nama MK
// - Layout lebih rapi dan proporsional
// - Overflow di bagian kehadiran diperbaiki

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/models/jadwal.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';

// ─── Models ──────────────────────────────────────────────────

class StatKehadiran {
  final int    totalPertemuan;
  final int    hadir;
  final int    terlambat;
  final int    absen;
  final int    hadirEfektif;
  final double persentase;

  const StatKehadiran({
    required this.totalPertemuan,
    required this.hadir,
    required this.terlambat,
    required this.absen,
    required this.hadirEfektif,
    required this.persentase,
  });

  factory StatKehadiran.fromJson(Map<String, dynamic> json) => StatKehadiran(
    totalPertemuan: json['total_pertemuan'] as int? ?? 0,
    hadir         : json['hadir']           as int? ?? 0,
    terlambat     : json['terlambat']       as int? ?? 0,
    absen         : json['absen']           as int? ?? 0,
    hadirEfektif  : json['hadir_efektif']   as int? ?? 0,
    persentase    : (json['persentase'] as num?)?.toDouble() ?? 0.0,
  );
}

class SesiAktifInfo {
  final String  sesiId;
  final String  matakuliahNama;
  final String  matakuliahKode;
  final String  mode;
  final int?    detikTersisa;
  final int     pertemuanKe;
  final String? kodeKelas;
  final String? dosenNama;
  final String? ruangan;

  const SesiAktifInfo({
    required this.sesiId,
    required this.matakuliahNama,
    required this.matakuliahKode,
    required this.mode,
    this.detikTersisa,
    required this.pertemuanKe,
    this.kodeKelas,
    this.dosenNama,
    this.ruangan,
  });

  factory SesiAktifInfo.fromJson(Map<String, dynamic> json) => SesiAktifInfo(
    sesiId        : json['sesi_id']         as String? ?? '',
    matakuliahNama: json['matakuliah_nama'] as String? ?? '',
    matakuliahKode: json['matakuliah_kode'] as String? ?? '',
    mode          : json['mode']            as String? ?? '',
    detikTersisa  : json['detik_tersisa']   as int?,
    pertemuanKe   : json['pertemuan_ke']    as int? ?? 0,
    kodeKelas     : json['kode_kelas']      as String?,
    dosenNama     : json['dosen_nama']      as String?,
    ruangan       : json['ruangan']         as String?,
  );

  bool get isOnline => mode == 'online';
}

class HomeSummaryModel {
  final String              namaMahasiswa;
  final String              nim;
  final bool                isFaceRegistered;
  final StatKehadiran       statSemester;
  final int                 presensiHariIni;
  final List<JadwalModel>   jadwalHariIni;
  final List<SesiAktifInfo> sesiAktif;
  final String?             programStudiId;

  const HomeSummaryModel({
    required this.namaMahasiswa,
    required this.nim,
    required this.isFaceRegistered,
    required this.statSemester,
    required this.presensiHariIni,
    required this.jadwalHariIni,
    required this.sesiAktif,
    this.programStudiId,
  });

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeSummaryModel(
      namaMahasiswa   : json['nama_mahasiswa']     as String? ?? '',
      nim             : json['nim']                as String? ?? '',
      isFaceRegistered: json['is_face_registered'] as bool?   ?? false,
      statSemester    : StatKehadiran.fromJson(
          (json['stat_semester'] as Map<String, dynamic>?) ?? {}),
      presensiHariIni : json['presensi_hari_ini']  as int? ?? 0,
      jadwalHariIni   : ((json['jadwal_hari_ini'] as List<dynamic>?) ?? [])
          .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sesiAktif       : ((json['sesi_aktif'] as List<dynamic>?) ?? [])
          .map((e) => SesiAktifInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      programStudiId  : json['program_studi_id'] as String?,
    );
  }

  String get namaDepan => namaMahasiswa.split(' ').first;
}

// ─── HomeScreen ───────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {

  HomeSummaryModel? _summary;
  bool    _isLoading = true;
  String? _error;
  Timer?  _countdownTimer;
  Duration? _sisaWaktu;
  bool    _isFetching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient().get('/mahasiswa/home-summary');
      final json     = jsonDecode(response.body) as Map<String, dynamic>;
      final summary  = HomeSummaryModel.fromJson(json);
      if (!mounted) return;
      setState(() { _summary = summary; _isLoading = false; });

      if (summary.sesiAktif.isNotEmpty) {
        final onlineSesi = summary.sesiAktif
            .where((s) => s.isOnline && s.detikTersisa != null)
            .toList();
        if (onlineSesi.isNotEmpty) {
          _startCountdown(onlineSesi.first.detikTersisa!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    } finally {
      _isFetching = false;
    }
  }

  void _startCountdown(int detikAwal) {
    _sisaWaktu = Duration(seconds: detikAwal);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_sisaWaktu != null && _sisaWaktu!.inSeconds > 0) {
        setState(() => _sisaWaktu = _sisaWaktu! - const Duration(seconds: 1));
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  String _getSapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat Pagi';
    if (jam < 15) return 'Selamat Siang';
    if (jam < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: RefreshIndicator(
        onRefresh: _fetchSummary,
        color    : AppColors.kNavy,
        child    : _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────
  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        _buildAppBarPlaceholder(),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.kNavy),
                const SizedBox(height: 16),
                Text('Memuat data...',
                  style: AppTypography.body2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBarPlaceholder() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned        : true,
      backgroundColor: AppColors.kNavy,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.kNavyGradient),
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────
  Widget _buildError() {
    return CustomScrollView(
      slivers: [
        _buildAppBarPlaceholder(),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 64,
                    color: AppColors.kSoftGray),
                  const SizedBox(height: 16),
                  Text('Gagal memuat data', style: AppTypography.heading3),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center,
                    style: AppTypography.body2),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton.icon(
                      onPressed: _fetchSummary,
                      icon : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Body utama ─────────────────────────────────────────────
  Widget _buildBody() {
    final s = _summary!;
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(s),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver : SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // Banner sesi aktif
              if (s.sesiAktif.isNotEmpty) ...[
                _SesiAktifBanner(
                  sesi      : s.sesiAktif.first,
                  sisaWaktu : _sisaWaktu,
                  onPresensi: () => context.go('/scan'),
                ),
                const SizedBox(height: 20),
              ],

              // Card statistik kehadiran (DIPERBAIKI)
              _StatKehadiranCard(stat: s.statSemester),
              const SizedBox(height: 24),

              // Header jadwal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Jadwal Hari Ini', style: AppTypography.sectionTitle),
                  Text(
                    DateFormat('EEE, d MMM yyyy', 'id_ID')
                        .format(DateTime.now()),
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List jadwal
              if (s.jadwalHariIni.isEmpty)
                _EmptyJadwal()
              else
                ...s.jadwalHariIni.map((j) => _JadwalCard(
                  jadwal: j,
                  onScan: () => context.go('/scan'),
                )),
            ]),
          ),
        ),
      ],
    );
  }

  // ── SliverAppBar ───────────────────────────────────────────
  Widget _buildSliverAppBar(HomeSummaryModel s) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned        : true,
      floating      : false,
      backgroundColor: AppColors.kNavy,
      elevation     : 0,
      automaticallyImplyLeading: false,
      // Collapsed state
      title: Row(
        children: [
          // Logo UMS placeholder (fallback jika asset belum ada)
          _UMSLogo(size: 28),
          const SizedBox(width: 10),
          Text(s.namaDepan, style: AppTypography.hero.copyWith(fontSize: 16)),
        ],
      ),
      titleSpacing: 16,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2,
          color: AppColors.kGold.withOpacity(0.4)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background  : _AppBarBg(
          sapaan : _getSapaan(),
          nama   : s.namaDepan,
          nim    : s.nim,
          inisial: s.namaMahasiswa.isNotEmpty
              ? s.namaMahasiswa[0].toUpperCase() : '?',
        ),
      ),
    );
  }
}

// ─── AppBar Background ────────────────────────────────────────

class _AppBarBg extends StatelessWidget {
  final String sapaan, nama, nim, inisial;
  const _AppBarBg({
    required this.sapaan,
    required this.nama,
    required this.nim,
    required this.inisial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.kNavyGradient),
      child: Stack(
        children: [
          // Dekorasi geometrik
          Positioned(
            right: -30, top: -20,
            child: _GeoDecor(size: 130, opacity: 0.06),
          ),
          Positioned(
            right: 50, bottom: 10,
            child: _GeoDecor(size: 55, opacity: 0.04),
          ),
          // Garis gold bawah
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(height: 2,
              color: AppColors.kGold.withOpacity(0.4)),
          ),
          // Konten
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _UMSLogo(size: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment : MainAxisAlignment.center,
                      mainAxisSize      : MainAxisSize.min,
                      children: [
                        Text(sapaan, style: AppTypography.heroSubtitle),
                        const SizedBox(height: 3),
                        Text(nama,
                          style: AppTypography.hero.copyWith(fontSize: 22),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(nim,
                          style: AppTypography.heroSubtitle.copyWith(
                            fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  CircleAvatar(
                    radius         : 26,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: Text(inisial,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logo UMS ─────────────────────────────────────────────────

class _UMSLogo extends StatelessWidget {
  final double size;
  const _UMSLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Logo_UMS.png',
      width : size,
      height: size,
      errorBuilder: (_, __, ___) => Container(
        width : size,
        height: size,
        decoration: BoxDecoration(
          color       : AppColors.kGold,
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Text(
            'U',
            style: TextStyle(
              color     : AppColors.kNavyDark,
              fontSize  : size * 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Geometric Decor ──────────────────────────────────────────

class _GeoDecor extends StatelessWidget {
  final double size, opacity;
  const _GeoDecor({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width : size, height: size,
        decoration: BoxDecoration(
          border      : Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Container(
            width : size * 0.6, height: size * 0.6,
            decoration: BoxDecoration(
              border      : Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(size * 0.12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── [DIPERBAIKI] Stat Kehadiran Card ─────────────────────────
// Fix: circular progress tidak terpotong, layout lebih proporsional

class _StatKehadiranCard extends StatelessWidget {
  final StatKehadiran stat;
  const _StatKehadiranCard({required this.stat});

  Color get _warna {
    if (stat.persentase >= 75) return AppColors.kStatusHadir;
    if (stat.persentase >= 60) return AppColors.kStatusTerlambat;
    return AppColors.kStatusAbsen;
  }

  @override
  Widget build(BuildContext context) {
    final persen = stat.persentase;
    final hadirEfektif = stat.hadir + stat.terlambat;

    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow   : AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Kehadiran Semester Ini',
            style: AppTypography.sectionTitle.copyWith(fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              // ── Lingkaran progress — FIX: ukuran cukup besar ──
              SizedBox(
                width : 100,
                height: 100,
                child : Stack(
                  alignment: Alignment.center,
                  children : [
                    // Track (background)
                    SizedBox(
                      width : 100,
                      height: 100,
                      child : CircularProgressIndicator(
                        value      : 1.0,
                        strokeWidth: 9,
                        valueColor : AlwaysStoppedAnimation(
                          AppColors.kSoftGray),
                      ),
                    ),
                    // Progress
                    SizedBox(
                      width : 100,
                      height: 100,
                      child : CircularProgressIndicator(
                        value      : (persen / 100).clamp(0.0, 1.0),
                        strokeWidth: 9,
                        backgroundColor: Colors.transparent,
                        valueColor : AlwaysStoppedAnimation(_warna),
                        strokeCap  : StrokeCap.round,
                      ),
                    ),
                    // Teks tengah
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        Text(
                          '${persen.toStringAsFixed(0)}%',
                          style: AppTypography.heading3.copyWith(
                            color   : _warna,
                            fontSize: 22,
                          ),
                        ),
                        Text('hadir',
                          style: AppTypography.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // ── Stat kanan ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      icon : Icons.check_circle_outline,
                      color: AppColors.kStatusHadir,
                      label: 'Hadir Efektif',
                      nilai: '$hadirEfektif sesi',
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon : Icons.event_note_outlined,
                      color: AppColors.kNavy,
                      label: 'Total Sesi',
                      nilai: '${stat.totalPertemuan} sesi',
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon : Icons.cancel_outlined,
                      color: AppColors.kStatusAbsen,
                      label: 'Absen',
                      nilai: '${stat.absen} sesi',
                    ),
                    // Warning jika kehadiran rendah
                    if (persen < 75) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color       : AppColors.kWarning.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                              color: AppColors.kWarning, size: 12),
                            const SizedBox(width: 4),
                            Text('Di bawah 75%',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.kWarning, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   nilai;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.nilai,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
            style: AppTypography.body2.copyWith(fontSize: 12)),
        ),
        Text(nilai,
          style: AppTypography.bodyBold.copyWith(
            color: AppColors.kNavy, fontSize: 12)),
      ],
    );
  }
}

// ─── [DIPERBAIKI] Kartu Jadwal ────────────────────────────────
// Fix: badge kelas muncul, nama dosen tampil, layout tidak overflow

class _JadwalCard extends StatelessWidget {
  final JadwalModel  jadwal;
  final VoidCallback onScan;

  const _JadwalCard({required this.jadwal, required this.onScan});

  Color _statusColor() {
    switch (jadwal.statusPresensi) {
      case 'hadir'    : return AppColors.kStatusHadir;
      case 'terlambat': return AppColors.kStatusTerlambat;
      case 'absen'    : return AppColors.kStatusAbsen;
      default         : return jadwal.adaSesiAktif
          ? AppColors.kNavy : AppColors.kSoftGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color      = _statusColor();
    final sesiAktif  = jadwal.adaSesiAktif;
    final sudahHadir = jadwal.sudahPresensi;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        border      : sesiAktif && !sudahHadir
            ? Border.all(color: AppColors.kNavy.withOpacity(0.25), width: 1.5)
            : null,
        boxShadow   : AppDecorations.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child  : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Garis vertikal status
            Container(
              width     : 4,
              height    : 72,
              decoration: BoxDecoration(
                color       : color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Info MK
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris 1: kode MK + badge kelas + SKS
                  Row(
                    children: [
                      // Kode MK
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color       : AppColors.kNavy.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(jadwal.kode,
                          style: AppTypography.badge.copyWith(
                            color: AppColors.kNavy, fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      // ✅ Badge kelas A/B/C
                      if (jadwal.kodeKelas != null &&
                          jadwal.kodeKelas!.isNotEmpty)
                        KelasBadge(kodeKelas: jadwal.kodeKelas!),
                      const SizedBox(width: 6),
                      Text('${jadwal.sks} SKS',
                        style: AppTypography.caption),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Baris 2: nama MK
                  Text(jadwal.nama,
                    style: AppTypography.bodyBold.copyWith(
                      color: AppColors.kNavyDark, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 3),

                  // ✅ Baris 3: nama dosen (jika ada)
                  if (jadwal.dosenNama != null &&
                      jadwal.dosenNama!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                          size: 11, color: AppColors.kTextSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(jadwal.dosenNama!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.kTextSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Baris 4: jam + ruangan
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                        size: 11, color: AppColors.kTextSecondary),
                      const SizedBox(width: 3),
                      Text(jadwal.labelJam,
                        style: AppTypography.caption),
                      if (jadwal.ruanganEfektif != '-') ...[
                        const SizedBox(width: 10),
                        Icon(Icons.room_outlined,
                          size: 11, color: AppColors.kTextSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(jadwal.ruanganEfektif,
                            style: AppTypography.caption,
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Tombol / badge status
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (sesiAktif && !sudahHadir)
                  GestureDetector(
                    onTap : onScan,
                    child : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color       : AppColors.kNavy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Presensi',
                        style: AppTypography.buttonSmall.copyWith(
                          color: Colors.white, fontSize: 12)),
                    ),
                  )
                else
                  _StatusBadge(status: jadwal.statusPresensi ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case 'hadir'    : return 'Hadir';
      case 'terlambat': return 'Terlambat';
      case 'absen'    : return 'Absen';
      case 'izin'     : return 'Izin';
      case 'sakit'    : return 'Sakit';
      default         : return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = AppColors.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Text(_label,
        style: AppTypography.badge.copyWith(color: color, fontSize: 10)),
    );
  }
}

// ─── Sesi Aktif Banner ────────────────────────────────────────

class _SesiAktifBanner extends StatelessWidget {
  final SesiAktifInfo sesi;
  final Duration?     sisaWaktu;
  final VoidCallback  onPresensi;

  const _SesiAktifBanner({
    required this.sesi,
    required this.sisaWaktu,
    required this.onPresensi,
  });

  String _formatDurasi(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = sesi.isOnline;
    final gradColors = isOnline
        ? [AppColors.kNavyDark, AppColors.kNavy]
        : [const Color(0xFF1B5E20), AppColors.kGreen];

    return Container(
      decoration: BoxDecoration(
        gradient    : LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: gradColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow   : [
          BoxShadow(
            color     : (isOnline ? AppColors.kNavy : AppColors.kGreen)
                .withOpacity(0.30),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge status aktif
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color       : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        'SESI ${isOnline ? 'ONLINE' : 'OFFLINE'} AKTIF',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text('Pertemuan ${sesi.pertemuanKe}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),

            // Nama MK + badge kelas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama MK + badge kelas
                      Row(
                        children: [
                          Flexible(
                            child: Text(sesi.matakuliahNama,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sesi.kodeKelas != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.40)),
                              ),
                              child: Text('Kelas ${sesi.kodeKelas}',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      if (sesi.dosenNama != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                              size: 11, color: Colors.white60),
                            const SizedBox(width: 3),
                            Text(sesi.dosenNama!,
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isOnline ? Icons.laptop_outlined
                                : Icons.location_on_outlined,
                            size: 10, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(isOnline ? 'Online' : 'Tatap Muka',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
                          if (sesi.ruangan != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.room_outlined,
                              size: 10, color: Colors.white54),
                            const SizedBox(width: 3),
                            Text(sesi.ruangan!,
                              style: const TextStyle(
                                color: Colors.white60, fontSize: 10)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Countdown + tombol
            Row(
              children: [
                if (sisaWaktu != null && sesi.isOnline) ...[
                  const Icon(Icons.timer_outlined,
                    color: Colors.white70, size: 14),
                  const SizedBox(width: 5),
                  Text('Sisa ${_formatDurasi(sisaWaktu!)}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onPresensi,
                  icon : const Icon(Icons.face_rounded, size: 16),
                  label: const Text('Presensi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isOnline
                        ? AppColors.kNavy : const Color(0xFF1B5E20),
                    elevation  : 0,
                    padding    : const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    textStyle: AppTypography.buttonSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty Jadwal ─────────────────────────────────────────────

class _EmptyJadwal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow   : AppDecorations.cardShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined,
            size: 48, color: AppColors.kSoftGray),
          const SizedBox(height: 12),
          Text('Tidak ada jadwal hari ini', style: AppTypography.body2),
        ],
      ),
    );
  }
}