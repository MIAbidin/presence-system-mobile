// lib/screens/home_screen.dart
// Halaman beranda mahasiswa — menampilkan ringkasan kehadiran,
// banner sesi aktif, dan jadwal hari ini.
// Memanggil endpoint: GET /mahasiswa/home-summary

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

// ─── Konstanta warna tema ─────────────────────────────────────
const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFF2A5298);
const _kAccent    = Color(0xFF00BFA5);
const _kWarning   = Color(0xFFFFA726);
const _kDanger    = Color(0xFFEF5350);
const _kBgLight   = Color(0xFFF5F7FA);

// ─── Model HomeSummary (response GET /mahasiswa/home-summary) ─

class HomeSummaryModel {
  final String         namaMahasiswa;
  final String         nim;
  final String         programStudi;
  final double         persentaseKeseluruhan; // 0.0 – 100.0
  final int            totalHadir;
  final int            totalSesi;
  final List<StatMatakuliah> statPerMk;
  final List<JadwalModel>    jadwalHariIni;
  final SesiAktifInfo?       sesiAktif; // null jika tidak ada

  const HomeSummaryModel({
    required this.namaMahasiswa,
    required this.nim,
    required this.programStudi,
    required this.persentaseKeseluruhan,
    required this.totalHadir,
    required this.totalSesi,
    required this.statPerMk,
    required this.jadwalHariIni,
    this.sesiAktif,
  });

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeSummaryModel(
      namaMahasiswa : json['nama_mahasiswa'] ?? '',
      nim           : json['nim'] ?? '',
      programStudi  : json['program_studi'] ?? '',
      persentaseKeseluruhan :
          (json['persentase_keseluruhan'] ?? 0).toDouble(),
      totalHadir : json['total_hadir'] ?? 0,
      totalSesi  : json['total_sesi'] ?? 0,
      statPerMk : (json['stat_per_mk'] as List<dynamic>? ?? [])
        .map((e) => StatMatakuliah.fromJson(e as Map<String, dynamic>))
        .toList(),
      jadwalHariIni : (json['jadwal_hari_ini'] as List<dynamic>? ?? [])
        .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
        .toList(),
      sesiAktif             : json['sesi_aktif'] != null
          ? SesiAktifInfo.fromJson(json['sesi_aktif'] as Map<String, dynamic>)
          : null,
    );
  }
}

class StatMatakuliah {
  final String matakuliahId;
  final String kode;
  final String nama;
  final double persentase;
  final int    hadir;
  final int    total;

  const StatMatakuliah({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.persentase,
    required this.hadir,
    required this.total,
  });

  factory StatMatakuliah.fromJson(Map<String, dynamic> json) => StatMatakuliah(
    matakuliahId: json['matakuliah_id'] ?? '',
    kode        : json['kode'] ?? '',
    nama        : json['nama'] ?? '',
    persentase  : (json['persentase'] ?? 0).toDouble(),
    hadir       : json['hadir'] ?? 0,
    total       : json['total'] ?? 0,
  );
}

class SesiAktifInfo {
  final String sesiId;
  final String matakuliahNama;
  final String mode;          // 'offline' | 'online'
  final String? ruangan;
  final DateTime waktuBuka;
  final DateTime? kodeExpireAt;

  const SesiAktifInfo({
    required this.sesiId,
    required this.matakuliahNama,
    required this.mode,
    this.ruangan,
    required this.waktuBuka,
    this.kodeExpireAt,
  });

  factory SesiAktifInfo.fromJson(Map<String, dynamic> json) => SesiAktifInfo(
    sesiId          : json['sesi_id']           as String,
    matakuliahNama  : json['matakuliah_nama']    as String,
    mode            : json['mode']               as String,
    ruangan         : json['ruangan']            as String?,
    waktuBuka       : DateTime.parse(json['waktu_buka'] as String),
    kodeExpireAt    : json['kode_expire_at'] != null
        ? DateTime.parse(json['kode_expire_at'] as String)
        : null,
  );

  bool get isOnline => mode == 'online';
}

// ─── HomeScreen ───────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  // AutomaticKeepAliveClientMixin: state tidak di-reset saat berpindah tab

  HomeSummaryModel? _summary;
  bool   _isLoading = true;
  String? _error;

  // Timer untuk sisa waktu sesi aktif
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

  // ── Fetch data dari API ──────────────────────────────────────

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final client = context.read<ApiClient>();
      final response = await client.get('/mahasiswa/home-summary');

      final Map<String, dynamic> json =
          jsonDecode(response.body);

      final summary = HomeSummaryModel.fromJson(json);

      if (!mounted) return;
      setState(() {
        _summary   = summary;
        _isLoading = false;
      });

      // Mulai countdown jika ada sesi aktif online dengan expire
      if (summary.sesiAktif?.kodeExpireAt != null) {
        _startCountdown(summary.sesiAktif!.kodeExpireAt!);
      }
    } catch (e) {
      print("ERROR HOME: $e");
      if (!mounted) return;
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startCountdown(DateTime expireAt) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sisa = expireAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _sisaWaktu = sisa.isNegative ? Duration.zero : sisa;
      });
      if (sisa.isNegative) {
        _countdownTimer?.cancel();
        _fetchSummary(); // refresh setelah sesi expired
      }
    });
  }

  // ── Navigate ke tab Scan ────────────────────────────────────

  void _goToScan() {
    context.go('/scan');
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

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
        // ── App bar dengan sapaan ──────────────────────────────
        _buildSliverAppBar(s),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver : SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // ── Banner sesi aktif (jika ada) ─────────────────
              if (s.sesiAktif != null) ...[
                _SesiAktifBanner(
                  sesi      : s.sesiAktif!,
                  sisaWaktu : _sisaWaktu,
                  onPresensi: _goToScan,
                ),
                const SizedBox(height: 20),
              ],

              // ── Kartu statistik utama ─────────────────────────
              _StatUtamaCard(
                persentase : s.persentaseKeseluruhan,
                totalHadir : s.totalHadir,
                totalSesi  : s.totalSesi,
              ),
              const SizedBox(height: 20),

              // ── Statistik per matakuliah ─────────────────────
              if (s.statPerMk.isNotEmpty) ...[
                _SectionHeader(
                  title   : 'Kehadiran per Matakuliah',
                  subtitle: 'Semester ini',
                ),
                const SizedBox(height: 12),
                ...s.statPerMk.map((mk) => _MkStatCard(stat: mk)),
                const SizedBox(height: 20),
              ],

              // ── Jadwal hari ini ──────────────────────────────
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
                  jadwal  : j,
                  onScan  : _goToScan,
                )),
            ]),
          ),
        ),
      ],
    );
  }

  // ── SliverAppBar dengan gradient ──────────────────────────────

  Widget _buildSliverAppBar(HomeSummaryModel s) {
    final namaDepan = s.namaMahasiswa.split(' ').first;
    final jamSekarang = DateTime.now().hour;
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
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sapaan,
                              style: const TextStyle(
                                color   : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              namaDepan,
                              style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 22,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.nim}  ·  ${s.programStudi}',
                              style: const TextStyle(
                                color   : Colors.white60,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Avatar inisial
                      CircleAvatar(
                        radius         : 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child          : Text(
                          s.namaMahasiswa.isNotEmpty
                              ? s.namaMahasiswa[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color     : Colors.white,
                            fontSize  : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Saat di-collapse, tampilkan judul singkat
      title: const Text(
        'Beranda',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      titleSpacing: 20,
    );
  }
}

// ─── Sub-widget: Banner sesi aktif ────────────────────────────

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
          colors: [Color(0xFF00897B), _kAccent],
        ),
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
            // Header
            Row(
              children: [
                Container(
                  padding     : const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration  : BoxDecoration(
                    color       : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children    : [
                      const Icon(Icons.circle,
                          color: Colors.white, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        'SESI ${sesi.isOnline ? 'ONLINE' : 'OFFLINE'} AKTIF',
                        style: const TextStyle(
                          color     : Colors.white,
                          fontSize  : 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nama matakuliah
            Text(
              sesi.matakuliahNama,
              style: const TextStyle(
                color     : Colors.white,
                fontSize  : 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sesi.ruangan != null)
              Text(
                sesi.ruangan!,
                style: const TextStyle(
                  color  : Colors.white70,
                  fontSize: 13,
                ),
              ),

            const SizedBox(height: 12),

            // Countdown + tombol
            Row(
              children: [
                if (sisaWaktu != null) ...[
                  const Icon(Icons.timer_outlined,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Sisa ${_formatDurasi(sisaWaktu!)}',
                    style: const TextStyle(
                      color  : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    padding        : const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape          : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize  : 13,
                    ),
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

// ─── Sub-widget: Kartu statistik utama ────────────────────────

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
      padding     : const EdgeInsets.all(20),
      decoration  : BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow   : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset    : const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Lingkaran progres
          SizedBox(
            width : 90,
            height: 90,
            child : Stack(
              alignment: Alignment.center,
              children : [
                CircularProgressIndicator(
                  value          : persentase / 100,
                  strokeWidth    : 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor     : AlwaysStoppedAnimation(_warnaRing),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children    : [
                    Text(
                      '${persentase.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color     : _warnaRing,
                        fontSize  : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Hadir',
                      style: TextStyle(
                        color   : Colors.grey,
                        fontSize: 11,
                      ),
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
              children          : [
                const Text(
                  'Kehadiran Semester Ini',
                  style: TextStyle(
                    color     : _kNavy,
                    fontSize  : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _StatRow(
                  icon : Icons.check_circle_outline,
                  color: _kAccent,
                  label: 'Total Hadir',
                  nilai: '$totalHadir Pertemuan',
                ),
                const SizedBox(height: 6),
                _StatRow(
                  icon : Icons.event_note_outlined,
                  color: _kNavyLight,
                  label: 'Total Sesi',
                  nilai: '$totalSesi Pertemuan',
                ),
                if (persentase < 75) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding     : const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration  : BoxDecoration(
                      color       : _kWarning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        Icon(Icons.warning_amber_rounded,
                            color: _kWarning, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Kehadiran di bawah 75%',
                          style: TextStyle(
                            color   : _kWarning,
                            fontSize: 11,
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
  final String   nilai;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.nilai,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(width: 4),
      Text(
        nilai,
        style: const TextStyle(
          color     : _kNavy,
          fontSize  : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ─── Sub-widget: Kartu statistik per matakuliah ───────────────

class _MkStatCard extends StatelessWidget {
  final StatMatakuliah stat;

  const _MkStatCard({required this.stat});

  Color get _barColor {
    if (stat.persentase >= 75) return _kAccent;
    if (stat.persentase >= 60) return _kWarning;
    return _kDanger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin     : const EdgeInsets.only(bottom: 10),
      padding    : const EdgeInsets.all(14),
      decoration : BoxDecoration(
        color      : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow  : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children          : [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children          : [
                    Text(
                      stat.nama,
                      style: const TextStyle(
                        color     : _kNavy,
                        fontSize  : 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines : 1,
                      overflow : TextOverflow.ellipsis,
                    ),
                    Text(
                      stat.kode,
                      style: const TextStyle(
                        color  : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${stat.hadir}/${stat.total}',
                style: TextStyle(
                  color     : _barColor,
                  fontSize  : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child       : LinearProgressIndicator(
              value          : stat.persentase / 100,
              minHeight      : 6,
              backgroundColor: Colors.grey.shade100,
              valueColor     : AlwaysStoppedAnimation(_barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stat.persentase.toStringAsFixed(1)}% kehadiran',
            style: TextStyle(
              color  : _barColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widget: Kartu jadwal hari ini ────────────────────────

class _JadwalCard extends StatelessWidget {
  final JadwalModel jadwal;
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
      margin     : const EdgeInsets.only(bottom: 10),
      decoration : BoxDecoration(
        color      : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border     : jadwal.adaSesiAktif && !jadwal.sudahPresensi
            ? Border.all(color: _kNavy.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow  : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child  : Row(
          children: [
            // Garis kiri berwarna
            Container(
              width       : 4,
              height      : 52,
              decoration  : BoxDecoration(
                color       : color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Info jadwal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children          : [
                  Text(
                    jadwal.nama,
                    style: const TextStyle(
                      color     : _kNavy,
                      fontSize  : 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        jadwal.labelJam,
                        style: const TextStyle(
                          color  : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (jadwal.ruangan != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.room_outlined,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            jadwal.ruangan!,
                            style: const TextStyle(
                              color  : Colors.grey,
                              fontSize: 12,
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

            // Badge status / tombol presensi
            if (jadwal.adaSesiAktif && !jadwal.sudahPresensi)
              GestureDetector(
                onTap  : onScan,
                child  : Container(
                  padding     : const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration  : BoxDecoration(
                    color       : _kNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Presensi',
                    style: TextStyle(
                      color     : Colors.white,
                      fontSize  : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding     : const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration  : BoxDecoration(
                  color       : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  jadwal.labelStatus,
                  style: TextStyle(
                    color     : color,
                    fontSize  : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widget: Helpers ──────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children         : [
      Text(
        title,
        style: const TextStyle(
          color     : _kNavy,
          fontSize  : 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        subtitle,
        style: const TextStyle(
          color  : Colors.grey,
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _EmptyJadwal extends StatelessWidget {
  const _EmptyJadwal();

  @override
  Widget build(BuildContext context) => Container(
    padding    : const EdgeInsets.all(24),
    decoration : BoxDecoration(
      color      : Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(Icons.event_available_outlined,
            size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text(
          'Tidak ada jadwal hari ini',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
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
        Text(
          'Memuat data...',
          style: TextStyle(color: Colors.grey),
        ),
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
          mainAxisSize: MainAxisSize.min, // ⬅️ penting
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(
                color: _kNavy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}