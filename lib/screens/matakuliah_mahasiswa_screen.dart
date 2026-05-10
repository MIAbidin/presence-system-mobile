// lib/screens/matakuliah_mahasiswa_screen.dart
// v2.1.0 — Fase 4.3 SELESAI
//
// BARU: Halaman daftar matakuliah mandiri mahasiswa.
// Endpoint:
//   GET  /mahasiswa/matakuliah              — list MK terdaftar
//   GET  /matakuliah/semua                  — semua MK aktif (untuk browse)
//   POST /mahasiswa/matakuliah/{mk_id}/daftar — daftar ke MK
//   DELETE /mahasiswa/matakuliah/{mk_id}    — keluar dari MK
//
// Fitur:
//   Tab 'Terdaftar' : list MK yang diambil + badge kelas + dosen + % kehadiran
//   Tab 'Cari MK'   : search + browse + daftar ke kelas yang tersedia

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/ums_app_bar.dart';
import 'package:presensi_app/widgets/empty_error_state.dart';

// ══════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════

/// MK yang sudah diambil mahasiswa
class MatakuliahTerdaftarModel {
  final String  matakuliahId;
  final String  kode;
  final String  nama;
  final int     sks;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final String? kodeKelas;
  final String? kelasId;
  final String? dosenNama;
  final int     totalSesi;
  final int     hadirEfektif;
  final double  persentaseHadir;
  final bool    isTamu;

  const MatakuliahTerdaftarModel({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    this.kodeKelas,
    this.kelasId,
    this.dosenNama,
    required this.totalSesi,
    required this.hadirEfektif,
    required this.persentaseHadir,
    this.isTamu = false,
  });

  factory MatakuliahTerdaftarModel.fromJson(Map<String, dynamic> json) =>
      MatakuliahTerdaftarModel(
        matakuliahId   : json['matakuliah_id']    as String,
        kode           : json['kode']             as String,
        nama           : json['nama']             as String,
        sks            : json['sks']              as int,
        hari           : json['hari']             as String?,
        jamMulai       : json['jam_mulai']        as String?,
        jamSelesai     : json['jam_selesai']      as String?,
        ruangan        : json['ruangan']          as String?,
        kodeKelas      : json['kode_kelas']       as String?,
        kelasId        : json['kelas_id']         as String?,
        dosenNama      : json['dosen_nama']       as String?,
        totalSesi      : json['total_sesi']       as int? ?? 0,
        hadirEfektif   : json['hadir_efektif']    as int? ?? 0,
        persentaseHadir: (json['persentase_hadir'] as num?)?.toDouble() ?? 0.0,
        isTamu         : json['is_tamu']          as bool? ?? false,
      );

  String get labelJam =>
      (jamMulai != null && jamSelesai != null)
          ? '$jamMulai – $jamSelesai'
          : '-';
}

/// Kelas dalam MK yang tersedia untuk didaftarkan
class KelasAvailableModel {
  final String kelasId;
  final String kodeKelas;
  final String? dosenNama;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final int     enrolled;
  final int?    kapasitas;
  final bool    izinTamu;

  const KelasAvailableModel({
    required this.kelasId,
    required this.kodeKelas,
    this.dosenNama,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    required this.enrolled,
    this.kapasitas,
    this.izinTamu = false,
  });

  factory KelasAvailableModel.fromJson(Map<String, dynamic> json) =>
      KelasAvailableModel(
        kelasId  : json['kelas_id']   as String? ?? json['id'] as String? ?? '',
        kodeKelas: json['kode_kelas'] as String? ?? '',
        dosenNama: json['dosen_nama'] as String?,
        hari     : json['hari']       as String?,
        jamMulai : json['jam_mulai']  as String?,
        jamSelesai: json['jam_selesai'] as String?,
        ruangan  : json['ruangan']    as String?,
        enrolled : json['enrolled']   as int? ?? json['jumlah_mahasiswa'] as int? ?? 0,
        kapasitas: json['kapasitas']  as int?,
        izinTamu : json['izin_tamu']  as bool? ?? false,
      );

  int get sisaSlot => kapasitas != null ? kapasitas! - enrolled : -1;
  bool get penuh   => kapasitas != null && enrolled >= kapasitas!;

  String get labelJam =>
      (jamMulai != null && jamSelesai != null)
          ? '$jamMulai – $jamSelesai'
          : '-';
}

/// MK yang tersedia untuk di-browse
class MatakuliahAvailableModel {
  final String matakuliahId;
  final String kode;
  final String nama;
  final int    sks;
  final List<KelasAvailableModel> kelasList;
  final bool   sudahDaftar;

  const MatakuliahAvailableModel({
    required this.matakuliahId,
    required this.kode,
    required this.nama,
    required this.sks,
    required this.kelasList,
    this.sudahDaftar = false,
  });

  factory MatakuliahAvailableModel.fromJson(Map<String, dynamic> json) {
    final kelasList = (json['kelas_list'] as List<dynamic>? ?? [])
        .map((e) => KelasAvailableModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return MatakuliahAvailableModel(
      matakuliahId: json['matakuliah_id'] as String? ?? json['id'] as String,
      kode        : json['kode']          as String,
      nama        : json['nama']          as String,
      sks         : json['sks']           as int,
      kelasList   : kelasList,
      sudahDaftar : json['sudah_daftar']  as bool? ?? false,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════

class MatakuliahMahasiswaScreen extends StatefulWidget {
  const MatakuliahMahasiswaScreen({super.key});

  @override
  State<MatakuliahMahasiswaScreen> createState() =>
      _MatakuliahMahasiswaScreenState();
}

class _MatakuliahMahasiswaScreenState extends State<MatakuliahMahasiswaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned         : true,
            expandedHeight : 110,
            backgroundColor: AppColors.kNavy,
            foregroundColor: Colors.white,
            elevation      : 0,
            flexibleSpace  : FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.kNavyGradient,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 2,
                        color : AppColors.kGold.withOpacity(0.5),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child  : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matakuliah Saya',
                              style: AppTypography.hero.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kelola matakuliah yang kamu ikuti',
                              style: AppTypography.heroSubtitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon     : const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: TabBar(
              controller         : _tabController,
              indicatorColor     : AppColors.kGold,
              indicatorWeight    : 3,
              labelColor         : Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: AppTypography.bodyBold.copyWith(color: Colors.white),
              unselectedLabelStyle: AppTypography.body2.copyWith(
                  color: Colors.white54),
              tabs: const [
                Tab(text: 'Terdaftar'),
                Tab(text: 'Cari MK'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children  : [
            _TerdaftarTab(
              onDaftarBerhasil: () => _tabController.animateTo(0),
            ),
            _CariMKTab(
              onDaftarBerhasil: () => _tabController.animateTo(0),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 1 — TERDAFTAR
// ══════════════════════════════════════════════════════════════

class _TerdaftarTab extends StatefulWidget {
  final VoidCallback onDaftarBerhasil;
  const _TerdaftarTab({required this.onDaftarBerhasil});

  @override
  State<_TerdaftarTab> createState() => _TerdaftarTabState();
}

class _TerdaftarTabState extends State<_TerdaftarTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool   _isLoading = true;
  String? _error;
  List<MatakuliahTerdaftarModel> _list = [];

  @override
  void initState() {
    super.initState();
    _fetchTerdaftar();
  }

  Future<void> _fetchTerdaftar() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await ApiClient().get('/mahasiswa/matakuliah');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawList = data is List
            ? data
            : (data['matakuliah_list'] as List<dynamic>? ?? []);
        setState(() {
          _list = rawList
              .map((e) => MatakuliahTerdaftarModel.fromJson(
                      e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _error = err['detail'] ?? 'Gagal memuat matakuliah';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = 'Tidak dapat terhubung ke server';
        _isLoading = false;
      });
    }
  }

  Future<void> _keluarMK(MatakuliahTerdaftarModel mk) async {
    final konfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded,
                color: AppColors.kDanger, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keluar dari Matakuliah?',
                style: AppTypography.heading3.copyWith(
                    color: AppColors.kNavy, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${mk.nama} (${mk.kode})',
              style: AppTypography.bodyBold,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kDanger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Riwayat presensi yang sudah tercatat tidak akan dihapus.',
                style: AppTypography.body2.copyWith(
                    color: AppColors.kDanger, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kDanger,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );

    if (konfirm != true) return;

    try {
      final response =
          await ApiClient().delete('/mahasiswa/matakuliah/${mk.matakuliahId}');
      if (response.statusCode == 200) {
        _showSnack('Berhasil keluar dari ${mk.nama}');
        await _fetchTerdaftar();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal keluar dari MK', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? AppColors.kDanger : AppColors.kGreen,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ShimmerList(count: 4, cardHeight: 140),
      );
    }
    if (_error != null) {
      return ErrorState(message: _error, onRetry: _fetchTerdaftar);
    }
    if (_list.isEmpty) {
      return EmptyState(
        icon    : Icons.menu_book_outlined,
        title   : 'Belum Ada Matakuliah',
        subtitle: 'Kamu belum terdaftar di matakuliah manapun.\nCari dan daftar dari tab "Cari MK".',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTerdaftar,
      color    : AppColors.kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount  : _list.length,
        itemBuilder: (ctx, i) => _MKTerdaftarCard(
          mk    : _list[i],
          onKeluar: () => _keluarMK(_list[i]),
        ),
      ),
    );
  }
}

// ─── Card MK Terdaftar ────────────────────────────────────────

class _MKTerdaftarCard extends StatelessWidget {
  final MatakuliahTerdaftarModel mk;
  final VoidCallback             onKeluar;

  const _MKTerdaftarCard({required this.mk, required this.onKeluar});

  Color get _barColor => AppColors.persentaseColor(mk.persentaseHadir);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin    : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        boxShadow   : AppDecorations.cardShadow,
        border      : mk.isTamu
            ? Border.all(
                color: AppColors.kWarning.withOpacity(0.40), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: kode + kelas + tamu badge + menu ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris kode + badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.kNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mk.kode,
                              style: AppTypography.badge.copyWith(
                                color  : AppColors.kNavy,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (mk.kodeKelas != null) ...[
                            const SizedBox(width: 6),
                            KelasBadge(kodeKelas: mk.kodeKelas!),
                          ],
                          if (mk.isTamu) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.kWarning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.kWarning.withOpacity(0.40)),
                              ),
                              child: Text(
                                'Tamu',
                                style: AppTypography.badge.copyWith(
                                    color: AppColors.kWarning, fontSize: 9),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Nama MK
                      Text(
                        mk.nama,
                        style: AppTypography.bodyBold.copyWith(
                            color: AppColors.kNavyDark, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      // SKS
                      Text(
                        '${mk.sks} SKS',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                // Menu keluar
                PopupMenuButton<String>(
                  onSelected: (v) { if (v == 'keluar') onKeluar(); },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'keluar',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app_rounded,
                              color: AppColors.kDanger, size: 18),
                          SizedBox(width: 8),
                          Text('Keluar dari MK',
                              style: TextStyle(color: AppColors.kDanger)),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.kTextSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Info jadwal ──────────────────────────────────
            if (mk.hari != null || mk.dosenNama != null) ...[
              Wrap(
                spacing: 14, runSpacing: 6,
                children: [
                  if (mk.hari != null)
                    _InfoItem(
                      icon : Icons.calendar_today_outlined,
                      label: mk.hari!,
                    ),
                  if (mk.jamMulai != null)
                    _InfoItem(
                      icon : Icons.access_time_outlined,
                      label: mk.labelJam,
                    ),
                  if (mk.ruangan != null)
                    _InfoItem(
                      icon : Icons.room_outlined,
                      label: mk.ruangan!,
                    ),
                  if (mk.dosenNama != null)
                    _InfoItem(
                      icon : Icons.person_outline_rounded,
                      label: mk.dosenNama!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Progress kehadiran ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kehadiran',
                  style: AppTypography.label.copyWith(
                      color: AppColors.kTextSecondary),
                ),
                Text(
                  '${mk.hadirEfektif}/${mk.totalSesi} sesi  ·  '
                  '${mk.persentaseHadir.toStringAsFixed(1)}%',
                  style: AppTypography.label.copyWith(
                    color     : _barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value          : mk.totalSesi > 0
                    ? (mk.hadirEfektif / mk.totalSesi).clamp(0.0, 1.0)
                    : 0.0,
                backgroundColor: AppColors.kSoftGray,
                valueColor     : AlwaysStoppedAnimation(_barColor),
                minHeight      : 8,
              ),
            ),
            if (mk.persentaseHadir < 75 && mk.totalSesi > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 12, color: AppColors.kWarning),
                  const SizedBox(width: 4),
                  Text(
                    'Kehadiran di bawah 75% — perlu perhatian',
                    style: AppTypography.caption.copyWith(
                        color: AppColors.kWarning),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.kTextSecondary),
      const SizedBox(width: 4),
      Text(
        label,
        style: AppTypography.caption,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
// TAB 2 — CARI MK
// ══════════════════════════════════════════════════════════════

class _CariMKTab extends StatefulWidget {
  final VoidCallback onDaftarBerhasil;
  const _CariMKTab({required this.onDaftarBerhasil});

  @override
  State<_CariMKTab> createState() => _CariMKTabState();
}

class _CariMKTabState extends State<_CariMKTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();

  bool   _isLoading = true;
  String? _error;
  List<MatakuliahAvailableModel> _allList      = [];
  List<MatakuliahAvailableModel> _filteredList = [];

  // Track MK yang sedang proses daftar (loading per card)
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSemua();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSemua() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await ApiClient().get('/matakuliah/semua');
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final list = raw is List
            ? raw
            : (raw['matakuliah_list'] as List<dynamic>? ?? []);
        setState(() {
          _allList = list
              .map((e) => MatakuliahAvailableModel.fromJson(
                      e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
        _applyFilter();
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _error = err['detail'] ?? 'Gagal memuat daftar MK';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = 'Tidak dapat terhubung ke server';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredList = q.isEmpty
          ? List.from(_allList)
          : _allList
              .where((mk) =>
                  mk.nama.toLowerCase().contains(q) ||
                  mk.kode.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _daftar(
      MatakuliahAvailableModel mk, KelasAvailableModel kelas) async {
    if (_loadingIds.contains(mk.matakuliahId)) return;
    setState(() => _loadingIds.add(mk.matakuliahId));

    try {
      final response = await ApiClient().post(
        '/mahasiswa/matakuliah/${mk.matakuliahId}/daftar',
        body: {'kelas_id': kelas.kelasId},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnack('Berhasil mendaftar ke ${mk.nama} Kelas ${kelas.kodeKelas}');
        // Update sudahDaftar secara lokal
        setState(() {
          final idx = _allList.indexWhere(
              (m) => m.matakuliahId == mk.matakuliahId);
          if (idx >= 0) {
            _allList[idx] = MatakuliahAvailableModel(
              matakuliahId: _allList[idx].matakuliahId,
              kode        : _allList[idx].kode,
              nama        : _allList[idx].nama,
              sks         : _allList[idx].sks,
              kelasList   : _allList[idx].kelasList,
              sudahDaftar : true,
            );
          }
        });
        _applyFilter();
        widget.onDaftarBerhasil();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal mendaftar', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loadingIds.remove(mk.matakuliahId));
    }
  }

  void _showPilihKelasDialog(MatakuliahAvailableModel mk) {
    showModalBottomSheet(
      context           : context,
      isScrollControlled: true,
      backgroundColor   : Colors.transparent,
      builder: (ctx) => _PilihKelasSheet(
        mk     : mk,
        onDaftar: (kelas) {
          Navigator.pop(ctx);
          _daftar(mk, kelas);
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? AppColors.kDanger : AppColors.kGreen,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // ── Search bar ────────────────────────────────────
        Container(
          color  : AppColors.kSurface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child  : TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText : 'Cari nama atau kode matakuliah...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon    : const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilter();
                      })
                  : null,
              filled    : true,
              fillColor : AppColors.kBgLight,
              border    : OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide  : BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Divider(height: 1),

        // ── Jumlah hasil ──────────────────────────────────
        if (!_isLoading && _error == null)
          Container(
            color  : AppColors.kSurface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child  : Row(
              children: [
                Text(
                  '${_filteredList.length} matakuliah ditemukan',
                  style: AppTypography.label.copyWith(
                      color: AppColors.kTextSecondary),
                ),
              ],
            ),
          ),

        // ── List ──────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShimmerList(count: 4, cardHeight: 120),
                )
              : _error != null
                  ? ErrorState(message: _error, onRetry: _fetchSemua)
                  : _filteredList.isEmpty
                      ? EmptyState(
                          icon    : Icons.search_off_rounded,
                          title   : 'Tidak Ditemukan',
                          subtitle: 'Coba kata kunci yang berbeda',
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchSemua,
                          color    : AppColors.kNavy,
                          child    : ListView.builder(
                            padding    : const EdgeInsets.fromLTRB(
                                16, 12, 16, 32),
                            itemCount  : _filteredList.length,
                            itemBuilder: (ctx, i) => _MKAvailableCard(
                              mk       : _filteredList[i],
                              isLoading: _loadingIds.contains(
                                  _filteredList[i].matakuliahId),
                              onDaftar : () =>
                                  _showPilihKelasDialog(_filteredList[i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ─── Card MK Tersedia ─────────────────────────────────────────

class _MKAvailableCard extends StatelessWidget {
  final MatakuliahAvailableModel mk;
  final bool                     isLoading;
  final VoidCallback             onDaftar;

  const _MKAvailableCard({
    required this.mk,
    required this.isLoading,
    required this.onDaftar,
  });

  @override
  Widget build(BuildContext context) {
    final sudahDaftar = mk.sudahDaftar;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        boxShadow   : AppDecorations.cardShadow,
        border      : sudahDaftar
            ? Border.all(
                color: AppColors.kGreen.withOpacity(0.40), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kode MK + SKS
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.kNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mk.kode,
                              style: AppTypography.badge.copyWith(
                                  color: AppColors.kNavy, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${mk.sks} SKS',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        mk.nama,
                        style: AppTypography.bodyBold.copyWith(
                            color: AppColors.kNavyDark, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Badge sudah daftar / tombol daftar
                if (sudahDaftar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.kGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.kGreen.withOpacity(0.40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 14, color: AppColors.kGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Terdaftar',
                          style: AppTypography.badge.copyWith(
                              color: AppColors.kGreen, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 34,
                    child : ElevatedButton(
                      onPressed: isLoading ? null : onDaftar,
                      style    : ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Daftar',
                              style: AppTypography.buttonSmall.copyWith(
                                  color: Colors.white, fontSize: 12)),
                    ),
                  ),
              ],
            ),

            // ── List kelas tersedia ──────────────────────────
            if (mk.kelasList.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Kelas tersedia:',
                style: AppTypography.label.copyWith(
                    color: AppColors.kTextSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: mk.kelasList.map((kelas) {
                  return _KelasPill(kelas: kelas);
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Belum ada kelas yang dibuka',
                style: AppTypography.caption.copyWith(
                    color: AppColors.kTextSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill info kelas (Kelas A, B, C) pada card browse
class _KelasPill extends StatelessWidget {
  final KelasAvailableModel kelas;
  const _KelasPill({required this.kelas});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.kelasColor(kelas.kodeKelas);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kelas ${kelas.kodeKelas}',
            style: AppTypography.badge.copyWith(color: color, fontSize: 11),
          ),
          if (kelas.kapasitas != null) ...[
            const SizedBox(width: 6),
            Text(
              '${kelas.enrolled}/${kelas.kapasitas}',
              style: AppTypography.badge.copyWith(
                color   : kelas.penuh ? AppColors.kDanger : AppColors.kTextSecondary,
                fontSize: 10,
              ),
            ),
          ],
          if (kelas.penuh) ...[
            const SizedBox(width: 4),
            const Icon(Icons.block_rounded, size: 10, color: AppColors.kDanger),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTTOM SHEET — Pilih Kelas untuk Daftar
// ══════════════════════════════════════════════════════════════

class _PilihKelasSheet extends StatelessWidget {
  final MatakuliahAvailableModel mk;
  final void Function(KelasAvailableModel) onDaftar;

  const _PilihKelasSheet({required this.mk, required this.onDaftar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left  : 24, right: 24, top: 8,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize      : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width : 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color       : AppColors.kSoftGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Text(
            'Pilih Kelas',
            style: AppTypography.heading3.copyWith(color: AppColors.kNavy),
          ),
          const SizedBox(height: 4),
          Text(
            '${mk.nama} (${mk.kode})',
            style: AppTypography.body2,
          ),
          const SizedBox(height: 20),

          // Jika tidak ada kelas
          if (mk.kelasList.isEmpty)
            const EmptyState(
              icon    : Icons.class_outlined,
              title   : 'Belum Ada Kelas',
              subtitle: 'Hubungi admin untuk membuka kelas.',
            )
          else
            ...mk.kelasList.map((kelas) => _KelasOptionTile(
              kelas  : kelas,
              onTap  : kelas.penuh ? null : () => onDaftar(kelas),
            )),
        ],
      ),
    );
  }
}

class _KelasOptionTile extends StatelessWidget {
  final KelasAvailableModel kelas;
  final VoidCallback?       onTap;

  const _KelasOptionTile({required this.kelas, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color   = AppColors.kelasColor(kelas.kodeKelas);
    final disabled = onTap == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child : InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding   : const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.kSoftGray.withOpacity(0.5)
                : color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled
                  ? AppColors.kSoftGray
                  : color.withOpacity(0.30),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Badge kelas
              Container(
                width : 40, height: 40,
                decoration: BoxDecoration(
                  color       : color.withOpacity(disabled ? 0.05 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    kelas.kodeKelas,
                    style: AppTypography.heading3.copyWith(
                      color  : disabled ? AppColors.kTextSecondary : color,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info kelas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelas ${kelas.kodeKelas}',
                      style: AppTypography.bodyBold.copyWith(
                        color: disabled ? AppColors.kTextSecondary : color,
                      ),
                    ),
                    if (kelas.dosenNama != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 11, color: AppColors.kTextSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              kelas.dosenNama!,
                              style: AppTypography.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (kelas.jamMulai != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_outlined,
                              size: 11, color: AppColors.kTextSecondary),
                          const SizedBox(width: 3),
                          Text(
                            '${kelas.hari != null ? "${kelas.hari}  " : ""}'
                            '${kelas.labelJam}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Sisa slot / penuh
              if (kelas.kapasitas != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      disabled ? 'Penuh' : '${kelas.sisaSlot} slot',
                      style: AppTypography.badge.copyWith(
                        color: disabled
                            ? AppColors.kDanger
                            : AppColors.kGreen,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${kelas.enrolled}/${kelas.kapasitas}',
                      style: AppTypography.caption,
                    ),
                  ],
                )
              else
                Icon(
                  disabled
                      ? Icons.block_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size : 16,
                  color: disabled
                      ? AppColors.kDanger
                      : color.withOpacity(0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}