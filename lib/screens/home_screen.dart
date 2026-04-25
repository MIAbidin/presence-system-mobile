// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/models/jadwal.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/widgets/bottom_nav.dart';

const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFF2A5298);
const _kAccent    = Color(0xFF00BFA5);
const _kWarning   = Color(0xFFFFA726);
const _kDanger    = Color(0xFFEF5350);
const _kBgLight   = Color(0xFFF5F7FA);

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

  const SesiAktifInfo({
    required this.sesiId,
    required this.matakuliahNama,
    required this.mode,
    this.detikTersisa,
    required this.pertemuanKe,
  });

  factory SesiAktifInfo.fromJson(Map<String, dynamic> json) => SesiAktifInfo(
    sesiId        : json['sesi_id']          as String? ?? '',
    matakuliahNama: json['matakuliah_nama']   as String? ?? '',
    mode          : json['mode']              as String? ?? '',
    detikTersisa  : json['detik_tersisa']     as int?,
    pertemuanKe   : json['pertemuan_ke']      as int? ?? 0,
  );

  bool get isOnline => mode == 'online';
}

class HomeSummaryModel {
  final String           namaMahasiswa;
  final String           nim;
  final bool             isFaceRegistered;
  final StatKehadiran    statSemester;
  final int              presensiHariIni;
  final List<JadwalModel> jadwalHariIni;
  final List<SesiAktifInfo> sesiAktif;

  const HomeSummaryModel({
    required this.namaMahasiswa,
    required this.nim,
    required this.isFaceRegistered,
    required this.statSemester,
    required this.presensiHariIni,
    required this.jadwalHariIni,
    required this.sesiAktif,
  });

  /// Parse dari response GET /mahasiswa/home-summary
  /// Backend response sesuai HomeSummaryResponse di app/schemas/home.py
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
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      // ApiClient().get() returns http.Response — we must decode body manually
      final response = await ApiClient().get('/mahasiswa/home-summary');

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;

      final summary = HomeSummaryModel.fromJson(json);

      if (!mounted) return;
      setState(() {
        _summary   = summary;
        _isLoading = false;
      });

      // Start countdown if there's an active online session with time remaining
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
    }
  }

  void _startCountdown(int detikAwal) {
    _sisaWaktu = Duration(seconds: detikAwal);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_sisaWaktu != null && _sisaWaktu!.inSeconds > 0) {
          _sisaWaktu = _sisaWaktu! - const Duration(seconds: 1);
        } else {
          _sisaWaktu = Duration.zero;
          _countdownTimer?.cancel();
          _fetchSummary();
        }
      });
    });
  }

  void _goToScan() => context.go('/scan');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _kBgLight,
      body: RefreshIndicator(
        onRefresh : _fetchSummary,
        color     : _kNavy,
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

              // Kartu statistik
              _StatUtamaCard(
                persentase: s.statSemester.persentase,
                totalHadir: s.statSemester.hadir + s.statSemester.terlambat,
                totalSesi : s.statSemester.totalPertemuan,
              ),
              const SizedBox(height: 20),

              // Jadwal hari ini
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

  Widget _buildSliverAppBar(HomeSummaryModel s) {
    final namaDepan    = s.namaMahasiswa.split(' ').first;
    final jamSekarang  = DateTime.now().hour;
    final sapaan = jamSekarang < 11
        ? 'Selamat Pagi'
        : jamSekarang < 15
            ? 'Selamat Siang'
            : jamSekarang < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';

    return SliverAppBar(
      expandedHeight : 160,
      pinned         : true,
      backgroundColor: _kNavy,
      elevation      : 0,
      automaticallyImplyLeading: false,
      flexibleSpace  : FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin  : Alignment.topLeft,
              end    : Alignment.bottomRight,
              colors : [_kNavy, _kNavyLight],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment : MainAxisAlignment.center,
                      children: [
                        Text(sapaan,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(namaDepan,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(s.nim,
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius         : 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child          : Text(
                      s.namaMahasiswa.isNotEmpty ? s.namaMahasiswa[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: const Text('Beranda',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      titleSpacing: 20,
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────

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
        gradient    : const LinearGradient(colors: [Color(0xFF00897B), _kAccent]),
        borderRadius: BorderRadius.circular(16),
        boxShadow   : [
          BoxShadow(
            color     : _kAccent.withOpacity(0.3),
            blurRadius: 12,
            offset    : const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding    : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration : BoxDecoration(
                    color      : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      const Icon(Icons.circle, color: Colors.white, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        'SESI ${sesi.isOnline ? 'ONLINE' : 'OFFLINE'} AKTIF',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(sesi.matakuliahNama,
              style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Pertemuan ke-${sesi.pertemuanKe}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (sisaWaktu != null && sesi.isOnline) ...[
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text('Sisa ${_formatDurasi(sisaWaktu!)}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                ],
                ElevatedButton.icon(
                  onPressed  : onPresensi,
                  icon       : const Icon(Icons.face_rounded, size: 18),
                  label      : const Text('Presensi Sekarang'),
                  style      : ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00897B),
                    elevation      : 0,
                    padding        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape          : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

class _StatUtamaCard extends StatelessWidget {
  final double persentase;
  final int    totalHadir;
  final int    totalSesi;

  const _StatUtamaCard({
    required this.persentase,
    required this.totalHadir,
    required this.totalSesi,
  });

  Color get _warnaRing {
    if (persentase >= 75) return _kAccent;
    if (persentase >= 60) return _kWarning;
    return _kDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.all(20),
      decoration : BoxDecoration(
        color      : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow  : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width : 90,
            height: 90,
            child : Stack(
              alignment: Alignment.center,
              children : [
                CircularProgressIndicator(
                  value          : (persentase / 100).clamp(0.0, 1.0),
                  strokeWidth    : 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor     : AlwaysStoppedAnimation(_warnaRing),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    Text('${persentase.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: _warnaRing, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('Hadir',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                const Text('Kehadiran Semester Ini',
                  style: TextStyle(
                    color: _kNavy, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.check_circle_outline, color: _kAccent, size: 16),
                  const SizedBox(width: 6),
                  Text('Hadir Efektif  ',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('$totalHadir sesi',
                    style: const TextStyle(
                      color: _kNavy, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event_note_outlined, color: _kNavyLight, size: 16),
                  const SizedBox(width: 6),
                  Text('Total Sesi  ',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('$totalSesi sesi',
                    style: const TextStyle(
                      color: _kNavy, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                if (persentase < 75) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding    : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration : BoxDecoration(
                      color      : _kWarning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        Icon(Icons.warning_amber_rounded, color: _kWarning, size: 14),
                        const SizedBox(width: 4),
                        Text('Kehadiran di bawah 75%',
                          style: TextStyle(
                            color: _kWarning, fontSize: 11, fontWeight: FontWeight.w600)),
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

class _JadwalCard extends StatelessWidget {
  final JadwalModel  jadwal;
  final VoidCallback onScan;

  const _JadwalCard({required this.jadwal, required this.onScan});

  Color _statusColor() {
    switch (jadwal.statusPresensi) {
      case 'hadir'    : return _kAccent;
      case 'terlambat': return _kWarning;
      case 'absen'    : return _kDanger;
      default         : return jadwal.adaSesiAktif ? _kNavy : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color      : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border     : jadwal.adaSesiAktif && !jadwal.sudahPresensi
            ? Border.all(color: _kNavy.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow  : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width      : 4,
              height     : 52,
              decoration : BoxDecoration(
                color      : color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jadwal.nama,
                    style: const TextStyle(
                      color: _kNavy, fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(jadwal.labelJam,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (jadwal.ruangan != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.room_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(jadwal.ruangan!,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (jadwal.adaSesiAktif && !jadwal.sudahPresensi)
              GestureDetector(
                onTap : onScan,
                child : Container(
                  padding    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration : BoxDecoration(
                    color      : _kNavy, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Presensi',
                    style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            else
              Container(
                padding    : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration : BoxDecoration(
                  color      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(jadwal.labelStatus,
                  style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children         : [
      Text(title,
        style: const TextStyle(
          color: _kNavy, fontSize: 15, fontWeight: FontWeight.bold)),
      Text(subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );
}

class _EmptyJadwal extends StatelessWidget {
  const _EmptyJadwal();
  @override
  Widget build(BuildContext context) => Container(
    padding    : const EdgeInsets.all(24),
    decoration : BoxDecoration(
      color      : Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(
      children: [
        Icon(Icons.event_available_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Tidak ada jadwal hari ini',
          style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children         : [
        CircularProgressIndicator(color: _kNavy),
        SizedBox(height: 16),
        Text('Memuat data...', style: TextStyle(color: Colors.grey)),
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
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Gagal memuat data',
              style: TextStyle(
                color: _kNavy, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon : const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}