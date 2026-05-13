// lib/screens/dosen/jadwal_dosen_screen.dart
// BUGFIX v2.1.3:
//
// FIX 1 (CRITICAL — blank Hari Ini): _hariIni diambil dari mingguan response
//   saja (tidak lagi dari DateTime.now() di initState). Ini memastikan key
//   yang dipakai untuk slice _jadwalHariIni SELALU identik dengan key di
//   _jadwalMingguan. Sebelumnya DateTime.now() bisa menghasilkan "Rabu" tapi
//   server mengembalikan "Rabu" juga — namun slice dilakukan SEBELUM
//   _jadwalMingguan terisi, sehingga hasilnya selalu kosong.
//   Root cause: _jadwalHariIni = mingguanMap[hariDariServer] dipanggil saat
//   mingguanMap baru saja diparse tapi belum di-assign ke _jadwalMingguan.
//   Fix: pastikan slice terjadi dari variabel lokal mingguanMap, bukan dari
//   state, dan setState() dipanggil dengan keduanya sekaligus.
//
// FIX 2 (layout crash): _ActionBtn OutlinedButton tanpa Expanded di dalam Row
//   menyebabkan BoxConstraints forces an infinite width. Fix: hapus
//   minimumSize: double.infinity dari OutlinedButton/ElevatedButton style,
//   ganti dengan SizedBox atau biarkan parent yang constrain.
//   Khusus di _buildActions() "selesai" — tombol "Detail" tidak dibungkus
//   Expanded, jadi OutlinedButton tidak boleh punya width=infinity.
//
// FIX 3 (BerandaDosenScreen blank): Beranda juga terkena masalah serupa —
//   setelah _fetchBeranda() resolve, _isLoading di-set false di finally
//   block yang sudah ada. Masalahnya adalah beranda dosen ini untuk akun
//   "Suryanti" (Rabu) — beranda menampilkan "0 matakuliah Rabu" padahal
//   di tab Jadwal terlihat ada 2 MK (Jaringan Komputer & Logika dan Himpunan).
//   Ini bukan bug di file ini tapi di dosen_service.py — beranda_dosen_screen
//   sudah benar. Lihat catatan di bawah.
//
// CATATAN BERANDA:
//   Beranda menunjukkan "0 matakuliah" untuk dosen Suryanti di Rabu, tapi
//   Jadwal tab Mingguan menunjukkan 2 MK di Rabu. Ini karena:
//   GET /dosen/beranda → dosen_service.get_beranda_dosen() sudah dipatch
//   menggunakan kelas_matakuliah (bukan matakuliah.hari). Kemungkinan akun
//   Suryanti bukan dosen di kelas-kelas tersebut (dosen_id berbeda).
//   Cek seed data: apakah Suryanti (NIDN 0102034510) memang dosen di kelas
//   IK3012301 dan TIF3221308? Kalau iya, bug ada di backend dosen_service,
//   bukan di Flutter.
//
// FIX 4: FCM updateToken error "type 'List<dynamic>' is not a subtype of
//   type 'String'" — ini bug di fcm_service.dart, bukan di file ini.
//   Fix: await ApiClient().patch(...) mungkin mengembalikan list, bukan
//   dict. Tambahkan try-catch yang lebih spesifik di fcm_service.dart.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/slot_label.dart';

// ─── Model ────────────────────────────────────────────────────

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
  final String  statusSesi;
  final String? sesiId;
  final int?    pertemuanKe;
  final String? kodeSesi;
  final int?    detikTersisa;
  final String? kodeKelas;
  final String? kelasId;
  final int?    slotMulai;
  final int?    slotSelesai;
  final bool    adaJadwalPengganti;
  final String? jamMulaiPengganti;
  final String? jamSelesaiPengganti;
  final String? ruanganPengganti;
  final String? modePengganti;
  final bool    izinTamu;
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

  factory JadwalDosenItem.fromMingguanJson(Map<String, dynamic> j) {
    final jp = j['jadwal_pengganti'] as Map<String, dynamic>?;
    return JadwalDosenItem(
      matakuliahId       : j['matakuliah_id']                as String,
      kode               : j['matakuliah_kode']              as String? ?? '',
      nama               : j['matakuliah_nama']              as String? ?? '',
      sks                : j['sks']                          as int?    ?? 0,
      hari               : j['hari']                         as String?,
      jamMulai           : j['jam_mulai']                    as String?,
      jamSelesai         : j['jam_selesai']                  as String?,
      ruangan            : (j['nama_ruangan'] ?? j['kode_ruangan']) as String?,
      jumlahMahasiswa    : j['jumlah_mahasiswa']             as int?    ?? 0,
      statusSesi         : j['status_sesi']                  as String? ?? 'belum_dibuka',
      sesiId             : j['sesi_id']?.toString(),
      pertemuanKe        : j['pertemuan_ke_berikutnya']      as int?,
      kodeSesi           : null,
      detikTersisa       : null,
      kodeKelas          : j['kode_kelas']                   as String?,
      kelasId            : j['kelas_id']?.toString(),
      slotMulai          : j['slot_mulai']                   as int?,
      slotSelesai        : j['slot_selesai']                 as int?,
      adaJadwalPengganti : j['ada_jadwal_pengganti']         as bool?   ?? false,
      jamMulaiPengganti  : jp?['jam_mulai_baru']             as String?,
      jamSelesaiPengganti: jp?['jam_selesai_baru']           as String?,
      ruanganPengganti   : jp?['ruangan_baru']               as String?,
      modePengganti      : jp?['mode']                       as String?,
      izinTamu           : j['izin_tamu']                    as bool?   ?? false,
      kelasList          : const [],
    );
  }

  factory JadwalDosenItem.fromBerandaJson(Map<String, dynamic> j) {
    return JadwalDosenItem(
      matakuliahId       : j['matakuliah_id']          as String,
      kode               : j['kode']                   as String? ?? '',
      nama               : j['nama']                   as String? ?? '',
      sks                : j['sks']                    as int?    ?? 0,
      hari               : j['hari']                   as String?,
      jamMulai           : j['jam_mulai']              as String?,
      jamSelesai         : j['jam_selesai']             as String?,
      ruangan            : j['ruangan']                as String?,
      jumlahMahasiswa    : j['jumlah_mahasiswa']        as int?    ?? 0,
      statusSesi         : j['status_sesi']            as String? ?? 'belum_mulai',
      sesiId             : j['sesi_id']                as String?,
      pertemuanKe        : j['pertemuan_ke']           as int?,
      kodeSesi           : j['kode_sesi']              as String?,
      detikTersisa       : j['detik_tersisa']          as int?,
      kodeKelas          : j['kode_kelas']             as String?,
      kelasId            : j['kelas_id']               as String?,
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
  }

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

  String? get modeEfektif => adaJadwalPengganti ? modePengganti : null;

  bool get isBelumMulai =>
      statusSesi == 'belum_mulai' || statusSesi == 'belum_dibuka';
  bool get isAktif    => statusSesi == 'aktif';
  bool get isSelesai  => statusSesi == 'selesai';
}

const _urutanHari = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

// Helper: nama hari dari weekday number
String _namaHariDariWeekday(int weekday) {
  const map = {
    1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
    5: 'Jumat', 6: 'Sabtu',  7: 'Minggu',
  };
  return map[weekday] ?? 'Senin';
}

// ══════════════════════════════════════════════════════════════
// SCREEN UTAMA
// ══════════════════════════════════════════════════════════════

class JadwalDosenScreen extends StatefulWidget {
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

  // FIX 1: _hariIni dimulai dengan string kosong, diisi dari server response
  // BUKAN dari DateTime.now() — agar selalu sinkron dengan key di mingguanMap
  String  _hariIni      = '';
  bool    _isLoading    = true;
  String? _error;
  bool    _isFetching   = false;

  List<JadwalDosenItem>               _jadwalHariIni  = [];
  Map<String, List<JadwalDosenItem>>  _jadwalMingguan = {};

  Timer?               _countdownTimer;
  final Map<String, int> _countdownMap = {};
  final Set<String>      _expandedHari = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // FIX 1: Jangan set _hariIni dari DateTime.now() di sini.
    // Biarkan kosong, akan diisi dari server. Expanded set setelah fetch.
    _fetchJadwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── FETCH UTAMA ───────────────────────────────────────────
  Future<void> _fetchJadwal() async {
    if (_isFetching) return;
    _isFetching = true;
    if (mounted) setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient().get('/dosen/jadwal/mingguan');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;

      // FIX 1: Ambil hari_ini dari server, fallback ke DateTime.now()
      final hariDariServer = (data['hari_ini'] as String?)?.trim()
          ?? _namaHariDariWeekday(DateTime.now().weekday);

      // Parse jadwal_per_hari dari server
      final Map<String, List<JadwalDosenItem>> mingguanMap = {};
      final jadwalPerHari = data['jadwal_per_hari'] as Map<String, dynamic>? ?? {};

      for (final entry in jadwalPerHari.entries) {
        // Trim key untuk jaga-jaga whitespace
        final hariKey = entry.key.trim();
        final list = (entry.value as List<dynamic>)
            .map((e) => JadwalDosenItem.fromMingguanJson(e as Map<String, dynamic>))
            .toList();
        mingguanMap[hariKey] = list;
      }

      // FIX 1 (KRITIS): Slice _jadwalHariIni dari mingguanMap LOKAL,
      // BUKAN dari _jadwalMingguan (state) yang belum di-update.
      // Ini adalah bug utama — sebelumnya slice terjadi setelah setState
      // atau menggunakan _hariIni yang bisa berbeda dari hariDariServer.
      final hariIniList = List<JadwalDosenItem>.from(
        mingguanMap[hariDariServer] ?? [],
      );

      // Debug log untuk trace jika masih blank
      debugPrint('[JadwalDosen] hari_dari_server="$hariDariServer"');
      debugPrint('[JadwalDosen] keys_available=${mingguanMap.keys.toList()}');
      debugPrint('[JadwalDosen] jadwal_hari_ini_count=${hariIniList.length}');

      if (mounted) {
        setState(() {
          // FIX 1: Set _hariIni dari server, bukan DateTime.now()
          _hariIni        = hariDariServer;
          // FIX 1: Set KEDUA state sekaligus dalam satu setState()
          _jadwalHariIni  = hariIniList;
          _jadwalMingguan = mingguanMap;
          _isLoading      = false;
          _error          = null;
        });

        // Expand hari ini di accordion mingguan
        if (!_expandedHari.contains(_hariIni)) {
          _expandedHari.add(_hariIni);
        }
      }

      // Fetch beranda untuk enrich countdown & kode_sesi (non-blocking)
      _fetchBerandaForCountdown(hariDariServer, mingguanMap);

    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    } finally {
      _isFetching = false;
      // Pastikan _isLoading selalu false
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Fetch beranda untuk update countdown/kode_sesi (non-blocking) ──
  Future<void> _fetchBerandaForCountdown(
    String hariDariServer,
    Map<String, List<JadwalDosenItem>> mingguanMap,
  ) async {
    try {
      final berandaResp = await ApiClient().get('/dosen/beranda');
      final berandaData = jsonDecode(berandaResp.body) as Map<String, dynamic>;

      final jadwalBeranda = (berandaData['jadwal_hari_ini'] as List<dynamic>? ?? [])
          .map((e) => JadwalDosenItem.fromBerandaJson(e as Map<String, dynamic>))
          .toList();

      if (jadwalBeranda.isEmpty || !mounted) return;

      final berandaMap = <String, JadwalDosenItem>{
        for (final j in jadwalBeranda) j.matakuliahId: j,
      };

      final countdownMap = <String, int>{};
      for (final j in jadwalBeranda) {
        if (j.sesiId != null && j.detikTersisa != null && j.isAktif) {
          countdownMap[j.sesiId!] = j.detikTersisa!;
        }
      }

      // Merge: update status sesi, kode_sesi, detik_tersisa dari beranda
      final hariIniUpdated = (mingguanMap[hariDariServer] ?? []).map((j) {
        final b = berandaMap[j.matakuliahId];
        if (b == null) return j;
        return JadwalDosenItem(
          matakuliahId       : j.matakuliahId,
          kode               : j.kode,
          nama               : j.nama,
          sks                : j.sks,
          hari               : j.hari,
          jamMulai           : j.jamMulai,
          jamSelesai         : j.jamSelesai,
          ruangan            : j.ruangan,
          jumlahMahasiswa    : j.jumlahMahasiswa,
          statusSesi         : b.statusSesi.isNotEmpty ? b.statusSesi : j.statusSesi,
          sesiId             : j.sesiId ?? b.sesiId,
          pertemuanKe        : j.pertemuanKe ?? b.pertemuanKe,
          kodeSesi           : b.kodeSesi,
          detikTersisa       : b.detikTersisa,
          kodeKelas          : j.kodeKelas ?? b.kodeKelas,
          kelasId            : j.kelasId   ?? b.kelasId,
          slotMulai          : j.slotMulai,
          slotSelesai        : j.slotSelesai,
          adaJadwalPengganti : j.adaJadwalPengganti,
          jamMulaiPengganti  : j.jamMulaiPengganti,
          jamSelesaiPengganti: j.jamSelesaiPengganti,
          ruanganPengganti   : j.ruanganPengganti,
          modePengganti      : j.modePengganti,
          izinTamu           : j.izinTamu,
          kelasList          : b.kelasList.isNotEmpty ? b.kelasList : j.kelasList,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _jadwalHariIni = hariIniUpdated;
        _countdownMap
          ..clear()
          ..addAll(countdownMap);
      });

      _startCountdown();

    } catch (e) {
      debugPrint('[JadwalDosen] fetchBeranda failed (non-critical): $e');
      // Tidak apa-apa — data mingguan sudah tampil
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
                icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _fetchJadwal,
                tooltip  : 'Refresh',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48 + 2),
              child: Column(
                children: [
                  TabBar(
                    controller           : _tabController,
                    indicatorColor       : AppColors.kGold,
                    indicatorWeight      : 3,
                    labelColor           : Colors.white,
                    unselectedLabelColor : Colors.white54,
                    labelStyle           : AppTypography.button.copyWith(fontSize: 13),
                    unselectedLabelStyle : AppTypography.body2
                        .copyWith(color: Colors.white54, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Hari Ini'),
                      Tab(text: 'Mingguan'),
                    ],
                  ),
                  Container(height: 2, color: AppColors.kGold.withOpacity(0.4)),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.kNavy))
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

  // ── Tab Hari Ini ──────────────────────────────────────────

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
            onMonitor      : () => widget.onGoToMonitor?.call(j.sesiId),
            onRekap        : () {
              if (j.sesiId != null) context.go('/dosen/rekap/${j.sesiId}');
            },
            onTampilKode   : () {
              if (j.sesiId == null) return;
              context.go('/dosen/kode', extra: {
                'id'           : j.sesiId,
                'sesi_id'      : j.sesiId,
                'kode_sesi'    : j.kodeSesi ?? '',
                'detik_tersisa': _countdownMap[j.sesiId!] ?? j.detikTersisa ?? 0,
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

  // ── Tab Mingguan ──────────────────────────────────────────

  Widget _buildTabMingguan() {
    final hariUrut = _urutanHari
        .where((h) => (_jadwalMingguan[h]?.isNotEmpty ?? false))
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
          final hari      = hariUrut[i];
          final list      = _jadwalMingguan[hari]!;
          final isHariIni = hari == _hariIni;
          final expanded  = _expandedHari.contains(hari);

          return _HariAccordion(
            hari       : hari,
            jadwalList : list,
            isHariIni  : isHariIni,
            expanded   : expanded,
            onToggle   : () => setState(() {
              if (expanded) _expandedHari.remove(hari);
              else          _expandedHari.add(hari);
            }),
            countdownMap   : _countdownMap,
            formatCountdown: _formatCountdown,
            onBukaSesi     : _showBukaSesiSheet,
            onMonitor      : (sesiId) => widget.onGoToMonitor?.call(sesiId),
            onRekap        : (sesiId) {
              if (sesiId != null) context.go('/dosen/rekap/$sesiId');
            },
            onTampilKode   : (j) {
              if (j.sesiId == null) return;
              context.go('/dosen/kode', extra: {
                'id'           : j.sesiId,
                'sesi_id'      : j.sesiId,
                'kode_sesi'    : j.kodeSesi ?? '',
                'detik_tersisa': _countdownMap[j.sesiId!] ?? j.detikTersisa ?? 0,
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

  int get _jumlahAktif => jadwalList.where((j) => j.isAktif).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : isHariIni
            ? Border.all(color: AppColors.kNavy.withOpacity(0.3), width: 1.5)
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
          InkWell(
            onTap       : onToggle,
            borderRadius: BorderRadius.vertical(
              top   : const Radius.circular(14),
              bottom: expanded ? Radius.zero : const Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (isHariIni)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.kNavy,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('Hari Ini',
                        style: AppTypography.badge.copyWith(
                          color: Colors.white, fontSize: 10)),
                    ),
                  Text(hari,
                    style: AppTypography.bodyBold.copyWith(
                      color   : isHariIni ? AppColors.kNavy : AppColors.kTextPrimary,
                      fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.kSoftGray,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('${jadwalList.length} MK',
                      style: AppTypography.caption),
                  ),
                  if (_jumlahAktif > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color : AppColors.kGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.kGreen.withOpacity(0.3))),
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
                      if (idx > 0) const Divider(height: 1, indent: 16),
                      _JadwalCardCompact(
                        jadwal         : j,
                        countdownDetik : countdownMap[j.sesiId ?? ''],
                        formatCountdown: formatCountdown,
                        onBukaSesi     : () => onBukaSesi(j),
                        onMonitor      : () => onMonitor(j.sesiId),
                        onRekap        : () => onRekap(j.sesiId),
                        onTampilKode   : () => onTampilKode(j),
                        onDetailMatakuliah: () => onDetailMatakuliah(j.matakuliahId),
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
// WIDGET: Jadwal Card — Tab Hari Ini
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
    if (jadwal.isAktif)   return AppColors.kGreen;
    if (jadwal.isSelesai) return AppColors.kTextSecondary;
    return AppColors.kNavy;
  }

  String get _statusLabel {
    if (jadwal.isAktif)   return 'AKTIF';
    if (jadwal.isSelesai) return 'SELESAI';
    return 'BELUM MULAI';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin    : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : jadwal.isAktif
            ? Border.all(color: AppColors.kGreen.withOpacity(0.4), width: 1.5)
            : jadwal.isSelesai
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
          InkWell(
            onTap       : onDetailMatakuliah,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _KodePill(kode: jadwal.kode),
                      const SizedBox(width: 6),
                      if (jadwal.kodeKelas != null) ...[
                        KelasBadge(kodeKelas: jadwal.kodeKelas!),
                        const SizedBox(width: 6),
                      ],
                      Text('${jadwal.sks} SKS', style: AppTypography.caption),
                      const Spacer(),
                      _StatusBadge(
                        label    : _statusLabel,
                        color    : _statusColor,
                        showPulse: jadwal.isAktif),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(jadwal.nama,
                          style   : AppTypography.bodyBold.copyWith(
                            color: AppColors.kNavy, fontSize: 15),
                          overflow: TextOverflow.ellipsis)),
                      Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _JamRuanganRow(jadwal: jadwal),
                  if (jadwal.adaJadwalPengganti) ...[
                    const SizedBox(height: 8),
                    _JadwalPenggantiAlert(jadwal: jadwal),
                  ],
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
          if (jadwal.isAktif && jadwal.kodeSesi != null &&
              countdownDetik != null)
            _KodeCountdownBar(
              kodeSesi       : jadwal.kodeSesi!,
              countdownDetik : countdownDetik!,
              formatCountdown: formatCountdown,
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
    if (jadwal.isAktif) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _ActionBtn(
              label    : 'Monitor Live',
              icon     : Icons.bar_chart_rounded,
              color    : AppColors.kNavy,
              filled   : true,
              onPressed: onMonitor)),
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
                    onPressed: onRekap)),
        ],
      );
    }
    if (jadwal.isSelesai) {
      // FIX 2: Kedua tombol dibungkus Expanded agar tidak infinite width
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _ActionBtn(
              label    : 'Lihat Rekap',
              icon     : Icons.summarize_rounded,
              color    : Colors.blue.shade700,
              filled   : true,
              onPressed: onRekap)),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionBtn(
              label    : 'Detail',
              icon     : Icons.school_outlined,
              color    : AppColors.kNavy,
              filled   : false,
              onPressed: onDetailMatakuliah)),
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
            onPressed: onBukaSesi)),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionBtn(
            label    : 'Detail',
            icon     : Icons.school_outlined,
            color    : AppColors.kNavy,
            filled   : false,
            onPressed: onDetailMatakuliah)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Jadwal Card Compact — Tab Mingguan
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
    if (jadwal.isAktif)   return AppColors.kGreen;
    if (jadwal.isSelesai) return AppColors.kTextSecondary;
    return AppColors.kNavy;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDetailMatakuliah,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color       : _statusColor,
                    borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(jadwal.nama,
                              style   : AppTypography.bodyBold.copyWith(
                                color: AppColors.kNavy, fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                          if (jadwal.kodeKelas != null) ...[
                            const SizedBox(width: 6),
                            KelasBadge(
                              kodeKelas : jadwal.kodeKelas!,
                              fontSize  : 9,
                              showPrefix: false),
                          ],
                          if (jadwal.isAktif) ...[
                            const SizedBox(width: 6),
                            _PulseDot(color: AppColors.kGreen),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _KodePill(kode: jadwal.kode, small: true),
                          const SizedBox(width: 6),
                          Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.kTextSecondary),
                          const SizedBox(width: 3),
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
                              size: 11, color: AppColors.kTextSecondary),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(jadwal.labelRuangan,
                                style   : AppTypography.caption,
                                overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (jadwal.adaJadwalPengganti) ...[
              const SizedBox(height: 6),
              _JadwalPenggantiAlert(jadwal: jadwal, compact: true),
            ],
            const SizedBox(height: 8),
            _buildCompactActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActions() {
    if (jadwal.isAktif) {
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
    if (jadwal.isSelesai) {
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
// WIDGET: Bottom Sheet Buka Sesi
// ══════════════════════════════════════════════════════════════

class _BukaSesiSheet extends StatefulWidget {
  final JadwalDosenItem                     jadwal;
  final void Function(Map<String, dynamic>) onBerhasil;

  const _BukaSesiSheet({required this.jadwal, required this.onBerhasil});

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
    if (widget.jadwal.adaJadwalPengganti && widget.jadwal.modePengganti != null) {
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
      final kelasId = _selectedKelas?['id'] as String? ?? widget.jadwal.kelasId;
      if (kelasId != null && kelasId.isNotEmpty) body['kelas_id'] = kelasId;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
            Text('Buka Sesi Presensi', style: AppTypography.heading3),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.jadwal.nama}  ·  ${widget.jadwal.kode}',
                    style: AppTypography.body2, overflow: TextOverflow.ellipsis)),
                if (widget.jadwal.kodeKelas != null && !_hasMultiKelas) ...[
                  const SizedBox(width: 6),
                  KelasBadge(kodeKelas: widget.jadwal.kodeKelas!),
                ],
              ],
            ),
            if (widget.jadwal.adaJadwalPengganti) ...[
              const SizedBox(height: 10),
              _JadwalPenggantiAlert(jadwal: widget.jadwal),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
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
                  border: Border.all(color: AppColors.kSoftGray, width: 1)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value    : _selectedKelas,
                    isExpanded: true,
                    hint     : Text('Pilih kelas...', style: AppTypography.body2),
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
                                style   : AppTypography.body2.copyWith(fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedKelas = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _InfoRow(
              label: 'Pertemuan ke',
              value: widget.jadwal.pertemuanKe != null
                  ? '${widget.jadwal.pertemuanKe}' : 'Tidak tersedia'),
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
                            ? 'Dari jam jadwal (${widget.jadwal.jamMulai ?? "-"})'
                            : 'Dari sekarang',
                        style: AppTypography.body2.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value    : _mulaiDariJadwal,
                  onChanged: (v) => setState(() => _mulaiDariJadwal = v),
                  activeColor: AppColors.kNavy),
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
            Text('Toleransi Terlambat',
              style: AppTypography.bodyBold.copyWith(
                color: AppColors.kNavy, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: _opsiTerlambat.map((v) => ChoiceChip(
                label    : Text(_labelTerlambat(v), style: AppTypography.caption),
                selected : _batasTerlambat == v,
                onSelected: (_) => setState(() => _batasTerlambat = v),
                selectedColor: AppColors.kNavy,
                labelStyle: TextStyle(
                  color: _batasTerlambat == v
                      ? Colors.white : AppColors.kTextPrimary),
              )).toList(),
            ),
            if (_mode == 'online') ...[
              const SizedBox(height: 16),
              Text('Durasi Kode Aktif',
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.kNavy, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: _opsiDurasi.map((v) => ChoiceChip(
                  label    : Text('$v mnt', style: AppTypography.caption),
                  selected : _durasiKode == v,
                  onSelected: (_) => setState(() => _durasiKode = v),
                  selectedColor: const Color(0xFF7C3AED),
                  labelStyle: TextStyle(
                    color: _durasiKode == v
                        ? Colors.white : AppColors.kTextPrimary),
                )).toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child : ElevatedButton.icon(
                onPressed: (_isLoading ||
                    widget.jadwal.pertemuanKe == null ||
                    (_hasMultiKelas && _selectedKelas == null))
                    ? null : _bukaSesi,
                icon : _isLoading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_circle_rounded, size: 22),
                label: Text(
                  _isLoading ? 'Membuka...'
                      : _mode == 'online'
                          ? 'Buka Sesi & Generate Kode'
                          : 'Buka Sesi Tatap Muka',
                  style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mode == 'online'
                      ? const Color(0xFF7C3AED) : AppColors.kNavy,
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
// WIDGET HELPERS
// ══════════════════════════════════════════════════════════════

class _KodePill extends StatelessWidget {
  final String kode;
  final bool   small;
  const _KodePill({required this.kode, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 6 : 8, vertical: small ? 1 : 2),
    decoration: BoxDecoration(
      color       : AppColors.kNavy.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6)),
    child: Text(kode,
      style: AppTypography.badge.copyWith(
        color: AppColors.kNavy, fontSize: small ? 9 : 11)),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   showPulse;
  const _StatusBadge({
    required this.label, required this.color, this.showPulse = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPulse) ...[
          _PulseDot(color: color), const SizedBox(width: 4)],
        Text(label,
          style: AppTypography.badge.copyWith(color: color, fontSize: 10)),
      ],
    ),
  );
}

class _JamRuanganRow extends StatelessWidget {
  final JadwalDosenItem jadwal;
  const _JamRuanganRow({required this.jadwal});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
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
      Icon(Icons.room_outlined, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Expanded(
        child: Text(jadwal.labelRuangan,
          style   : AppTypography.body2.copyWith(fontSize: 12),
          overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _JadwalPenggantiAlert extends StatelessWidget {
  final JadwalDosenItem jadwal;
  final bool            compact;
  const _JadwalPenggantiAlert({required this.jadwal, this.compact = false});

  String get _detail {
    final parts = <String>[];
    if (jadwal.jamMulaiPengganti != null && jadwal.jamSelesaiPengganti != null)
      parts.add('${jadwal.jamMulaiPengganti} – ${jadwal.jamSelesaiPengganti}');
    if (jadwal.ruanganPengganti != null) parts.add(jadwal.ruanganPengganti!);
    if (jadwal.modePengganti != null)
      parts.add(jadwal.modePengganti!.toLowerCase() == 'online'
          ? '💻 Online' : '📍 Tatap Muka');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: 10, vertical: compact ? 6 : 8),
    decoration: BoxDecoration(
      color: AppColors.kGold.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border(
        left: BorderSide(color: AppColors.kGold, width: 3))),
    child: Row(
      children: [
        Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.kWarning),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jadwal Pengganti',
                style: AppTypography.badge.copyWith(
                  color      : AppColors.kWarning,
                  fontSize   : 10,
                  fontWeight : FontWeight.w700)),
              if (_detail.isNotEmpty)
                Text(_detail,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.kTextSecondary)),
            ],
          ),
        ),
        if (jadwal.modePengganti != null)
          ModeBadge(
            mode    : jadwal.modePengganti!,
            fontSize: 9,
            padding : const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
      ],
    ),
  );
}

class _KodeCountdownBar extends StatelessWidget {
  final String               kodeSesi;
  final int                  countdownDetik;
  final String Function(int) formatCountdown;
  const _KodeCountdownBar({
    required this.kodeSesi,
    required this.countdownDetik,
    required this.formatCountdown});

  @override
  Widget build(BuildContext context) => Container(
    margin : const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.kNavy.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.kNavy.withOpacity(0.1))),
    child: Row(
      children: [
        const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.kNavy),
        const SizedBox(width: 8),
        Text('Kode: ', style: AppTypography.body2.copyWith(fontSize: 13)),
        Text(kodeSesi, style: AppTypography.kodeSmall),
        const Spacer(),
        Icon(Icons.timer_outlined,
          size : 14,
          color: countdownDetik < 300
              ? AppColors.kDanger : AppColors.kGreen),
        const SizedBox(width: 4),
        Text(formatCountdown(countdownDetik),
          style: AppTypography.label.copyWith(
            color      : countdownDetik < 300
                ? AppColors.kDanger : AppColors.kGreen,
            fontWeight : FontWeight.bold,
            fontSize   : 13)),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;
  const _InfoChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
      style: AppTypography.badge.copyWith(color: color, fontSize: 11)),
  );
}

class _ChipButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onPressed;
  const _ChipButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.30), width: 1)),
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

// FIX 2: _ActionBtn — hapus minimumSize: double.infinity agar tidak
// crash saat dipakai tanpa Expanded di sekitarnya.
// Sekarang parent yang bertanggung jawab memberi constraint width.
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
    required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // FIX 2: Tidak pakai double.infinity untuk minimumSize.
    // Parent (Expanded) akan memberikan width yang tepat.
    const btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)));

    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon : Icon(icon, size: 16),
        label: Text(label, style: AppTypography.buttonSmall),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          // FIX 2: minimumSize tanpa double.infinity
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: btnShape),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon : Icon(icon, size: 16),
      label: Text(label, style: AppTypography.buttonSmall),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        // FIX 2: minimumSize tanpa double.infinity
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: btnShape),
    );
  }
}

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

class _ModeChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
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
      width : 7, height: 7,
      decoration: BoxDecoration(
        color: widget.color, shape: BoxShape.circle)),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle});

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
            style: AppTypography.body2, textAlign: TextAlign.center),
        ],
      ),
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
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Gagal memuat jadwal',
            style: AppTypography.heading3.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center, style: AppTypography.body2),
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