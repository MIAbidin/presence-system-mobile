// lib/screens/home_screen.dart
// v2.1.0 — Fase 2: Update tema UMS, badge kelas, nama dosen, mode sesi aktif

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
import 'package:presensi_app/widgets/slot_label.dart';
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
  final String  mode;
  final int?    detikTersisa;
  final int     pertemuanKe;

  // ── [BARU v2.1.0] ─────────────────────────────────────────
  final String? kodeKelas;
  final String? dosenNama;
  final String? kelasId;

  const SesiAktifInfo({
    required this.sesiId,
    required this.matakuliahNama,
    required this.mode,
    this.detikTersisa,
    required this.pertemuanKe,
    this.kodeKelas,
    this.dosenNama,
    this.kelasId,
  });

  factory SesiAktifInfo.fromJson(Map<String, dynamic> json) => SesiAktifInfo(
    sesiId         : json['sesi_id']          as String? ?? '',
    matakuliahNama : json['matakuliah_nama']   as String? ?? '',
    mode           : json['mode']             as String? ?? '',
    detikTersisa   : json['detik_tersisa']     as int?,
    pertemuanKe    : json['pertemuan_ke']      as int? ?? 0,
    kodeKelas      : json['kode_kelas']        as String?,
    dosenNama      : json['dosen_nama']        as String?,
    kelasId        : json['kelas_id']          as String?,
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

  // ── [BARU v2.1.0] ─────────────────────────────────────────
  final String? programStudiId;

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
      namaMahasiswa   : json['nama_mahasiswa']    as String? ?? '',
      nim             : json['nim']               as String? ?? '',
      isFaceRegistered: json['is_face_registered'] as bool? ?? false,
      statSemester    : StatKehadiran.fromJson(
          (json['stat_semester'] as Map<String, dynamic>?) ?? {}),
      presensiHariIni : json['presensi_hari_ini'] as int? ?? 0,
      jadwalHariIni   : ((json['jadwal_hari_ini'] as List<dynamic>?) ?? [])
          .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sesiAktif       : ((json['sesi_aktif'] as List<dynamic>?) ?? [])
          .map((e) => SesiAktifInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      programStudiId  : json['program_studi_id'] as String?,
    );
  }
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
  bool   _isLoading = true;
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
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final summary = HomeSummaryModel.fromJson(json);

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
        setState(() { _sisaWaktu = _sisaWaktu! - const Duration(seconds: 1); });
      } else {
        _countdownTimer?.cancel();
        setState(() => _sisaWaktu = Duration.zero);
      }
    });
  }

  void _goToScan() => context.go('/scan');

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
        _buildUMSSliverAppBar(s),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver : SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // Banner sesi aktif
              if (s.sesiAktif.isNotEmpty) ...[
                _SesiAktifBanner(
                  sesi      : s.sesiAktif.first,
                  sisaWaktu : _sisaWaktu,
                  onPresensi: _goToScan,
                ),
                const SizedBox(height: 20),
              ],

              // Kartu statistik kehadiran
              _StatUtamaCard(
                persentase: s.statSemester.persentase,
                totalHadir: s.statSemester.hadir + s.statSemester.terlambat,
                totalSesi : s.statSemester.totalPertemuan,
                absen     : s.statSemester.absen,
              ),
              const SizedBox(height: 20),

              // Header jadwal hari ini
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
                  jadwal : j,
                  onScan : _goToScan,
                )),
            ]),
          ),
        ),
      ],
    );
  }

  // ── UMS SliverAppBar dengan logo ──────────────────────────
  Widget _buildUMSSliverAppBar(HomeSummaryModel s) {
    final namaDepan   = s.namaMahasiswa.split(' ').first;
    final jamSekarang = DateTime.now().hour;
    final sapaan = jamSekarang < 11
        ? 'Selamat Pagi,'
        : jamSekarang < 15
            ? 'Selamat Siang,'
            : jamSekarang < 18
                ? 'Selamat Sore,'
                : 'Selamat Malam,';

    return SliverAppBar(
      expandedHeight          : 170,
      pinned                  : true,
      floating                : false,
      backgroundColor         : AppColors.kNavy,
      elevation               : 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background  : Container(
          decoration: const BoxDecoration(gradient: AppColors.kNavyGradient),
          child: Stack(
            children: [
              // Dekorasi geometrik kanan atas
              Positioned(
                right : -25,
                top   : -20,
                child : Opacity(
                  opacity: 0.07,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      border      : Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          border      : Border.all(color: Colors.white, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Garis gold di bawah
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 2,
                  color : AppColors.kGold.withOpacity(0.5),
                ),
              ),
              // Konten utama
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Logo UMS
                          _UMSLogoWidget(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sapaan,
                                  style: AppTypography.heroSubtitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  namaDepan,
                                  style   : AppTypography.hero.copyWith(fontSize: 22),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  s.nim,
                                  style: AppTypography.heroSubtitle.copyWith(
                                    fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Avatar initial
                          CircleAvatar(
                            radius         : 26,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            child          : Text(
                              s.namaMahasiswa.isNotEmpty
                                  ? s.namaMahasiswa[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Title saat collapsed
      title: Row(
        children: [
          _UMSLogoWidget(size: 26),
          const SizedBox(width: 8),
          Text(
            'Beranda',
            style: AppTypography.hero.copyWith(fontSize: 16),
          ),
        ],
      ),
      titleSpacing: 16,
    );
  }
}

// ─── Logo Widget UMS ─────────────────────────────────────────

class _UMSLogoWidget extends StatelessWidget {
  final double size;
  const _UMSLogoWidget({this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Logo_UMS.png',
      height: size,
      width : size,
      errorBuilder: (_, __, ___) => Container(
        width : size,
        height: size,
        decoration: BoxDecoration(
          color       : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            'U',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Banner Sesi Aktif (v2.1.0 — tambah badge kelas, dosen, mode) ────

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
    return Container(
      decoration: BoxDecoration(
        gradient    : const LinearGradient(
          colors: [Color(0xFF00695C), AppColors.kGreen],
          begin: Alignment.topLeft,
          end  : Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        boxShadow   : [
          BoxShadow(
            color     : AppColors.kGreen.withOpacity(0.30),
            blurRadius: 16,
            offset    : const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris status badge
            Row(
              children: [
                Container(
                  padding    : const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration : BoxDecoration(
                    color      : Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      Container(
                        width : 7, height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SESI ${sesi.isOnline ? 'ONLINE' : 'OFFLINE'} AKTIF',
                        style: const TextStyle(
                          color     : Colors.white,
                          fontSize  : 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // [BARU v2.1.0] Mode badge
                _ModeBadgeWhite(mode: sesi.mode),
              ],
            ),
            const SizedBox(height: 10),

            // Nama MK
            Text(
              sesi.matakuliahNama,
              style: const TextStyle(
                color: Colors.white, fontSize: 17,
                fontWeight: FontWeight.bold),
            ),

            // [BARU v2.1.0] Kelas + dosen + pertemuan
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Pertemuan ke-${sesi.pertemuanKe}',
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
                ),
                if (sesi.kodeKelas != null) ...[
                  const SizedBox(width: 8),
                  _KelasBadgeWhite(kodeKelas: sesi.kodeKelas!),
                ],
                if (sesi.dosenNama != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sesi.dosenNama!,
                      style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Baris countdown + tombol presensi
            Row(
              children: [
                if (sisaWaktu != null && sesi.isOnline) ...[
                  const Icon(Icons.timer_outlined,
                    color: Colors.white70, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'Sisa ${_formatDurasi(sisaWaktu!)}',
                    style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  onPressed  : onPresensi,
                  icon       : const Icon(Icons.face_rounded, size: 17),
                  label      : const Text('Presensi Sekarang'),
                  style      : ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.kGreen,
                    elevation      : 0,
                    padding        : const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    textStyle: AppTypography.buttonSmall.copyWith(
                      color: AppColors.kGreen),
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

// Badge mode putih untuk di atas banner hijau
class _ModeBadgeWhite extends StatelessWidget {
  final String mode;
  const _ModeBadgeWhite({required this.mode});

  bool get _isOnline => mode.toLowerCase() == 'online';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.laptop_outlined : Icons.location_on_outlined,
            size: 10, color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            _isOnline ? 'Online' : 'Tatap Muka',
            style: const TextStyle(
              color     : Colors.white,
              fontSize  : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Badge kelas putih untuk di dalam banner
class _KelasBadgeWhite extends StatelessWidget {
  final String kodeKelas;
  const _KelasBadgeWhite({required this.kodeKelas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color       : Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Kelas $kodeKelas',
        style: const TextStyle(
          color     : Colors.white,
          fontSize  : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Stat Utama Card ──────────────────────────────────────────

class _StatUtamaCard extends StatelessWidget {
  final double persentase;
  final int    totalHadir;
  final int    totalSesi;
  final int    absen;

  const _StatUtamaCard({
    required this.persentase,
    required this.totalHadir,
    required this.totalSesi,
    required this.absen,
  });

  Color get _warnaRing => AppColors.persentaseColor(persentase);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color      : AppColors.kSurface,
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        // Border bawah gold untuk kartu featured
        border     : const Border(
          bottom: BorderSide(color: AppColors.kGold, width: 3),
        ),
        boxShadow  : AppDecorations.cardShadow,
      ),
      child: Row(
        children: [
          // Ring persentase
          SizedBox(
            width : 88,
            height: 88,
            child : Stack(
              alignment: Alignment.center,
              children : [
                CircularProgressIndicator(
                  value          : (persentase / 100).clamp(0.0, 1.0),
                  strokeWidth    : 8,
                  backgroundColor: AppColors.kSoftGray,
                  valueColor     : AlwaysStoppedAnimation(_warnaRing),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    Text(
                      '${persentase.toStringAsFixed(0)}%',
                      style: AppTypography.sectionTitle.copyWith(
                        color   : _warnaRing,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Hadir',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.kTextSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kehadiran Semester Ini',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 10),
                _StatRow(
                  icon : Icons.check_circle_outline,
                  color: AppColors.kStatusHadir,
                  label: 'Hadir Efektif',
                  value: '$totalHadir sesi',
                ),
                const SizedBox(height: 6),
                _StatRow(
                  icon : Icons.event_note_outlined,
                  color: AppColors.kNavy,
                  label: 'Total Sesi',
                  value: '$totalSesi sesi',
                ),
                const SizedBox(height: 6),
                _StatRow(
                  icon : Icons.cancel_outlined,
                  color: AppColors.kStatusAbsen,
                  label: 'Absen',
                  value: '$absen sesi',
                ),
                // Peringatan jika kehadiran < 75%
                if (persentase < 75) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding    : const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                    decoration : BoxDecoration(
                      color      : AppColors.kStatusTerlambat.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border     : Border.all(
                        color: AppColors.kStatusTerlambat.withOpacity(0.30),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        Icon(Icons.warning_amber_rounded,
                          color: AppColors.kWarning, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Kehadiran di bawah 75%',
                          style: AppTypography.caption.copyWith(
                            color     : AppColors.kWarning,
                            fontWeight: FontWeight.w600,
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
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
        const SizedBox(width: 4),
        Text(value, style: AppTypography.caption.copyWith(
          color     : AppColors.kNavyDark,
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }
}

// ─── Jadwal Card (v2.1.0 — badge kelas + nama dosen + mode) ──

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
    final color      = _statusColor();
    final adaAktif   = jadwal.adaSesiAktif && !jadwal.sudahPresensi;
    final modePengganti = jadwal.modeEfektif;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color      : AppColors.kSurface,
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        border     : adaAktif
            ? Border.all(color: AppColors.kNavy.withOpacity(0.35), width: 1.5)
            : null,
        boxShadow  : AppDecorations.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child  : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Garis vertikal warna status
                Container(
                  width : 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color       : color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Info matakuliah
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [BARU v2.1.0] Baris badge kelas + kode MK
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.kNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jadwal.kode,
                              style: AppTypography.caption.copyWith(
                                color     : AppColors.kNavy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (jadwal.kodeKelas != null) ...[
                            const SizedBox(width: 6),
                            KelasBadge(kodeKelas: jadwal.kodeKelas!),
                          ],
                          if (modePengganti != null) ...[
                            const SizedBox(width: 6),
                            ModeBadge(mode: modePengganti),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Nama MK
                      Text(
                        jadwal.nama,
                        style: AppTypography.bodyBold.copyWith(
                          color: AppColors.kNavyDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // [BARU v2.1.0] Nama dosen
                      if (jadwal.dosenNama != null) ...[
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                              size: 12, color: AppColors.kTextSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jadwal.dosenNama!,
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Jam + ruangan
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.kTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            jadwal.labelJam,
                            style: AppTypography.caption,
                          ),
                          if (jadwal.ruangan != null) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.room_outlined,
                              size: 12,
                              color: AppColors.kTextSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jadwal.ruanganEfektif,
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Badge tamu
                      if (jadwal.isTamu) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_add_outlined,
                              size: 11, color: AppColors.kWarning),
                            const SizedBox(width: 3),
                            Text(
                              'Bergabung sebagai Tamu',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.kWarning),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Tombol presensi / badge status
                if (adaAktif)
                  GestureDetector(
                    onTap : onScan,
                    child : Container(
                      padding    : const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      decoration : BoxDecoration(
                        color      : AppColors.kNavy,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Presensi',
                        style: AppTypography.buttonSmall.copyWith(
                          color: Colors.white),
                      ),
                    ),
                  )
                else
                  Container(
                    padding    : const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                    decoration : BoxDecoration(
                      color      : color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      jadwal.labelStatus,
                      style: AppTypography.caption.copyWith(
                        color     : color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Alert jadwal pengganti
          if (jadwal.adaJadwalPengganti) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child  : _JadwalPenggantiMini(
                jamMulai  : jadwal.jamMulaiPengganti,
                jamSelesai: jadwal.jamSelesaiPengganti,
                ruangan   : jadwal.ruanganPengganti,
                mode      : jadwal.modePengganti,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Mini alert jadwal pengganti di dalam kartu
class _JadwalPenggantiMini extends StatelessWidget {
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final String? mode;

  const _JadwalPenggantiMini({
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    this.mode,
  });

  String _detail() {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color       : AppColors.kGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border      : Border(
          left: BorderSide(color: AppColors.kGold, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded,
            size: 14, color: AppColors.kWarning),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Diganti',
                  style: AppTypography.caption.copyWith(
                    color     : AppColors.kWarning,
                    fontWeight: FontWeight.w700,
                    fontSize  : 10,
                  ),
                ),
                Text(
                  _detail(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.kTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: AppTypography.sectionTitle),
      Text(subtitle, style: AppTypography.caption),
    ],
  );
}

class _EmptyJadwal extends StatelessWidget {
  const _EmptyJadwal();

  @override
  Widget build(BuildContext context) => Container(
    padding    : const EdgeInsets.all(24),
    decoration : BoxDecoration(
      color      : AppColors.kSurface,
      borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
      boxShadow  : AppDecorations.cardShadow,
    ),
    child: Column(
      children: [
        Icon(Icons.event_available_outlined,
          size: 48, color: AppColors.kSoftGray),
        const SizedBox(height: 12),
        Text(
          'Tidak ada jadwal hari ini',
          style: AppTypography.body2,
        ),
        const SizedBox(height: 4),
        Text(
          'Nikmati hari libur kuliah 🎉',
          style: AppTypography.caption,
        ),
      ],
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.kNavy),
        const SizedBox(height: 16),
        Text('Memuat data...', style: AppTypography.body2),
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
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
              size: 64, color: AppColors.kSoftGray),
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
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
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
    ),
  );
}