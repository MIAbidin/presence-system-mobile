// lib/screens/jadwal_screen.dart
// v2.1.0 — Fase 2: Update JadwalScreen
// Perubahan:
// Tab Hari Ini:
// - Kartu jadwal: badge kelas dan slot waktu 'Kelas A | Slot 1-2 | 07:00-08:40'
// - Kartu jadwal: tampilkan nama dosen pengampu kelas mahasiswa ini
// - Banner jadwal pengganti: jam baru, ruangan baru, MODE baru (Offline/Online)
// - Badge 'Tamu' jika mahasiswa masuk via izin tamu
//
// Tab Mingguan:
// - Setiap item: kode kelas + slot waktu
// - Accordion: badge jumlah kelas
// - Indikator perubahan jadwal pengganti

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/constants.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/models/jadwal.dart';
import 'package:presensi_app/models/kelas.dart';
import 'package:presensi_app/services/slot_service.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/slot_label.dart';
import 'package:presensi_app/widgets/empty_error_state.dart';

const List<String> _hariList = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {

  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  // ── Jadwal hari ini ───────────────────────────────────────
  List<JadwalModel> _jadwalHariIni      = [];
  bool              _isLoadingHariIni   = true;
  String?           _errorHariIni;

  // ── Jadwal mingguan ───────────────────────────────────────
  Map<String, List<JadwalModel>> _jadwalMingguan = {};
  bool              _isLoadingMingguan  = true;
  String?           _errorMingguan;
  String?           _expandedHari;

  // ── Slot options (sudah di-cache oleh SlotService) ────────
  List<SlotOption> _slotOptions = SlotDefaults.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSlots();
    _fetchHariIni();
    _fetchMingguan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load slot options ─────────────────────────────────────
  Future<void> _initSlots() async {
    final slots = await SlotService().getSlotOptions();
    if (mounted) setState(() => _slotOptions = slots);
  }

  // ── Fetch jadwal hari ini ─────────────────────────────────
  Future<void> _fetchHariIni() async {
    setState(() { _isLoadingHariIni = true; _errorHariIni = null; });
    try {
      final response = await ApiClient().get('/jadwal/hari-ini');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _jadwalHariIni = list
              .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() => _errorHariIni = err['detail'] ?? 'Gagal memuat jadwal');
      }
    } catch (e) {
      setState(() => _errorHariIni = 'Tidak dapat terhubung ke server');
    } finally {
      setState(() => _isLoadingHariIni = false);
    }
  }

  // ── Fetch jadwal mingguan ─────────────────────────────────
  Future<void> _fetchMingguan() async {
    setState(() { _isLoadingMingguan = true; _errorMingguan = null; });
    try {
      final response = await ApiClient().get('/jadwal/mingguan');
      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body) as Map<String, dynamic>;
        final grouped = <String, List<JadwalModel>>{};
        data.forEach((hari, list) {
          grouped[hari] = (list as List<dynamic>)
              .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        setState(() {
          _jadwalMingguan = grouped;
          _expandedHari   = _namaHariIni();
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() => _errorMingguan = err['detail'] ?? 'Gagal memuat jadwal');
      }
    } catch (e) {
      setState(() => _errorMingguan = 'Tidak dapat terhubung ke server');
    } finally {
      setState(() => _isLoadingMingguan = false);
    }
  }

  String _namaHariIni() {
    return AppConstants.namaHariDariWeekday(DateTime.now().weekday);
  }

  // ── Helper: label slot dari slotMulai/slotSelesai ─────────
  String _slotRangeLabel(int? slotMulai, int? slotSelesai) {
    if (slotMulai == null) return '';
    final selesai = slotSelesai ?? slotMulai;
    final jamMulai   = SlotOption.rangeLabel(slotMulai, selesai, _slotOptions)
        .split(' – ')
        .first;
    final jamSelesai = SlotOption.rangeLabel(slotMulai, selesai, _slotOptions)
        .split(' – ')
        .last;
    return 'Slot $slotMulai–$selesai  |  $jamMulai – $jamSelesai';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned         : true,
            expandedHeight : 130,
            backgroundColor: AppColors.kNavy,
            automaticallyImplyLeading: false,
            elevation      : 0,
            flexibleSpace  : FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.kNavyGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal Kuliah',
                          style: AppTypography.hero.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                              .format(DateTime.now()),
                          style: AppTypography.heroSubtitle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller         : _tabController,
              indicatorColor     : AppColors.kGold,
              indicatorWeight    : 3,
              labelColor         : Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle         : AppTypography.bodyBold.copyWith(
                color: Colors.white),
              unselectedLabelStyle: AppTypography.body2.copyWith(
                color: Colors.white54),
              tabs: const [
                Tab(text: 'Hari Ini'),
                Tab(text: 'Mingguan'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children  : [
            _buildHariIniTab(),
            _buildMingguanTab(),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 1: Jadwal Hari Ini
  // ────────────────────────────────────────────────────────────

  Widget _buildHariIniTab() {
    if (_isLoadingHariIni) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.kNavy),
      );
    }
    if (_errorHariIni != null) {
      return ErrorState(
        message: _errorHariIni,
        onRetry : _fetchHariIni,
      );
    }
    if (_jadwalHariIni.isEmpty) {
      return const EmptyState(
        icon    : Icons.event_available_outlined,
        title   : 'Tidak Ada Jadwal Hari Ini',
        subtitle: 'Nikmati hari libur kuliah kamu 🎉',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHariIni,
      color    : AppColors.kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount  : _jadwalHariIni.length,
        itemBuilder: (ctx, i) => _JadwalHariIniCard(
          jadwal      : _jadwalHariIni[i],
          slotOptions : _slotOptions,
          onPresensi  : () => context.go('/scan'),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // TAB 2: Jadwal Mingguan
  // ────────────────────────────────────────────────────────────

  Widget _buildMingguanTab() {
    if (_isLoadingMingguan) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.kNavy),
      );
    }
    if (_errorMingguan != null) {
      return ErrorState(
        message: _errorMingguan,
        onRetry : _fetchMingguan,
      );
    }

    final hariIni = _namaHariIni();

    return RefreshIndicator(
      onRefresh: _fetchMingguan,
      color    : AppColors.kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount  : _hariList.length,
        itemBuilder: (ctx, i) {
          final hari   = _hariList[i];
          final items  = _jadwalMingguan[hari] ?? [];
          final isToday = hari == hariIni;
          final isOpen  = _expandedHari == hari;

          return _HariAccordion(
            hari        : hari,
            items       : items,
            isToday     : isToday,
            isExpanded  : isOpen,
            slotOptions : _slotOptions,
            onTap       : () => setState(() =>
                _expandedHari = isOpen ? null : hari),
            onPresensi  : () => context.go('/scan'),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// [DIPERBARUI v2.1.0] Kartu Jadwal Hari Ini
// ─────────────────────────────────────────────────────────────

class _JadwalHariIniCard extends StatelessWidget {
  final JadwalModel    jadwal;
  final List<SlotOption> slotOptions;
  final VoidCallback   onPresensi;

  const _JadwalHariIniCard({
    required this.jadwal,
    required this.slotOptions,
    required this.onPresensi,
  });

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
    final color         = _statusColor();
    final sesiAktif     = jadwal.adaSesiAktif;
    final sudahPresensi = jadwal.sudahPresensi;
    // Label jam slot (jika ada data slot)
    final labelSlot = jadwal.slotMulai != null
        ? SlotOption.rangeLabel(
            jadwal.slotMulai!,
            jadwal.slotSelesai ?? jadwal.slotMulai!,
            slotOptions,
          )
        : jadwal.labelJam;

    return Container(
      margin    : const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(16),
        border      : sesiAktif && !sudahPresensi
            ? Border.all(
                color: AppColors.kNavy.withOpacity(0.30), width: 1.5)
            : null,
        boxShadow   : AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header kartu ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child  : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Garis vertikal status
                Container(
                  width     : 4,
                  height    : 70,
                  decoration: BoxDecoration(
                    color       : color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Baris 1: kode MK + badge kelas + badge tamu ──
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
                                color  : AppColors.kNavy,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          // ── [BARU] Badge kelas A/B/C ─────
                          if (jadwal.kodeKelas != null &&
                              jadwal.kodeKelas!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            KelasBadge(kodeKelas: jadwal.kodeKelas!),
                          ],
                          // ── [BARU] Badge tamu ────────────
                          if (jadwal.isTamu) ...[
                            const SizedBox(width: 6),
                            const TamuBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // ── Baris 2: nama MK ─────────────────
                      Text(
                        jadwal.nama,
                        style: AppTypography.bodyBold.copyWith(
                          color  : AppColors.kNavyDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // ── [BARU] Baris 3: nama dosen ────────
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
                        const SizedBox(height: 5),
                      ],

                      // ── [BARU] Baris 4: slot waktu + ruangan ─
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size : 12,
                            color: AppColors.kTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          // Prioritas slot, fallback ke jam langsung
                          if (jadwal.slotMulai != null)
                            Flexible(
                              child: SlotLabel(
                                slotMulai  : jadwal.slotMulai,
                                slotSelesai: jadwal.slotSelesai,
                                fontSize   : 12,
                              ),
                            )
                          else
                            Text(
                              labelSlot,
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
                            Flexible(
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
                // Badge status presensi
                StatusPresensiiBadge(
                  status  : jadwal.statusPresensi ?? '',
                  fontSize: 10,
                ),
              ],
            ),
          ),

          // ── [BARU] Banner jadwal pengganti ───────────────
          if (jadwal.adaJadwalPengganti) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child  : JadwalPenggantiAlert(
                jamMulai  : jadwal.jamMulaiPengganti,
                jamSelesai: jadwal.jamSelesaiPengganti,
                ruangan   : jadwal.ruanganPengganti,
                mode      : jadwal.modePengganti,
              ),
            ),
          ],

          // ── Banner sesi aktif / presensi ──────────────────
          if (sesiAktif && !sudahPresensi) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child  : _SesiAktifRow(onPresensi: onPresensi),
            ),
          ] else if (sudahPresensi) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child  : _PresensiTercatat(status: jadwal.statusPresensi ?? ''),
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SesiAktifRow extends StatelessWidget {
  final VoidCallback onPresensi;
  const _SesiAktifRow({required this.onPresensi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color       : AppColors.kNavy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(
          color: AppColors.kNavy.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width : 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sesi sedang berlangsung',
              style: AppTypography.label.copyWith(
                color     : AppColors.kNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap : onPresensi,
            child : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color      : AppColors.kNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Presensi',
                style: AppTypography.buttonSmall.copyWith(
                  color  : Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresensiTercatat extends StatelessWidget {
  final String status;
  const _PresensiTercatat({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final label = status == 'hadir'
        ? 'Presensi tercatat ✓'
        : status == 'terlambat'
            ? 'Tercatat terlambat'
            : 'Tidak hadir';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color     : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// [DIPERBARUI v2.1.0] Accordion Hari — Mingguan
// ─────────────────────────────────────────────────────────────

class _HariAccordion extends StatelessWidget {
  final String              hari;
  final List<JadwalModel>   items;
  final bool                isToday;
  final bool                isExpanded;
  final List<SlotOption>    slotOptions;
  final VoidCallback        onTap;
  final VoidCallback        onPresensi;

  const _HariAccordion({
    required this.hari,
    required this.items,
    required this.isToday,
    required this.isExpanded,
    required this.slotOptions,
    required this.onTap,
    required this.onPresensi,
  });

  // ── Jumlah kelas yang punya jadwal pengganti ──────────────
  int get _jumlahPengganti =>
      items.where((j) => j.adaJadwalPengganti).length;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color       : AppColors.kSurface,
        borderRadius: BorderRadius.circular(14),
        border      : isToday
            ? Border.all(
                color: AppColors.kNavy.withOpacity(0.25), width: 1.5)
            : null,
        boxShadow   : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header accordion ──────────────────────────────
          InkWell(
            onTap       : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          hari,
                          style: AppTypography.bodyBold.copyWith(
                            color  : isToday
                                ? AppColors.kNavy
                                : AppColors.kTextPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color      : AppColors.kNavy,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Hari ini',
                              style: AppTypography.badge.copyWith(
                                color  : Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // ── [BARU] Badge jumlah kelas + indikator pengganti ──
                  Row(
                    children: [
                      if (_jumlahPengganti > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color       : AppColors.kGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border      : Border.all(
                              color: AppColors.kGold.withOpacity(0.40)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children    : [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size : 10,
                                color: AppColors.kWarning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$_jumlahPengganti pengganti',
                                style: AppTypography.badge.copyWith(
                                  color  : AppColors.kWarning,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        hasItems ? '${items.length} kelas' : 'Libur',
                        style: AppTypography.caption.copyWith(
                          color: hasItems
                              ? AppColors.kTextSecondary
                              : AppColors.kTextSecondary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns   : isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child   : Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Konten accordion ──────────────────────────────
          AnimatedCrossFade(
            duration      : const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: !hasItems
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color       : AppColors.kSoftGray.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.beach_access_rounded,
                            color: AppColors.kSoftGray,
                            size : 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tidak ada jadwal',
                            style: AppTypography.body2,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: items
                          .map((mk) => _MingguanItem(
                                jadwal     : mk,
                                isToday    : isToday,
                                slotOptions: slotOptions,
                                onPresensi : onPresensi,
                              ))
                          .toList(),
                    ),
                  ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// [DIPERBARUI v2.1.0] Item Mingguan
// ─────────────────────────────────────────────────────────────

class _MingguanItem extends StatelessWidget {
  final JadwalModel    jadwal;
  final bool           isToday;
  final List<SlotOption> slotOptions;
  final VoidCallback   onPresensi;

  const _MingguanItem({
    required this.jadwal,
    required this.isToday,
    required this.slotOptions,
    required this.onPresensi,
  });

  @override
  Widget build(BuildContext context) {
    // Jam efektif (prioritas jadwal pengganti)
    final jamMulaiEfektif   = jadwal.adaJadwalPengganti
        ? (jadwal.jamMulaiPengganti   ?? jadwal.jamMulai)
        : jadwal.jamMulai;
    final jamSelesaiEfektif = jadwal.adaJadwalPengganti
        ? (jadwal.jamSelesaiPengganti ?? jadwal.jamSelesai)
        : jadwal.jamSelesai;

    // Label slot jika ada
    final slotLabel = jadwal.slotMulai != null
        ? SlotOption.rangeLabel(
            jadwal.slotMulai!,
            jadwal.slotSelesai ?? jadwal.slotMulai!,
            slotOptions,
          )
        : '${jamMulaiEfektif ?? "-"} – ${jamSelesaiEfektif ?? "-"}';

    return Container(
      margin    : const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color       : AppColors.kBgLight,
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(color: AppColors.kSoftGray),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child  : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Jam mulai + selesai ───────────────────
                SizedBox(
                  width: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jamMulaiEfektif ?? '-',
                        style: AppTypography.bodyBold.copyWith(
                          color  : AppColors.kNavy,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        jamSelesaiEfektif ?? '',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                // Divider vertikal
                Container(
                  width : 1,
                  height: 42,
                  color : AppColors.kSoftGray,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                // ── Info MK ──────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama MK + badge kelas
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              jadwal.nama,
                              style: AppTypography.bodyBold.copyWith(
                                color  : AppColors.kNavyDark,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ── [BARU] Badge kelas ───────────
                          if (jadwal.kodeKelas != null &&
                              jadwal.kodeKelas!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            KelasBadge(
                              kodeKelas : jadwal.kodeKelas!,
                              fontSize  : 9,
                              showPrefix: false,
                            ),
                          ],
                          if (jadwal.isTamu) ...[
                            const SizedBox(width: 4),
                            const TamuBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // ── [BARU] Slot waktu ────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size : 11,
                            color: AppColors.kTextSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            slotLabel,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      if (jadwal.ruanganEfektif != '-') ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.room_outlined,
                              size : 11,
                              color: AppColors.kTextSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              jadwal.ruanganEfektif,
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Status / tombol presensi (hari ini saja) ──
                if (isToday) ...[
                  const SizedBox(width: 8),
                  if (jadwal.adaSesiAktif && !jadwal.sudahPresensi)
                    GestureDetector(
                      onTap : onPresensi,
                      child : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color      : AppColors.kNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Presensi',
                          style: AppTypography.buttonSmall.copyWith(
                            color  : Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                  else if (jadwal.statusPresensi != null)
                    StatusPresensiiBadge(
                      status  : jadwal.statusPresensi!,
                      fontSize: 9,
                    ),
                ],
              ],
            ),
          ),

          // ── [BARU] Banner jadwal pengganti di mingguan ───
          if (jadwal.adaJadwalPengganti) ...[
            Container(
              margin : const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color       : AppColors.kGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border      : Border(
                  left: BorderSide(color: AppColors.kGold, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size : 14,
                    color: AppColors.kWarning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal Diganti',
                          style: AppTypography.badge.copyWith(
                            color    : AppColors.kWarning,
                            fontSize : 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Tampilkan mode baru jika ada
                        Text(
                          _buildPenggantiDetail(jadwal),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildPenggantiDetail(JadwalModel jadwal) {
    final parts = <String>[];
    if (jadwal.jamMulaiPengganti != null &&
        jadwal.jamSelesaiPengganti != null) {
      parts.add(
          '${jadwal.jamMulaiPengganti} – ${jadwal.jamSelesaiPengganti}');
    }
    if (jadwal.ruanganPengganti != null) {
      parts.add(jadwal.ruanganPengganti!);
    }
    // ── [BARU] Mode dari jadwal pengganti ────────────────────
    if (jadwal.modePengganti != null) {
      parts.add(jadwal.modePengganti!.toLowerCase() == 'online'
          ? '💻 Online'
          : '📍 Tatap Muka');
    }
    return parts.join(' · ');
  }
}