// lib/screens/dosen/jadwal_dosen_screen.dart
// FASE 6.2 — BARU
// Screen jadwal mingguan dosen dengan dua tab:
//   Tab 0: Hari Ini   — jadwal mengajar hari ini + status sesi + tombol buka sesi cepat
//   Tab 1: Mingguan   — semua jadwal per hari dalam seminggu
//
// Fitur per kartu MK:
//   - Badge kelas (A/B/C) di samping kode MK
//   - SlotLabel: slot waktu dan jam ("Slot 1–3 | 07:00–09:30")
//   - Ruangan, jumlah mahasiswa
//   - Banner jadwal pengganti kuning (termasuk mode yang diubah)
//   - Status sesi (AKTIF / SELESAI / BELUM MULAI)
//   - Tombol buka sesi langsung dari kartu (belum_mulai)
//   - Tombol Monitor / Rekap (aktif / selesai)
//
// Endpoint: GET /dosen/beranda
// (data jadwal_hari_ini dipakai untuk Tab Hari Ini;
//  semua_jadwal_mingguan untuk Tab Mingguan — field baru dari backend,
//  fallback ke grouping manual jika belum tersedia)
//
// Route: /dosen/jadwal (tab index 1 di bottom nav dosen baru)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/slot_label.dart';

// ─── Model Jadwal Dosen ───────────────────────────────────────
// Dipakai untuk Tab Hari Ini maupun Tab Mingguan

class JadwalDosenItem {
  final String  matakuliahId;
  final String  kode;
  final String  nama;
  final int     sks;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final int     jumlahMahasiswa;
  final String  statusSesi;   // 'aktif' | 'selesai' | 'belum_mulai'
  final String? sesiId;
  final int?    pertemuanKe;
  final String? kodeSesi;
  final int?    detikTersisa;
  // Kelas
  final String? kodeKelas;
  final String? kelasId;
  final int?    slotMulai;
  final int?    slotSelesai;
  // Jadwal pengganti
  final bool    adaJadwalPengganti;
  final String? jamMulaiPengganti;
  final String? jamSelesaiPengganti;
  final String? ruanganPengganti;
  final String? modePengganti;   // 'offline' | 'online' — [BARU Fase 6.2]
  // Izin tamu
  final bool    izinTamu;
  // Multi-kelas (untuk bottom sheet buka sesi)
  final List<Map<String, dynamic>> kelasList;

  const JadwalDosenItem({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    required this.jumlahMahasiswa,
    required this.statusSesi,
    this.sesiId,
    this.pertemuanKe,
    this.kodeSesi,
    this.detikTersisa,
    this.kodeKelas,
    this.kelasId,
    this.slotMulai,
    this.slotSelesai,
    this.adaJadwalPengganti  = false,
    this.jamMulaiPengganti,
    this.jamSelesaiPengganti,
    this.ruanganPengganti,
    this.modePengganti,
    this.izinTamu            = false,
    this.kelasList           = const [],
  });

  factory JadwalDosenItem.fromJson(Map<String, dynamic> j) =>
      JadwalDosenItem(
        matakuliahId       : j['matakuliah_id']          as String,
        kode               : j['kode']                   as String,
        nama               : j['nama']                   as String,
        sks                : j['sks']                    as int,
        hari               : j['hari']                   as String?,
        jamMulai           : j['jam_mulai']              as String?,
        jamSelesai         : j['jam_selesai']            as String?,
        ruangan            : j['ruangan']                as String?,
        jumlahMahasiswa    : j['jumlah_mahasiswa']       as int?    ?? 0,
        statusSesi         : j['status_sesi']            as String? ?? 'belum_mulai',
        sesiId             : j['sesi_id']                as String?,
        pertemuanKe        : j['pertemuan_ke']           as int?,
        kodeSesi           : j['kode_sesi']              as String?,
        detikTersisa       : j['detik_tersisa']          as int?,
        kodeKelas          : j['kode_kelas']             as String?,
        kelasId            : j['kelas_id']              as String?,
        slotMulai          : j['slot_mulai']             as int?,
        slotSelesai        : j['slot_selesai']           as int?,
        adaJadwalPengganti : j['ada_jadwal_pengganti']   as bool?   ?? false,
        jamMulaiPengganti  : j['jam_mulai_pengganti']    as String?,
        jamSelesaiPengganti: j['jam_selesai_pengganti']  as String?,
        ruanganPengganti   : j['ruangan_pengganti']      as String?,
        modePengganti      : j['mode_pengganti']         as String?,
        izinTamu           : j['izin_tamu']              as bool?   ?? false,
        kelasList          : (j['kelas_list'] as List<dynamic>?)
                                ?.cast<Map<String, dynamic>>() ?? [],
      );

  // Jam efektif (prioritas jadwal pengganti)
  String get labelJam {
    final m = (adaJadwalPengganti && jamMulaiPengganti != null)
        ? jamMulaiPengganti! : (jamMulai   ?? '-');
    final s = (adaJadwalPengganti && jamSelesaiPengganti != null)
        ? jamSelesaiPengganti! : (jamSelesai ?? '-');
    return '$m – $s';
  }

  String get labelRuangan =>
      (adaJadwalPengganti && ruanganPengganti != null)
          ? ruanganPengganti! : (ruangan ?? '-');

  // Mode efektif (dari jadwal pengganti jika ada, else null)
  String? get modeEfektif => adaJadwalPengganti ? modePengganti : null;
}

// ─── Konstanta urutan hari ─────────────────────────────────────
const _urutanHari = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

// ══════════════════════════════════════════════════════════════
// SCREEN UTAMA
// ══════════════════════════════════════════════════════════════

class JadwalDosenScreen extends StatefulWidget {
  /// Callback saat dosen tap "Buka Sesi" atau "Monitor Live" →
  /// parent (MainDosenScreen) akan pindah ke tab Monitor
  final void Function(String? sesiId)? onGoToMonitor;

  const JadwalDosenScreen({super.key, this.onGoToMonitor});

  @override
  State<JadwalDosenScreen> createState() => _JadwalDosenScreenState();
}

class _JadwalDosenScreenState extends State<JadwalDosenScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  // Data
  String  _hariIni      = '';
  bool    _isLoading    = true;
  String? _error;
  bool    _isFetching   = false;

  List<JadwalDosenItem>               _jadwalHariIni  = [];
  Map<String, List<JadwalDosenItem>>  _jadwalMingguan = {};

  // Countdown map: sesiId → detik tersisa
  Timer?               _countdownTimer;
  final Map<String, int> _countdownMap = {};

  // Mingguan: hari yang di-expand (accordion)
  final Set<String> _expandedHari = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hariIni = _namaHariDariDate(DateTime.now());
    _expandedHari.add(_hariIni); // auto-expand hari ini
    _fetchJadwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> _fetchJadwal() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient().get('/dosen/beranda');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;

      // Tab Hari Ini — dari jadwal_hari_ini
      final hariIniList = (data['jadwal_hari_ini'] as List<dynamic>? ?? [])
          .map((e) => JadwalDosenItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Tab Mingguan — dari jadwal_mingguan (field baru)
      // Fallback: gunakan semua_matakuliah atau kelompokkan manual
      final Map<String, List<JadwalDosenItem>> mingguanMap = {};

      if (data.containsKey('jadwal_mingguan')) {
        // Backend sudah sediakan jadwal_mingguan per hari
        final raw = data['jadwal_mingguan'] as Map<String, dynamic>;
        for (final entry in raw.entries) {
          final list = (entry.value as List<dynamic>)
              .map((e) => JadwalDosenItem.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) mingguanMap[entry.key] = list;
        }
      } else {
        // Fallback: gunakan semua_matakuliah dan kelompokkan per hari
        final semuaMk = (data['semua_matakuliah'] as List<dynamic>? ?? []);
        for (final e in semuaMk) {
          final item = JadwalDosenItem.fromJson(
              e as Map<String, dynamic>);
          final hari = item.hari ?? 'Lainnya';
          mingguanMap.putIfAbsent(hari, () => []).add(item);
        }
        // Pastikan jadwal hari ini juga masuk ke mingguan
        for (final j in hariIniList) {
          final hari = j.hari ?? _hariIni;
          final exists = mingguanMap[hari]
              ?.any((x) => x.matakuliahId == j.matakuliahId) ?? false;
          if (!exists) {
            mingguanMap.putIfAbsent(hari, () => []).add(j);
          }
        }
      }

      // Countdown map
      final newMap = <String, int>{};
      for (final j in hariIniList) {
        if (j.sesiId != null && j.detikTersisa != null &&
            j.statusSesi == 'aktif') {
          newMap[j.sesiId!] = j.detikTersisa!;
        }
      }

      if (mounted) {
        setState(() {
          _jadwalHariIni  = hariIniList;
          _jadwalMingguan = mingguanMap;
          _isLoading      = false;
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
        for (final k in _countdownMap.keys.toList()) {
          if (_countdownMap[k]! > 0) _countdownMap[k] = _countdownMap[k]! - 1;
        }
      });
    });
  }

  String _formatCountdown(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _namaHariDariDate(DateTime dt) {
    const map = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
      5: 'Jumat', 6: 'Sabtu',  7: 'Minggu',
    };
    return map[dt.weekday] ?? 'Senin';
  }

  void _showBukaSesiSheet(JadwalDosenItem jadwal) {
    showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => _BukaSesiSheet(
        jadwal    : jadwal,
        onBerhasil: (sesiData) {
          Navigator.pop(ctx);
          _fetchJadwal();
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

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned         : true,
            floating       : false,
            backgroundColor: AppColors.kNavy,
            automaticallyImplyLeading: false,
            elevation      : 0,
            title          : Text('Jadwal Mengajar',
                style: AppTypography.hero.copyWith(fontSize: 18)),
            titleSpacing   : 20,
            actions        : [
              IconButton(
                icon     : const Icon(Icons.refresh_rounded,
                    color: Colors.white),
                onPressed: _fetchJadwal,
                tooltip  : 'Refresh',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48 + 2),
              child: Column(
                children: [
                  TabBar(
                    controller        : _tabController,
                    indicatorColor    : AppColors.kGold,
                    indicatorWeight   : 3,
                    labelColor        : Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle        : AppTypography.button
                        .copyWith(fontSize: 13),
                    unselectedLabelStyle: AppTypography.body2
                        .copyWith(color: Colors.white54, fontSize: 13),
                    tabs              : const [
                      Tab(text: 'Hari Ini'),
                      Tab(text: 'Mingguan'),
                    ],
                  ),
                  Container(height: 2,
                      color: AppColors.kGold.withOpacity(0.4)),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.kNavy))
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _fetchJadwal)
                : TabBarView(
                    controller: _tabController,
                    children  : [
                      _buildTabHariIni(),
                      _buildTabMingguan(),
                    ],
                  ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB HARI INI
  // ══════════════════════════════════════════════════════════

  Widget _buildTabHariIni() {
    if (_jadwalHariIni.isEmpty) {
      return _EmptyState(
        icon    : Icons.event_available_outlined,
        title   : 'Tidak ada jadwal $_hariIni',
        subtitle: 'Nikmati hari tanpa mengajar hari ini 🎉',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchJadwal,
      color    : AppColors.kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount  : _jadwalHariIni.length,
        itemBuilder: (ctx, i) {
          final j = _jadwalHariIni[i];
          return _JadwalCard(
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
            onDetailMatakuliah: () =>
                context.go('/dosen/matakuliah/${j.matakuliahId}'),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB MINGGUAN
  // ══════════════════════════════════════════════════════════

  Widget _buildTabMingguan() {
    // Urutkan hari sesuai urutan Senin–Minggu
    final hariUrut = _urutanHari
        .where((h) => _jadwalMingguan.containsKey(h))
        .toList();

    if (hariUrut.isEmpty) {
      return const _EmptyState(
        icon    : Icons.calendar_month_outlined,
        title   : 'Belum ada jadwal minggu ini',
        subtitle: 'Hubungi admin jika ada kesalahan data',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchJadwal,
      color    : AppColors.kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount  : hariUrut.length,
        itemBuilder: (ctx, i) {
          final hari   = hariUrut[i];
          final list   = _jadwalMingguan[hari]!;
          final isHariIni = hari == _hariIni;
          final expanded  = _expandedHari.contains(hari);

          return _HariAccordion(
            hari       : hari,
            jadwalList : list,
            isHariIni  : isHariIni,
            expanded   : expanded,
            onToggle   : () {
              setState(() {
                if (expanded) {
                  _expandedHari.remove(hari);
                } else {
                  _expandedHari.add(hari);
                }
              });
            },
            countdownMap   : _countdownMap,
            formatCountdown: _formatCountdown,
            onBukaSesi     : _showBukaSesiSheet,
            onMonitor      : (sesiId) =>
                widget.onGoToMonitor?.call(sesiId),
            onRekap        : (sesiId) {
              if (sesiId != null) {
                context.go('/dosen/rekap/$sesiId');
              }
            },
            onTampilKode   : (j) {
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
            onDetailMatakuliah: (mkId) =>
                context.go('/dosen/matakuliah/$mkId'),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Accordion hari (Tab Mingguan)
// ══════════════════════════════════════════════════════════════

class _HariAccordion extends StatelessWidget {
  final String                  hari;
  final List<JadwalDosenItem>   jadwalList;
  final bool                    isHariIni;
  final bool                    expanded;
  final VoidCallback            onToggle;
  final Map<String, int>        countdownMap;
  final String Function(int)    formatCountdown;
  final void Function(JadwalDosenItem) onBukaSesi;
  final void Function(String?)  onMonitor;
  final void Function(String?)  onRekap;
  final void Function(JadwalDosenItem) onTampilKode;
  final void Function(String)   onDetailMatakuliah;

  const _HariAccordion({
    required this.hari,
    required this.jadwalList,
    required this.isHariIni,
    required this.expanded,
    required this.onToggle,
    required this.countdownMap,
    required this.formatCountdown,
    required this.onBukaSesi,
    required this.onMonitor,
    required this.onRekap,
    required this.onTampilKode,
    required this.onDetailMatakuliah,
  });

  // Jumlah sesi aktif di hari ini
  int get _jumlahAktif =>
      jadwalList.where((j) => j.statusSesi == 'aktif').length;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : isHariIni
            ? Border.all(
                color: AppColors.kNavy.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header accordion ──────────────────────────────
          InkWell(
            onTap       : onToggle,
            borderRadius: BorderRadius.vertical(
              top   : const Radius.circular(14),
              bottom: expanded
                  ? Radius.zero
                  : const Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Badge hari ini
                  if (isHariIni)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.kNavy,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('Hari Ini',
                        style: AppTypography.badge.copyWith(
                          color: Colors.white, fontSize: 10)),
                    ),

                  Text(hari,
                    style: AppTypography.bodyBold.copyWith(
                      color: isHariIni
                          ? AppColors.kNavy
                          : AppColors.kTextPrimary,
                      fontSize: 15)),

                  const Spacer(),

                  // Badge jumlah MK
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.kSoftGray,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('${jadwalList.length} MK',
                      style: AppTypography.caption),
                  ),

                  // Badge aktif (jika ada sesi aktif)
                  if (_jumlahAktif > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.kGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.kGreen.withOpacity(0.3))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulseDot(color: AppColors.kGreen),
                          const SizedBox(width: 4),
                          Text('$_jumlahAktif Aktif',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.kGreen, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns   : expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child   : Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.kTextSecondary, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Konten accordion ──────────────────────────────
          AnimatedCrossFade(
            duration      : const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild : const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                ...jadwalList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final j   = entry.value;
                  return Column(
                    children: [
                      if (idx > 0)
                        const Divider(height: 1, indent: 16),
                      _JadwalCardCompact(
                        jadwal         : j,
                        countdownDetik : countdownMap[j.sesiId ?? ''],
                        formatCountdown: formatCountdown,
                        onBukaSesi     : () => onBukaSesi(j),
                        onMonitor      : () => onMonitor(j.sesiId),
                        onRekap        : () => onRekap(j.sesiId),
                        onTampilKode   : () => onTampilKode(j),
                        onDetailMatakuliah: () =>
                            onDetailMatakuliah(j.matakuliahId),
                        isLast: idx == jadwalList.length - 1,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Jadwal Card — Tab Hari Ini (versi lengkap)
// ══════════════════════════════════════════════════════════════

class _JadwalCard extends StatelessWidget {
  final JadwalDosenItem      jadwal;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAktif
            ? Border.all(
                color: AppColors.kGreen.withOpacity(0.4), width: 1.5)
            : isSelesai
                ? Border.all(color: Colors.grey.shade200)
                : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset    : const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // ── Header — tap ke detail MK ─────────────────────
          InkWell(
            onTap       : onDetailMatakuliah,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: kode + kelas badge + sks + status
                  Row(
                    children: [
                      _KodePill(kode: jadwal.kode),
                      const SizedBox(width: 6),
                      if (jadwal.kodeKelas != null) ...[
                        KelasBadge(kodeKelas: jadwal.kodeKelas!),
                        const SizedBox(width: 6),
                      ],
                      Text('${jadwal.sks} SKS',
                        style: AppTypography.caption),
                      const Spacer(),
                      _StatusBadge(
                        label    : _statusLabel,
                        color    : _statusColor,
                        showPulse: isAktif),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Nama MK
                  Row(
                    children: [
                      Expanded(
                        child: Text(jadwal.nama,
                          style   : AppTypography.bodyBold.copyWith(
                            color: AppColors.kNavy, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.chevron_right_rounded,
                        size : 18,
                        color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Slot + jam + ruangan
                  _JamRuanganRow(jadwal: jadwal),

                  // Banner jadwal pengganti (dengan mode)
                  if (jadwal.adaJadwalPengganti) ...[
                    const SizedBox(height: 8),
                    _JadwalPenggantiAlert(jadwal: jadwal),
                  ],
                ],
              ),
            ),
          ),

          // ── Sub-info: pertemuan + mahasiswa + izin tamu ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (jadwal.pertemuanKe != null)
                  _InfoChip(
                    label: 'Pertemuan ${jadwal.pertemuanKe}',
                    color: Colors.blue.shade700,
                    bg   : Colors.blue.shade50),
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

          // ── Kode countdown (online + aktif) ──────────────
          if (isAktif && jadwal.kodeSesi != null &&
              countdownDetik != null)
            _KodeCountdownBar(
              kodeSesi       : jadwal.kodeSesi!,
              countdownDetik : countdownDetik!,
              formatCountdown: formatCountdown,
            ),

          const Divider(height: 1),

          // ── Tombol aksi ───────────────────────────────────
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
      return Row(
        children: [
          Expanded(
            child: _ActionBtn(
              label    : 'Lihat Rekap',
              icon     : Icons.summarize_rounded,
              color    : Colors.blue.shade700,
              filled   : true,
              onPressed: onRekap),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label    : 'Detail',
            icon     : Icons.school_outlined,
            color    : AppColors.kNavy,
            filled   : false,
            onPressed: onDetailMatakuliah),
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
        _ActionBtn(
          label    : 'Detail',
          icon     : Icons.school_outlined,
          color    : AppColors.kNavy,
          filled   : false,
          onPressed: onDetailMatakuliah),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Jadwal Card Compact — Tab Mingguan (dalam accordion)
// ══════════════════════════════════════════════════════════════

class _JadwalCardCompact extends StatelessWidget {
  final JadwalDosenItem      jadwal;
  final int?                 countdownDetik;
  final String Function(int) formatCountdown;
  final VoidCallback         onBukaSesi;
  final VoidCallback         onMonitor;
  final VoidCallback         onRekap;
  final VoidCallback         onTampilKode;
  final VoidCallback         onDetailMatakuliah;
  final bool                 isLast;

  const _JadwalCardCompact({
    required this.jadwal,
    required this.countdownDetik,
    required this.formatCountdown,
    required this.onBukaSesi,
    required this.onMonitor,
    required this.onRekap,
    required this.onTampilKode,
    required this.onDetailMatakuliah,
    required this.isLast,
  });

  Color get _statusColor {
    switch (jadwal.statusSesi) {
      case 'aktif'  : return AppColors.kGreen;
      case 'selesai': return AppColors.kTextSecondary;
      default       : return AppColors.kNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAktif = jadwal.statusSesi == 'aktif';

    return InkWell(
      onTap       : onDetailMatakuliah,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, isLast ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row: nama + badge kelas + status dot
            Row(
              children: [
                // Bar warna status
                Container(
                  width : 3, height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color       : _statusColor,
                    borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama MK + kelas badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(jadwal.nama,
                              style   : AppTypography.bodyBold.copyWith(
                                color: AppColors.kNavy, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          ),
                          if (jadwal.kodeKelas != null) ...[
                            const SizedBox(width: 6),
                            KelasBadge(
                              kodeKelas : jadwal.kodeKelas!,
                              fontSize  : 9,
                              showPrefix: false),
                          ],
                          if (isAktif) ...[
                            const SizedBox(width: 6),
                            _PulseDot(color: AppColors.kGreen),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Jam + ruangan
                      Row(
                        children: [
                          _KodePill(kode: jadwal.kode, small: true),
                          const SizedBox(width: 6),
                          Icon(Icons.access_time_rounded,
                            size: 11,
                            color: AppColors.kTextSecondary),
                          const SizedBox(width: 3),
                          // Slot label compact
                          jadwal.slotMulai != null
                              ? SlotLabelCompact(
                                  slotMulai  : jadwal.slotMulai,
                                  slotSelesai: jadwal.slotSelesai,
                                  fontSize   : 11)
                              : Text(jadwal.labelJam,
                                  style: AppTypography.caption),
                          const SizedBox(width: 6),
                          if (jadwal.labelRuangan != '-') ...[
                            Icon(Icons.room_outlined,
                              size: 11,
                              color: AppColors.kTextSecondary),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(jadwal.labelRuangan,
                                style   : AppTypography.caption,
                                overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Banner jadwal pengganti (jika ada, termasuk mode)
            if (jadwal.adaJadwalPengganti) ...[
              const SizedBox(height: 6),
              _JadwalPenggantiAlert(jadwal: jadwal, compact: true),
            ],

            // Tombol aksi compact
            const SizedBox(height: 8),
            _buildCompactActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActions() {
    if (jadwal.statusSesi == 'aktif') {
      return Row(
        children: [
          _ChipButton(
            label    : 'Monitor',
            icon     : Icons.bar_chart_rounded,
            color    : AppColors.kNavy,
            onPressed: onMonitor),
          const SizedBox(width: 6),
          if (jadwal.kodeSesi != null)
            _ChipButton(
              label    : 'Kode',
              icon     : Icons.vpn_key_rounded,
              color    : const Color(0xFF7C3AED),
              onPressed: onTampilKode),
        ],
      );
    }
    if (jadwal.statusSesi == 'selesai') {
      return _ChipButton(
        label    : 'Rekap',
        icon     : Icons.summarize_rounded,
        color    : Colors.blue.shade700,
        onPressed: onRekap);
    }
    return _ChipButton(
      label    : 'Buka Sesi',
      icon     : Icons.play_circle_rounded,
      color    : AppColors.kNavy,
      onPressed: onBukaSesi);
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Bottom Sheet Buka Sesi (sama dengan Beranda Dosen)
// ══════════════════════════════════════════════════════════════

class _BukaSesiSheet extends StatefulWidget {
  final JadwalDosenItem                     jadwal;
  final void Function(Map<String, dynamic>) onBerhasil;

  const _BukaSesiSheet({
    required this.jadwal,
    required this.onBerhasil,
  });

  @override
  State<_BukaSesiSheet> createState() => _BukaSesiSheetState();
}

class _BukaSesiSheetState extends State<_BukaSesiSheet> {
  String _mode            = 'offline';
  int?   _batasTerlambat  = 15;
  int    _durasiKode      = 30;
  bool   _mulaiDariJadwal = true;
  bool   _isLoading       = false;
  Map<String, dynamic>? _selectedKelas;

  final List<int?> _opsiTerlambat = [null, 0, 10, 15, 30];
  final List<int>  _opsiDurasi    = [15, 30, 60, 90];

  bool get _hasMultiKelas => widget.jadwal.kelasList.length > 1;

  String _labelTerlambat(int? v) {
    if (v == null) return 'Tidak ada batas';
    if (v == 0)   return 'Langsung';
    return '$v mnt';
  }

  @override
  void initState() {
    super.initState();
    if (widget.jadwal.kelasList.length == 1) {
      _selectedKelas = widget.jadwal.kelasList.first;
    }
    // Isi mode default dari jadwal pengganti jika ada
    if (widget.jadwal.adaJadwalPengganti &&
        widget.jadwal.modePengganti != null) {
      _mode = widget.jadwal.modePengganti!;
    }
  }

  Future<void> _bukaSesi() async {
    if (widget.jadwal.pertemuanKe == null) {
      _snack('Tidak dapat menentukan nomor pertemuan');
      return;
    }
    if (_hasMultiKelas && _selectedKelas == null) {
      _snack('Pilih kelas terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'matakuliah_id'        : widget.jadwal.matakuliahId,
        'mode'                 : _mode,
        'pertemuan_ke'         : widget.jadwal.pertemuanKe,
        'batas_terlambat_menit': _batasTerlambat,
        'mulai_dari_jam_jadwal': _mulaiDariJadwal,
      };
      final kelasId = _selectedKelas?['id'] as String?
                   ?? widget.jadwal.kelasId;
      if (kelasId != null && kelasId.isNotEmpty) {
        body['kelas_id'] = kelasId;
      }
      if (_mode == 'online') body['durasi_menit'] = _durasiKode;

      final resp = await ApiClient().post('/sesi/buka', body: body);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (!mounted) return;
      widget.onBerhasil(data);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('Gagal buka sesi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: AppColors.kDanger,
      behavior       : SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize      : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color       : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
            ),
            Text('Buka Sesi Presensi',
              style: AppTypography.heading3),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.jadwal.nama}  ·  ${widget.jadwal.kode}',
                    style: AppTypography.body2,
                    overflow: TextOverflow.ellipsis)),
                if (widget.jadwal.kodeKelas != null && !_hasMultiKelas) ...[
                  const SizedBox(width: 6),
                  KelasBadge(kodeKelas: widget.jadwal.kodeKelas!),
                ],
              ],
            ),

            // Info jadwal pengganti dengan mode
            if (widget.jadwal.adaJadwalPengganti) ...[
              const SizedBox(height: 10),
              _JadwalPenggantiAlert(jadwal: widget.jadwal),
            ],

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Dropdown kelas (multi)
            if (_hasMultiKelas) ...[
              Text('Kelas',
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.kNavy, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.kBgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.kSoftGray, width: 1)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value     : _selectedKelas,
                    isExpanded: true,
                    hint      : Text('Pilih kelas...',
                      style: AppTypography.body2),
                    items: widget.jadwal.kelasList.map((k) {
                      final kk = k['kode_kelas'] as String? ?? '';
                      final dn = k['dosen_nama'] as String? ?? '-';
                      return DropdownMenuItem(
                        value: k,
                        child: Row(
                          children: [
                            KelasBadge(kodeKelas: kk),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(dn,
                                style   : AppTypography.body2
                                    .copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedKelas = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pertemuan ke
            _InfoRow(
              label: 'Pertemuan ke',
              value: widget.jadwal.pertemuanKe != null
                  ? '${widget.jadwal.pertemuanKe}'
                  : 'Tidak tersedia'),
            const SizedBox(height: 12),

            // Waktu mulai
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
                        style: AppTypography.body2
                            .copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value    : _mulaiDariJadwal,
                  onChanged: (v) =>
                      setState(() => _mulaiDariJadwal = v),
                  activeColor: AppColors.kNavy),
              ],
            ),
            const SizedBox(height: 16),

            // Mode
            Text('Mode Kelas',
              style: AppTypography.bodyBold.copyWith(
                color: AppColors.kNavy, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label   : '📍 Tatap Muka',
                    selected: _mode == 'offline',
                    color   : AppColors.kNavy,
                    onTap   : () => setState(() => _mode = 'offline'))),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label   : '💻 Online',
                    selected: _mode == 'online',
                    color   : const Color(0xFF7C3AED),
                    onTap   : () => setState(() => _mode = 'online'))),
              ],
            ),
            const SizedBox(height: 16),

            // Toleransi terlambat
            Text('Toleransi Terlambat',
              style: AppTypography.bodyBold.copyWith(
                color: AppColors.kNavy, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: _opsiTerlambat.map((v) => ChoiceChip(
                label     : Text(_labelTerlambat(v),
                  style: AppTypography.caption),
                selected  : _batasTerlambat == v,
                onSelected: (_) =>
                    setState(() => _batasTerlambat = v),
                selectedColor: AppColors.kNavy,
                labelStyle: TextStyle(
                  color: _batasTerlambat == v
                      ? Colors.white
                      : AppColors.kTextPrimary),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // Durasi kode (online)
            if (_mode == 'online') ...[
              Text('Durasi Kode Aktif',
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.kNavy, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: _opsiDurasi.map((v) => ChoiceChip(
                  label     : Text('$v mnt',
                    style: AppTypography.caption),
                  selected  : _durasiKode == v,
                  onSelected: (_) =>
                      setState(() => _durasiKode = v),
                  selectedColor: const Color(0xFF7C3AED),
                  labelStyle: TextStyle(
                    color: _durasiKode == v
                        ? Colors.white
                        : AppColors.kTextPrimary),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Tombol
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
                    : const Icon(
                        Icons.play_circle_rounded, size: 22),
                label: Text(
                  _isLoading
                      ? 'Membuka...'
                      : _mode == 'online'
                          ? 'Buka Sesi & Generate Kode'
                          : 'Buka Sesi Tatap Muka',
                  style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mode == 'online'
                      ? const Color(0xFF7C3AED)
                      : AppColors.kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET HELPERS — shared di seluruh screen ini
// ══════════════════════════════════════════════════════════════

/// Pill kode MK (mis. "TIF3232209")
class _KodePill extends StatelessWidget {
  final String kode;
  final bool   small;
  const _KodePill({required this.kode, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 8,
      vertical  : small ? 1 : 2),
    decoration: BoxDecoration(
      color       : AppColors.kNavy.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6)),
    child: Text(kode,
      style: AppTypography.badge.copyWith(
        color   : AppColors.kNavy,
        fontSize: small ? 9 : 11)),
  );
}

/// Status badge: AKTIF / SELESAI / BELUM MULAI
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   showPulse;
  const _StatusBadge({
    required this.label,
    required this.color,
    this.showPulse = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color       : color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPulse) ...[
          _PulseDot(color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
          style: AppTypography.badge.copyWith(
            color: color, fontSize: 10)),
      ],
    ),
  );
}

/// Row jam + ruangan dengan slot label
class _JamRuanganRow extends StatelessWidget {
  final JadwalDosenItem jadwal;
  const _JamRuanganRow({required this.jadwal});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.access_time_rounded,
        size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      // Slot atau jam biasa
      jadwal.slotMulai != null
          ? SlotLabel(
              slotMulai      : jadwal.slotMulai,
              slotSelesai    : jadwal.slotSelesai,
              showIcon       : false,
              showSlotNumber : true,
              fontSize       : 12)
          : Text(jadwal.labelJam,
              style: AppTypography.body2.copyWith(fontSize: 12)),
      const SizedBox(width: 10),
      Icon(Icons.room_outlined,
        size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Expanded(
        child: Text(jadwal.labelRuangan,
          style   : AppTypography.body2.copyWith(fontSize: 12),
          overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// Banner kuning jadwal pengganti — tampilkan jam, ruangan, dan MODE
class _JadwalPenggantiAlert extends StatelessWidget {
  final JadwalDosenItem jadwal;
  final bool            compact;
  const _JadwalPenggantiAlert({
    required this.jadwal,
    this.compact = false,
  });

  String get _detail {
    final parts = <String>[];
    if (jadwal.jamMulaiPengganti != null &&
        jadwal.jamSelesaiPengganti != null) {
      parts.add(
          '${jadwal.jamMulaiPengganti} – ${jadwal.jamSelesaiPengganti}');
    }
    if (jadwal.ruanganPengganti != null) {
      parts.add(jadwal.ruanganPengganti!);
    }
    if (jadwal.modePengganti != null) {
      parts.add(jadwal.modePengganti!.toLowerCase() == 'online'
          ? '💻 Online'
          : '📍 Tatap Muka');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: 10,
      vertical  : compact ? 6 : 8),
    decoration: BoxDecoration(
      color: AppColors.kGold.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border(
        left: BorderSide(color: AppColors.kGold, width: 3))),
    child: Row(
      children: [
        Icon(Icons.swap_horiz_rounded,
          size: 14, color: AppColors.kWarning),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jadwal Pengganti',
                style: AppTypography.badge.copyWith(
                  color     : AppColors.kWarning,
                  fontSize  : 10,
                  fontWeight: FontWeight.w700)),
              if (_detail.isNotEmpty)
                Text(_detail,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.kTextSecondary)),
            ],
          ),
        ),
        // Badge mode pengganti (jika ada)
        if (jadwal.modePengganti != null)
          ModeBadge(
            mode    : jadwal.modePengganti!,
            fontSize: 9,
            padding : const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2)),
      ],
    ),
  );
}

/// Countdown bar kode sesi online
class _KodeCountdownBar extends StatelessWidget {
  final String           kodeSesi;
  final int              countdownDetik;
  final String Function(int) formatCountdown;
  const _KodeCountdownBar({
    required this.kodeSesi,
    required this.countdownDetik,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin : const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.symmetric(
      horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color : AppColors.kNavy.withOpacity(0.04),
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
        Text(kodeSesi,
          style: AppTypography.kodeSmall),
        const Spacer(),
        Icon(Icons.timer_outlined,
          size : 14,
          color: countdownDetik < 300
              ? AppColors.kDanger : AppColors.kGreen),
        const SizedBox(width: 4),
        Text(formatCountdown(countdownDetik),
          style: AppTypography.label.copyWith(
            color: countdownDetik < 300
                ? AppColors.kDanger : AppColors.kGreen,
            fontWeight: FontWeight.bold,
            fontSize  : 13)),
      ],
    ),
  );
}

/// Info chip kecil
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
    padding: const EdgeInsets.symmetric(
      horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
      style: AppTypography.badge.copyWith(
        color: color, fontSize: 11)),
  );
}

/// Tombol chip kecil (Tab Mingguan)
class _ChipButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onPressed;
  const _ChipButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border      : Border.all(
          color: color.withOpacity(0.30), width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
            style: AppTypography.badge.copyWith(
              color: color, fontSize: 11)),
        ],
      ),
    ),
  );
}

/// Tombol aksi (ElevatedButton / OutlinedButton)
class _ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         filled;
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
        label: Text(label, style: AppTypography.buttonSmall),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10))));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon : Icon(icon, size: 16),
      label: Text(label, style: AppTypography.buttonSmall),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10))));
  }
}

/// Row info: label : value
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

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

/// Mode chip di bottom sheet
class _ModeChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;
  const _ModeChip({
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
          color  : selected ? Colors.white : AppColors.kTextPrimary,
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
      vsync   : this,
      duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: widget.color, shape: BoxShape.circle)),
  );
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(title,
            style    : AppTypography.bodyBold.copyWith(
              color: AppColors.kNavy, fontSize: 16),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
            style    : AppTypography.body2,
            textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ── Error View ────────────────────────────────────────────────
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
          Text('Gagal memuat jadwal',
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
              foregroundColor: Colors.white)),
        ],
      ),
    ),
  );
}