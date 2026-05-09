// lib/screens/home_screen.dart
// v2.1.0 — Fase 2: Update HomeScreen
// Perubahan:
// - SliverAppBar: tambah logo UMS (asset) di pojok kiri header
// - Card jadwal: tampilkan badge kelas (A/B/C) di sebelah kode MK
// - Card jadwal: tampilkan nama dosen pengampu di bawah nama MK
// - Banner sesi aktif: tampilkan kode kelas, nama dosen, dan mode (Offline/Online)
// - Sapaan dinamis: gunakan nama depan mahasiswa dari response

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
import 'package:presensi_app/widgets/ums_app_bar.dart';

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
  // ── [BARU v2.1.0] ────────────────────────────────────────
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
    sesiId         : json['sesi_id']          as String? ?? '',
    matakuliahNama : json['matakuliah_nama']   as String? ?? '',
    matakuliahKode : json['matakuliah_kode']   as String? ?? '',
    mode           : json['mode']              as String? ?? '',
    detikTersisa   : json['detik_tersisa']     as int?,
    pertemuanKe    : json['pertemuan_ke']      as int? ?? 0,
    kodeKelas      : json['kode_kelas']        as String?,
    dosenNama      : json['dosen_nama']        as String?,
    ruangan        : json['ruangan']           as String?,
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
  // ── [BARU v2.1.0] ────────────────────────────────────────
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
      namaMahasiswa    : json['nama_mahasiswa']     as String? ?? '',
      nim              : json['nim']                as String? ?? '',
      isFaceRegistered : json['is_face_registered'] as bool?   ?? false,
      statSemester     : StatKehadiran.fromJson(
          (json['stat_semester'] as Map<String, dynamic>?) ?? {}),
      presensiHariIni  : json['presensi_hari_ini']  as int? ?? 0,
      jadwalHariIni    : ((json['jadwal_hari_ini'] as List<dynamic>?) ?? [])
          .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sesiAktif        : ((json['sesi_aktif'] as List<dynamic>?) ?? [])
          .map((e) => SesiAktifInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      programStudiId   : json['program_studi_id']   as String?,
    );
  }

  /// Nama depan mahasiswa
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

  Timer?    _countdownTimer;
  Duration? _sisaWaktu;
  bool      _isFetching = false;

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
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final summary = HomeSummaryModel.fromJson(json);

      if (!mounted) return;
      setState(() {
        _summary   = summary;
        _isLoading = false;
      });

      // Mulai countdown untuk sesi online aktif
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
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
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
        setState(() => _sisaWaktu = Duration.zero);
      }
    });
  }

  void _goToScan() => context.go('/scan');

  // ── Sapaan dinamis ────────────────────────────────────────
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
        onRefresh : _fetchSummary,
        color     : AppColors.kNavy,
        child     : _isLoading
            ? const _LoadingView()
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _fetchSummary)
                : _buildBody(),
      ),
    );
  }

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

              // ── Banner sesi aktif ────────────────────────
              if (s.sesiAktif.isNotEmpty) ...[
                _SesiAktifBanner(
                  sesi      : s.sesiAktif.first,
                  sisaWaktu : _sisaWaktu,
                  onPresensi: _goToScan,
                ),
                const SizedBox(height: 20),
              ],

              // ── Stat kehadiran ───────────────────────────
              _StatUtamaCard(
                persentase: s.statSemester.persentase,
                totalHadir: s.statSemester.hadir + s.statSemester.terlambat,
                totalSesi : s.statSemester.totalPertemuan,
              ),
              const SizedBox(height: 24),

              // ── Jadwal hari ini ──────────────────────────
              _SectionHeader(
                title   : 'Jadwal Hari Ini',
                subtitle: DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                    .format(DateTime.now()),
              ),
              const SizedBox(height: 12),
              if (s.jadwalHariIni.isEmpty)
                const _EmptyJadwal()
              else
                ...s.jadwalHariIni.map((j) => _JadwalCard(
                  jadwal: j,
                  onScan: _goToScan,
                )),
            ]),
          ),
        ),
      ],
    );
  }

  // ── [DIPERBARUI v2.1.0] SliverAppBar dengan logo UMS ─────
  Widget _buildSliverAppBar(HomeSummaryModel s) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned        : true,
      floating      : false,
      backgroundColor: AppColors.kNavy,
      elevation     : 0,
      automaticallyImplyLeading: false,
      flexibleSpace : FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background  : _AppBarBackground(
          sapaan   : _getSapaan(),
          nama     : s.namaDepan,
          nim      : s.nim,
          inisial  : s.namaMahasiswa.isNotEmpty
              ? s.namaMahasiswa[0].toUpperCase()
              : '?',
        ),
      ),
      // Collapsed title dengan logo
      title: Row(
        children: [
          // ── Logo UMS kecil di collapsed state ────────────
          Image.asset(
            'assets/images/Logo_UMS.png',
            height: 28,
            width : 28,
            errorBuilder: (_, __, ___) => Container(
              width : 28,
              height: 28,
              decoration: BoxDecoration(
                color       : AppColors.kGold,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text('U',
                  style: TextStyle(
                    color     : AppColors.kNavyDark,
                    fontSize  : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            s.namaDepan,
            style: AppTypography.hero.copyWith(fontSize: 16),
          ),
        ],
      ),
      titleSpacing: 20,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          color : AppColors.kGold.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ─── AppBar Background ────────────────────────────────────────

class _AppBarBackground extends StatelessWidget {
  final String sapaan;
  final String nama;
  final String nim;
  final String inisial;

  const _AppBarBackground({
    required this.sapaan,
    required this.nama,
    required this.nim,
    required this.inisial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.kNavyGradient,
      ),
      child: Stack(
        children: [
          // ── Dekorasi geometrik ───────────────────────────
          Positioned(
            right : -30,
            top   : -20,
            child : _GeometricDecor(size: 130, opacity: 0.06),
          ),
          Positioned(
            right : 50,
            bottom: 10,
            child : _GeometricDecor(size: 55, opacity: 0.04),
          ),
          // ── Garis bawah gold ────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child : Container(height: 2, color: AppColors.kGold.withOpacity(0.4)),
          ),
          // ── Konten ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  // Logo UMS di expanded state
                  Image.asset(
                    'assets/images/Logo_UMS.png',
                    height: 40,
                    width : 40,
                    errorBuilder: (_, __, ___) => Container(
                      width : 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color       : AppColors.kGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('UMS',
                          style: TextStyle(
                            color     : AppColors.kNavyDark,
                            fontSize  : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment : MainAxisAlignment.center,
                      children: [
                        Text(
                          sapaan,
                          style: AppTypography.heroSubtitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nama,
                          style: AppTypography.hero.copyWith(fontSize: 22),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nim,
                          style: AppTypography.heroSubtitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar inisial
                  CircleAvatar(
                    radius         : 26,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child          : Text(
                      inisial,
                      style: const TextStyle(
                        color     : Colors.white,
                        fontSize  : 20,
                        fontWeight: FontWeight.bold,
                      ),
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

class _GeometricDecor extends StatelessWidget {
  final double size;
  final double opacity;
  const _GeometricDecor({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width : size,
        height: size,
        decoration: BoxDecoration(
          border      : Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Container(
            width : size * 0.6,
            height: size * 0.6,
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

// ─── [DIPERBARUI v2.1.0] Banner Sesi Aktif ───────────────────
// Sekarang menampilkan: kode kelas, nama dosen, mode

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
    final isOnline  = sesi.isOnline;
    final modeColor = isOnline ? AppColors.kModeOnline : AppColors.kGreen;

    return Container(
      decoration: BoxDecoration(
        gradient    : LinearGradient(
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
          colors: isOnline
              ? [AppColors.kNavyDark, AppColors.kNavy]
              : [const Color(0xFF1B5E20), AppColors.kGreen],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow   : [
          BoxShadow(
            color     : (isOnline ? AppColors.kNavy : AppColors.kGreen)
                .withOpacity(0.30),
            blurRadius: 14,
            offset    : const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: badge status sesi ──────────────────
            Row(
              children: [
                Container(
                  padding    : const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration : BoxDecoration(
                    color      : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      Container(
                        width : 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SESI ${isOnline ? 'ONLINE' : 'OFFLINE'} AKTIF',
                        style: const TextStyle(
                          color      : Colors.white,
                          fontSize   : 10,
                          fontWeight : FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // ── Pertemuan ke ────────────────────────────
                Text(
                  'Pertemuan ${sesi.pertemuanKe}',
                  style: const TextStyle(
                    color  : Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Nama MK + badge kelas ──────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // MK + badge kelas dalam satu baris
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              sesi.matakuliahNama,
                              style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ── [BARU] Badge kelas di samping nama MK ──
                          if (sesi.kodeKelas != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color       : Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(20),
                                border      : Border.all(
                                  color: Colors.white.withOpacity(0.40),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Kelas ${sesi.kodeKelas}',
                                style: const TextStyle(
                                  color     : Colors.white,
                                  fontSize  : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // ── [BARU] Nama dosen di bawah nama MK ──────
                      if (sesi.dosenNama != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size : 12,
                              color: Colors.white60,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sesi.dosenNama!,
                              style: const TextStyle(
                                color  : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      // ── [BARU] Mode badge ────────────────────────
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOnline
                                      ? Icons.laptop_outlined
                                      : Icons.location_on_outlined,
                                  size : 10,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'Online' : 'Tatap Muka',
                                  style: const TextStyle(
                                    color  : Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sesi.ruangan != null) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.room_outlined,
                                  size : 11,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  sesi.ruangan!,
                                  style: const TextStyle(
                                    color  : Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Countdown + tombol presensi ────────────────
            Row(
              children: [
                if (sisaWaktu != null && sesi.isOnline) ...[
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white70,
                    size : 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Sisa ${_formatDurasi(sisaWaktu!)}',
                    style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                // Tombol presensi
                ElevatedButton.icon(
                  onPressed  : onPresensi,
                  icon       : const Icon(Icons.face_rounded, size: 17),
                  label      : const Text('Presensi'),
                  style      : ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isOnline
                        ? AppColors.kNavy
                        : const Color(0xFF1B5E20),
                    elevation  : 0,
                    padding    : const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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

// ─── [DIPERBARUI v2.1.0] Kartu Jadwal ─────────────────────────
// Sekarang menampilkan: badge kelas (A/B/C) + nama dosen

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
          ? AppColors.kNavy
          : AppColors.kTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color        = _statusColor();
    final sesiAktif    = jadwal.adaSesiAktif;
    final sudahPresensi = jadwal.sudahPresensi;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        border      : sesiAktif && !sudahPresensi
            ? Border.all(color: AppColors.kNavy.withOpacity(0.25), width: 1.5)
            : null,
        boxShadow   : AppDecorations.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child  : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Garis vertikal status
            Container(
              width     : 4,
              height    : 60,
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
                  // ── Baris 1: kode MK + badge kelas ──────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color      : AppColors.kNavy.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          jadwal.kode,
                          style: AppTypography.badge.copyWith(
                            color   : AppColors.kNavy,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      // ── [BARU] Badge kelas di sebelah kode MK ──
                      if (jadwal.kodeKelas != null &&
                          jadwal.kodeKelas!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        KelasBadge(kodeKelas: jadwal.kodeKelas!),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '${jadwal.sks} SKS',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // ── Baris 2: nama MK ─────────────────────
                  Text(
                    jadwal.nama,
                    style: AppTypography.bodyBold.copyWith(
                      color   : AppColors.kNavyDark,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // ── [BARU] Baris 3: nama dosen pengampu ──
                  if (jadwal.dosenNama != null &&
                      jadwal.dosenNama!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size : 12,
                          color: AppColors.kTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            jadwal.dosenNama!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.kTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // ── Baris 4: jam + ruangan ────────────────
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size : 12,
                        color: AppColors.kTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        jadwal.labelJam,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.kTextSecondary,
                        ),
                      ),
                      if (jadwal.ruanganEfektif != '-') ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.room_outlined,
                          size : 12,
                          color: AppColors.kTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            jadwal.ruanganEfektif,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.kTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Tombol / badge status ────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (sesiAktif && !sudahPresensi)
                  GestureDetector(
                    onTap : onScan,
                    child : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.kNavy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Presensi',
                        style: AppTypography.buttonSmall.copyWith(
                          color   : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  StatusPresensiiBadge(status: jadwal.statusPresensi ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Kehadiran Card ──────────────────────────────────────

class _StatUtamaCard extends StatelessWidget {
  final double persentase;
  final int    totalHadir;
  final int    totalSesi;

  const _StatUtamaCard({
    required this.persentase,
    required this.totalHadir,
    required this.totalSesi,
  });

  Color get _warna {
    if (persentase >= 75) return AppColors.kStatusHadir;
    if (persentase >= 60) return AppColors.kStatusTerlambat;
    return AppColors.kStatusAbsen;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.all(20),
      decoration : BoxDecoration(
        color      : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow  : AppDecorations.cardShadow,
      ),
      child: Row(
        children: [
          // Lingkaran persentase
          SizedBox(
            width : 90,
            height: 90,
            child : Stack(
              alignment: Alignment.center,
              children : [
                CircularProgressIndicator(
                  value      : (persentase / 100).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: AppColors.kSoftGray,
                  valueColor : AlwaysStoppedAnimation(_warna),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    Text(
                      '${persentase.toStringAsFixed(0)}%',
                      style: AppTypography.heading3.copyWith(
                        color   : _warna,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Hadir',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kehadiran Semester Ini',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 10),
                _statRow(
                  icon : Icons.check_circle_outline,
                  color: AppColors.kStatusHadir,
                  label: 'Hadir Efektif',
                  nilai: '$totalHadir sesi',
                ),
                const SizedBox(height: 6),
                _statRow(
                  icon : Icons.event_note_outlined,
                  color: AppColors.kNavy,
                  label: 'Total Sesi',
                  nilai: '$totalSesi sesi',
                ),
                if (persentase < 75) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color       : AppColors.kWarning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.kWarning,
                          size : 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Di bawah 75%',
                          style: AppTypography.badge.copyWith(
                            color  : AppColors.kWarning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required Color    color,
    required String   label,
    required String   nilai,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.body2.copyWith(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          nilai,
          style: AppTypography.bodyBold.copyWith(
            color  : AppColors.kNavy,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.sectionTitle),
        Text(subtitle, style: AppTypography.caption),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────

class _EmptyJadwal extends StatelessWidget {
  const _EmptyJadwal();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.all(32),
      decoration : BoxDecoration(
        color      : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow  : AppDecorations.cardShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size : 48,
            color: AppColors.kSoftGray,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada jadwal hari ini',
            style: AppTypography.body2,
          ),
        ],
      ),
    );
  }
}

// ─── Loading & Error ─────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.kNavy),
          SizedBox(height: 16),
          Text('Memuat data...', style: TextStyle(color: AppColors.kTextSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child  : Column(
          mainAxisSize: MainAxisSize.min,
          children    : [
            Icon(
              Icons.wifi_off_rounded,
              size : 64,
              color: AppColors.kSoftGray,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style    : AppTypography.body2,
            ),
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
                    borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}