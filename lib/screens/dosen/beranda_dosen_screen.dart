// lib/screens/dosen/beranda_dosen_screen.dart
// Fase 5 UPDATE: onTap card matakuliah sekarang navigasi ke DetailMatakuliahScreen

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/providers/auth_provider.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFF2A5298);
const _kAccent    = Color(0xFF00BFA5);
const _kWarning   = Color(0xFFFFA726);
const _kDanger    = Color(0xFFEF5350);
const _kBgLight   = Color(0xFFF5F7FA);
const _kPurple    = Color(0xFF7C3AED);

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
  });

  factory JadwalHariIniItem.fromJson(Map<String, dynamic> j) =>
      JadwalHariIniItem(
        matakuliahId      : j['matakuliah_id']          as String,
        kode              : j['kode']                   as String,
        nama              : j['nama']                   as String,
        sks               : j['sks']                    as int,
        hari              : j['hari']                   as String?,
        jamMulai          : j['jam_mulai']              as String?,
        jamSelesai        : j['jam_selesai']            as String?,
        ruangan           : j['ruangan']                as String?,
        izinTamu          : j['izin_tamu']              as bool?   ?? false,
        jumlahMahasiswa   : j['jumlah_mahasiswa']       as int?    ?? 0,
        statusSesi        : j['status_sesi']            as String? ?? 'belum_mulai',
        sesiId            : j['sesi_id']                as String?,
        pertemuanKe       : j['pertemuan_ke']           as int?,
        kodeSesi          : j['kode_sesi']              as String?,
        detikTersisa      : j['detik_tersisa']          as int?,
        adaJadwalPengganti: j['ada_jadwal_pengganti']   as bool?   ?? false,
        jamMulaiPengganti : j['jam_mulai_pengganti']    as String?,
        jamSelesaiPengganti:j['jam_selesai_pengganti']  as String?,
        ruanganPengganti  : j['ruangan_pengganti']      as String?,
      );

  String get labelJam {
    final mulai   = (adaJadwalPengganti && jamMulaiPengganti != null)
        ? jamMulaiPengganti!
        : (jamMulai ?? '-');
    final selesai = (adaJadwalPengganti && jamSelesaiPengganti != null)
        ? jamSelesaiPengganti!
        : (jamSelesai ?? '-');
    return '$mulai – $selesai';
  }

  String get labelRuangan =>
      (adaJadwalPengganti && ruanganPengganti != null)
          ? ruanganPengganti!
          : (ruangan ?? '-');
}

class MatakuliahRingkasan {
  final String  matakuliahId;
  final String  kode;
  final String  nama;
  final int     sks;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final int     jumlahMahasiswa;
  final bool    adaSesiAktif;
  final String? sesiId;

  const MatakuliahRingkasan({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    required this.jumlahMahasiswa,
    required this.adaSesiAktif,
    this.sesiId,
  });

  factory MatakuliahRingkasan.fromJson(Map<String, dynamic> j) =>
      MatakuliahRingkasan(
        matakuliahId   : j['matakuliah_id']    as String,
        kode           : j['kode']             as String,
        nama           : j['nama']             as String,
        sks            : j['sks']              as int,
        hari           : j['hari']             as String?,
        jamMulai       : j['jam_mulai']        as String?,
        jamSelesai     : j['jam_selesai']      as String?,
        ruangan        : j['ruangan']          as String?,
        jumlahMahasiswa: j['jumlah_mahasiswa'] as int?    ?? 0,
        adaSesiAktif   : j['ada_sesi_aktif']   as bool?   ?? false,
        sesiId         : j['sesi_id']          as String?,
      );
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

  String  _namaDosen       = '';
  String  _nidn            = '';
  String  _hariIni         = '';
  bool    _isLoading       = true;
  String? _error;
  bool    _isFetching      = false;

  List<JadwalHariIniItem>   _jadwalHariIni    = [];
  List<MatakuliahRingkasan> _semuaMatakuliah  = [];

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
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final jadwal = (data['jadwal_hari_ini'] as List<dynamic>? ?? [])
          .map((e) => JadwalHariIniItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final semua = (data['semua_matakuliah'] as List<dynamic>? ?? [])
          .map((e) => MatakuliahRingkasan.fromJson(e as Map<String, dynamic>))
          .toList();

      final adaAktif = jadwal.any((j) => j.statusSesi == 'aktif') ||
          semua.any((mk) => mk.adaSesiAktif);
      widget.onSesiAktifChanged?.call(adaAktif);

      final newMap = <String, int>{};
      for (final j in jadwal) {
        if (j.sesiId != null &&
            j.detikTersisa != null &&
            j.statusSesi == 'aktif') {
          newMap[j.sesiId!] = j.detikTersisa!;
        }
      }

      if (mounted) {
        setState(() {
          _namaDosen       = data['nama_dosen'] as String? ?? '';
          _nidn            = data['nidn']       as String? ?? '';
          _hariIni         = data['hari_ini']   as String? ?? '';
          _jadwalHariIni   = jadwal;
          _semuaMatakuliah = semua;
          _isLoading       = false;
          _countdownMap
            ..clear()
            ..addAll(newMap);
        });
        _startCountdown();
      }

    } on ApiException catch (e) {
      if (mounted) {
        setState(() { _error = e.message; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
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
          if (_countdownMap[key]! > 0) {
            _countdownMap[key] = _countdownMap[key]! - 1;
          }
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
          final mode   = sesiData['mode'] as String? ?? '';
          final sesiId = sesiData['id']   as String?;

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
      backgroundColor: _kBgLight,
      body: RefreshIndicator(
        onRefresh: _fetchBeranda,
        color    : _kNavy,
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
        SliverAppBar(
          expandedHeight: 150,
          pinned        : true,
          backgroundColor: _kNavy,
          automaticallyImplyLeading: false,
          elevation     : 0,
          flexibleSpace : FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin : Alignment.topLeft,
                  end   : Alignment.bottomRight,
                  colors: [_kNavy, _kNavyLight],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 60, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment : MainAxisAlignment.center,
                          children: [
                            Text(_getSapaan(),
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(namaDepan,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 22,
                                fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(_nidn,
                              style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius         : 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child          : Text(
                          namaDepan.isNotEmpty
                              ? namaDepan[0].toUpperCase() : 'D',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold)),
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
          actions: [
            IconButton(
              icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchBeranda,
              tooltip  : 'Refresh',
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Container(
            color  : _kNavy,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child  : Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                  color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver : SliverList(
            delegate: SliverChildListDelegate([

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
                  // ── BARU Fase 5: navigasi ke detail matakuliah ──
                  onDetailMatakuliah: () =>
                      context.go('/dosen/matakuliah/${j.matakuliahId}'),
                )),

              const SizedBox(height: 24),

              _SectionHeader(
                title   : '📚 Semua Matakuliah',
                subtitle: '${_semuaMatakuliah.length} matakuliah',
              ),
              const SizedBox(height: 10),

              if (_semuaMatakuliah.isEmpty)
                const _EmptyCard(
                  icon : Icons.school_outlined,
                  pesan: 'Belum ada matakuliah',
                  sub  : 'Hubungi admin untuk menambahkan matakuliah',
                )
              else
                ..._semuaMatakuliah.map((mk) => _MatakuliahCard(
                  mk        : mk,
                  // ── BARU Fase 5: navigasi ke detail matakuliah ──
                  onTap     : () =>
                      context.go('/dosen/matakuliah/${mk.matakuliahId}'),
                  onSesiAktif: () =>
                      widget.onGoToMonitor?.call(mk.sesiId),
                )),
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

// ─── Section header ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title,
        style: const TextStyle(
          color: _kNavy, fontSize: 15,
          fontWeight: FontWeight.bold)),
      const Spacer(),
      Text(subtitle,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
    ],
  );
}

// ─── Card jadwal hari ini ─────────────────────────────────────

class _JadwalCard extends StatelessWidget {
  final JadwalHariIniItem    jadwal;
  final int?                 countdownDetik;
  final String Function(int) formatCountdown;
  final VoidCallback onBukaSesi;
  final VoidCallback onMonitor;
  final VoidCallback onRekap;
  final VoidCallback onTampilKode;
  final VoidCallback onDetailMatakuliah; // ← BARU Fase 5

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
      case 'aktif'  : return _kAccent;
      case 'selesai': return Colors.grey.shade400;
      default       : return _kNavy;
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
            ? Border.all(color: _kAccent.withOpacity(0.4), width: 1.5)
            : isSelesai
                ? Border.all(color: Colors.grey.shade200)
                : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset    : const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header — tap untuk ke detail matakuliah
          InkWell(
            onTap       : onDetailMatakuliah,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4, height: 60,
                    decoration: BoxDecoration(
                      color       : _statusColor,
                      borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kNavy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6)),
                              child: Text(jadwal.kode,
                                style: const TextStyle(
                                  color: _kNavy, fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Text('${jadwal.sks} SKS',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11)),
                            const Spacer(),
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
                                    style: TextStyle(
                                      color: _statusColor, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(jadwal.nama,
                                style: const TextStyle(
                                  color: _kNavy, fontSize: 15,
                                  fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            ),
                            // Ikon detail → ke halaman detail matakuliah
                            Icon(Icons.info_outline_rounded,
                              size : 16,
                              color: Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(jadwal.labelJam,
                              style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(width: 10),
                            Icon(Icons.room_outlined,
                              size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(jadwal.labelRuangan,
                                style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (jadwal.pertemuanKe != null)
                  _InfoChip(
                    label: 'Pertemuan ${jadwal.pertemuanKe}',
                    color: Colors.blue.shade700,
                    bg   : Colors.blue.shade50,
                  ),
                if (jadwal.pertemuanKe != null)
                  const SizedBox(width: 6),
                if (jadwal.adaJadwalPengganti)
                  _InfoChip(
                    label: '⟳ Jadwal Pengganti',
                    color: _kWarning,
                    bg   : _kWarning.withOpacity(0.1),
                  ),
                const Spacer(),
                Icon(Icons.people_outline_rounded,
                  size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('${jadwal.jumlahMahasiswa} mhs',
                  style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
                if (jadwal.izinTamu) ...[
                  const SizedBox(width: 6),
                  _InfoChip(
                    label: 'Tamu OK',
                    color: _kAccent,
                    bg   : _kAccent.withOpacity(0.1),
                  ),
                ],
              ],
            ),
          ),

          if (isAktif &&
              jadwal.kodeSesi != null &&
              countdownDetik != null)
            Container(
              margin   : const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding  : const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color  : _kNavy.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border : Border.all(
                  color: _kNavy.withOpacity(0.1))),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded,
                    size: 16, color: _kNavy),
                  const SizedBox(width: 8),
                  Text('Kode: ',
                    style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
                  Text(jadwal.kodeSesi!,
                    style: const TextStyle(
                      color: _kNavy, fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3)),
                  const Spacer(),
                  Icon(Icons.timer_outlined,
                    size : 14,
                    color: countdownDetik! < 300 ? _kDanger : _kAccent),
                  const SizedBox(width: 4),
                  Text(
                    formatCountdown(countdownDetik!),
                    style: TextStyle(
                      color: countdownDetik! < 300 ? _kDanger : _kAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const Divider(height: 1),

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
              color    : _kNavy,
              filled   : true,
              onPressed: onMonitor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: jadwal.kodeSesi != null
                ? _ActionBtn(
                    label    : 'Kode',
                    icon     : Icons.vpn_key_rounded,
                    color    : _kPurple,
                    filled   : false,
                    onPressed: onTampilKode,
                  )
                : _ActionBtn(
                    label    : 'Rekap',
                    icon     : Icons.summarize_rounded,
                    color    : _kNavy,
                    filled   : false,
                    onPressed: onRekap,
                  ),
          ),
        ],
      );
    }

    if (jadwal.statusSesi == 'selesai') {
      return Row(
        children: [
          Expanded(
            child: _ActionBtn(
              label    : 'Lihat Rekap',
              icon     : Icons.summarize_rounded,
              color    : Colors.blue.shade700,
              filled   : true,
              onPressed: onRekap,
            ),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label    : 'Detail',
            icon     : Icons.school_outlined,
            color    : _kNavy,
            filled   : false,
            onPressed: onDetailMatakuliah,
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
            color    : _kNavy,
            filled   : true,
            onPressed: onBukaSesi,
          ),
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          label    : 'Detail',
          icon     : Icons.school_outlined,
          color    : _kNavy,
          filled   : false,
          onPressed: onDetailMatakuliah,
        ),
      ],
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────

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
      style: TextStyle(
        color: color, fontSize: 11,
        fontWeight: FontWeight.w600)),
  );
}

// ─── Action button ────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon : Icon(icon, size: 16),
        label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon : Icon(icon, size: 16),
      label: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Card matakuliah (tap → detail) ──────────────────────────

class _MatakuliahCard extends StatelessWidget {
  final MatakuliahRingkasan mk;
  final VoidCallback        onTap;        // ← sekarang ke detail matakuliah
  final VoidCallback        onSesiAktif;

  const _MatakuliahCard({
    required this.mk,
    required this.onTap,
    required this.onSesiAktif,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin    : const EdgeInsets.only(bottom: 8),
    elevation : 1,
    shape     : RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12)),
    child     : InkWell(
      onTap       : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width : 44, height: 44,
              decoration: BoxDecoration(
                color: _kNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                  mk.hari?.substring(0, 3) ?? '?',
                  style: const TextStyle(
                    color: _kNavy, fontSize: 12,
                    fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mk.nama,
                    style: const TextStyle(
                      color: _kNavy, fontSize: 14,
                      fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${mk.kode}  ·  '
                    '${mk.jamMulai ?? '-'} – ${mk.jamSelesai ?? '-'}'
                    '${mk.ruangan != null ? "  ·  ${mk.ruangan}" : ""}',
                    style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${mk.jumlahMahasiswa} mahasiswa',
                    style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            if (mk.adaSesiAktif)
              GestureDetector(
                onTap: onSesiAktif,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color : _kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _kAccent.withOpacity(0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseDot(color: _kAccent),
                      const SizedBox(width: 5),
                      const Text('Live',
                        style: TextStyle(
                          color: _kAccent, fontSize: 11,
                          fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            else
              // Ikon panah → memberi sinyal "bisa tap ke detail"
              Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    ),
  );
}

// ─── Bottom sheet buka sesi ───────────────────────────────────

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

  final List<int?> _opsiTerlambat = [null, 0, 10, 15, 30];
  final List<int>  _opsiDurasi    = [15, 30, 60, 90];

  String _labelTerlambat(int? val) {
    if (val == null) return 'Tidak ada batas';
    if (val == 0)   return 'Langsung';
    return '$val mnt';
  }

  Future<void> _bukaSesi() async {
    final pertemuanKe = widget.jadwal.pertemuanKe;
    if (pertemuanKe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content : Text('Tidak dapat menentukan nomor pertemuan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (_mode == 'online') body['durasi_menit'] = _durasiKode;

      final response = await ApiClient().post('/sesi/buka', body: body);
      final data     = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      widget.onBerhasil(data);

    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content        : Text(e.message),
          backgroundColor: _kDanger,
          behavior       : SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content        : Text('Gagal buka sesi: $e'),
          backgroundColor: _kDanger,
          behavior       : SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
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
              style: const TextStyle(
                color: _kNavy, fontSize: 18,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${widget.jadwal.nama}  ·  ${widget.jadwal.kode}',
              style: TextStyle(
                color: Colors.grey.shade500, fontSize: 13)),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            _SheetInfoRow(
              label: 'Pertemuan ke',
              value: widget.jadwal.pertemuanKe != null
                  ? '${widget.jadwal.pertemuanKe}'
                  : 'Tidak tersedia',
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Waktu Mulai',
                        style: TextStyle(
                          color: _kNavy, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      Text(
                        _mulaiDariJadwal
                            ? 'Dari jam jadwal '
                              '(${widget.jadwal.jamMulai ?? "-"})'
                            : 'Dari sekarang',
                        style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value    : _mulaiDariJadwal,
                  onChanged: (v) =>
                      setState(() => _mulaiDariJadwal = v),
                  activeColor: _kNavy,
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Mode Kelas',
              style: TextStyle(
                color: _kNavy, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetModeChip(
                    label   : '📍 Tatap Muka',
                    selected: _mode == 'offline',
                    color   : _kNavy,
                    onTap   : () => setState(() => _mode = 'offline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetModeChip(
                    label   : '💻 Online',
                    selected: _mode == 'online',
                    color   : _kPurple,
                    onTap   : () => setState(() => _mode = 'online'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Toleransi Terlambat',
              style: TextStyle(
                color: _kNavy, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: _opsiTerlambat.map((v) => ChoiceChip(
                label    : Text(_labelTerlambat(v),
                  style: const TextStyle(fontSize: 12)),
                selected : _batasTerlambat == v,
                onSelected: (_) =>
                    setState(() => _batasTerlambat = v),
                selectedColor: _kNavy,
                labelStyle: TextStyle(
                  color: _batasTerlambat == v
                      ? Colors.white : Colors.black87),
              )).toList(),
            ),
            const SizedBox(height: 16),

            if (_mode == 'online') ...[
              const Text('Durasi Kode Aktif',
                style: TextStyle(
                  color: _kNavy, fontSize: 13,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: _opsiDurasi.map((v) => ChoiceChip(
                  label    : Text('$v mnt',
                    style: const TextStyle(fontSize: 12)),
                  selected : _durasiKode == v,
                  onSelected: (_) =>
                      setState(() => _durasiKode = v),
                  selectedColor: _kPurple,
                  labelStyle: TextStyle(
                    color: _durasiKode == v
                        ? Colors.white : Colors.black87),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              height: 52,
              child : ElevatedButton.icon(
                onPressed: (_isLoading ||
                    widget.jadwal.pertemuanKe == null)
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
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _mode == 'online' ? _kPurple : _kNavy,
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

// ─── Sheet helpers ────────────────────────────────────────────

class _SheetInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      Text(value,
        style: const TextStyle(
          color: _kNavy, fontSize: 13,
          fontWeight: FontWeight.w600)),
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
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontSize: 13, fontWeight: FontWeight.bold)),
    ),
  );
}

// ─── Pulse dot ────────────────────────────────────────────────

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
      vsync   : this,
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
      width : 7, height: 7,
      decoration: BoxDecoration(
        color: widget.color, shape: BoxShape.circle)),
  );
}

// ─── Empty card ───────────────────────────────────────────────

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
          style: const TextStyle(
            color: _kNavy, fontSize: 14,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400, fontSize: 12)),
      ],
    ),
  );
}

// ─── Loading & Error ──────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: _kNavy),
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
          const Text('Gagal memuat beranda',
            style: TextStyle(
              color: _kNavy, fontSize: 16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon : const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white),
          ),
        ],
      ),
    ),
  );
}