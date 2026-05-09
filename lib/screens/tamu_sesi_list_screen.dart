// lib/screens/tamu_sesi_list_screen.dart
// v2.1.0 — Fase 3 Langkah 3.3 SELESAI
//
// BARU: Screen list sesi aktif yang tersedia untuk mahasiswa tamu.
// Dipanggil dari tombol 'Ikut sebagai Tamu' di ScanScreen.
//
// Flow:
//   Tap 'Ikut sebagai Tamu' di ScanScreen
//     → fetch GET /sesi/aktif-tamu
//     → tampilkan list kartu sesi (nama MK, kelas, dosen, jam, mode)
//     → tap sesi offline → ScanScreen dengan sesiAktif preset
//     → tap sesi online  → KodeSesiScreen dengan sesiAktif preset
//
// Syarat sesi muncul:
//   - Dosen sudah daftarkan mahasiswa secara manual, ATAU
//   - izin_tamu = true di kelas tersebut

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/models/sesi_tamu.dart';
import 'package:presensi_app/services/sesi_detect_service.dart';
import 'package:presensi_app/widgets/empty_error_state.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/ums_app_bar.dart';

class TamuSesiListScreen extends StatefulWidget {
  const TamuSesiListScreen({super.key});

  @override
  State<TamuSesiListScreen> createState() => _TamuSesiListScreenState();
}

class _TamuSesiListScreenState extends State<TamuSesiListScreen> {
  bool   _isLoading = true;
  String? _errorMsg;
  List<SesiTamuModel> _sesiList = [];

  @override
  void initState() {
    super.initState();
    _fetchSesiTamu();
  }

  // ── Fetch sesi tersedia untuk tamu ────────────────────────

  Future<void> _fetchSesiTamu() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg  = null;
    });

    try {
      final rawList = await SesiDetectService().getSesiAktifTamu();
      final list    = rawList
          .map((json) => SesiTamuModel.fromJson(json))
          .toList();
      if (mounted) {
        setState(() {
          _sesiList  = list;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg  = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg  = 'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Navigasi ke scan / kode sesi ─────────────────────────

  void _pilihSesi(SesiTamuModel sesi) {
    // Buat SesiDetectResult dari data sesi tamu
    final result = SesiDetectResult(
      status        : SesiDetectStatus.found,
      sesiId        : sesi.sesiId,
      matakuliahNama: sesi.matakuliahNama,
      matakuliahKode: sesi.matakuliahKode,
      kelasId       : sesi.kelasId,
      kodeKelas     : sesi.kodeKelas,
      dosenNama     : sesi.dosenNama,
      mode          : sesi.mode,
      ruangan       : sesi.ruangan,
      pertemuanKe   : sesi.pertemuanKe,
      detikTersisa  : sesi.detikTersisa,
    );

    if (sesi.isOnline) {
      // Sesi online → ke KodeSesiScreen dengan konteks sesi tamu
      context.go('/kode-sesi', extra: result);
    } else {
      // Sesi offline → kembali ke scan screen dengan sesi preset
      // Kirim result lewat extra agar ScanScreen bisa langsung pakai
      context.go('/scan', extra: result);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      appBar: UMSAppBar(
        title      : 'Ikut sebagai Tamu',
        showBack   : true,
        actions    : [
          IconButton(
            icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchSesiTamu,
            tooltip  : 'Perbarui',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_errorMsg != null) return _buildError();
    if (_sesiList.isEmpty) return const NoSesiTamuState();
    return _buildList();
  }

  // ── Loading state ─────────────────────────────────────────

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 20),
          const ShimmerList(count: 3, cardHeight: 120),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────

  Widget _buildError() {
    return ErrorState(
      message: _errorMsg,
      onRetry: _fetchSesiTamu,
    );
  }

  // ── List sesi ─────────────────────────────────────────────

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh   : _fetchSesiTamu,
      color       : AppColors.kNavy,
      child: CustomScrollView(
        slivers: [
          // Info banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildInfoBanner(),
            ),
          ),

          // Jumlah sesi tersedia
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${_sesiList.length} sesi tersedia untuk Anda',
                style: AppTypography.sectionTitle,
              ),
            ),
          ),

          // List kartu sesi
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: _SesiTamuCard(
                  sesi   : _sesiList[index],
                  onTap  : () => _pilihSesi(_sesiList[index]),
                ),
              ),
              childCount: _sesiList.length,
            ),
          ),

          // Spacer bawah
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Info banner — penjelasan fitur tamu ───────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color       : AppColors.kNavy.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(
            color: AppColors.kNavy.withOpacity(0.18), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.kNavy, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Berikut adalah sesi aktif yang dapat Anda ikuti sebagai tamu. '
              'Sesi muncul karena dosen telah mendaftarkan Anda, '
              'atau kelas tersebut membuka izin tamu.',
              style: AppTypography.body2.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARD: Satu sesi tamu
// ══════════════════════════════════════════════════════════════

class _SesiTamuCard extends StatelessWidget {
  final SesiTamuModel sesi;
  final VoidCallback  onTap;

  const _SesiTamuCard({required this.sesi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOnline = sesi.isOnline;

    return Material(
      color       : AppColors.kSurface,
      borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
      elevation   : 1,
      shadowColor : Colors.black12,
      child: InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
            border: Border(
              left: BorderSide(
                color: isOnline
                    ? AppColors.kModeOnline
                    : AppColors.kModeOffline,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Baris atas: nama MK + badge kelas + mode ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikon mode
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isOnline
                              ? AppColors.kModeOnline
                              : AppColors.kModeOffline)
                          .withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOnline
                          ? Icons.laptop_outlined
                          : Icons.location_on_outlined,
                      size : 20,
                      color: isOnline
                          ? AppColors.kModeOnline
                          : AppColors.kModeOffline,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nama MK + kode
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sesi.matakuliahNama,
                          style  : AppTypography.bodyBold.copyWith(
                            fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sesi.matakuliahKode,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),

                  // Badge alasan (didaftarkan / izin tamu)
                  _AlasanBadge(
                      sudahDidaftarkan: sesi.sudahDidaftarkan),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // ── Info baris: kelas, mode, jam, ruangan, dosen ──
              Wrap(
                spacing   : 8,
                runSpacing: 6,
                children  : [
                  // Badge kelas
                  if (sesi.kodeKelas.isNotEmpty)
                    KelasBadge(kodeKelas: sesi.kodeKelas),

                  // Badge mode
                  ModeBadge(mode: sesi.mode),

                  // Pertemuan ke
                  if (sesi.pertemuanKe != null)
                    _InfoChip(
                      icon : Icons.event_note_outlined,
                      label: 'Pertemuan ${sesi.pertemuanKe}',
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Jam + ruangan
              Row(
                children: [
                  if (sesi.jamMulai != null) ...[
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: AppColors.kTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      sesi.labelJam,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (sesi.ruangan != null) ...[
                    const Icon(Icons.room_outlined,
                        size: 13, color: AppColors.kTextSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sesi.ruangan!,
                        style  : AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Nama dosen
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: AppColors.kTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sesi.dosenNama,
                      style  : AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Tombol aksi ───────────────────────────────
              SizedBox(
                width : double.infinity,
                height: 44,
                child : ElevatedButton.icon(
                  onPressed: onTap,
                  icon : Icon(
                    isOnline
                        ? Icons.lock_open_rounded
                        : Icons.face_unlock_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isOnline ? 'Masukkan Kode Sesi' : 'Ikuti Kelas Ini',
                    style: AppTypography.buttonSmall.copyWith(
                        color: AppColors.kNavyDark),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kGold,
                    foregroundColor: AppColors.kNavyDark,
                    elevation      : 0,
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
}

// ── Badge alasan sesi tamu muncul ────────────────────────────

class _AlasanBadge extends StatelessWidget {
  final bool sudahDidaftarkan;
  const _AlasanBadge({required this.sudahDidaftarkan});

  @override
  Widget build(BuildContext context) {
    final color = sudahDidaftarkan
        ? AppColors.kNavy
        : AppColors.kGreen;
    final label = sudahDidaftarkan
        ? 'Didaftarkan'
        : 'Izin Tamu';
    final icon = sudahDidaftarkan
        ? Icons.how_to_reg_outlined
        : Icons.group_add_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color   : color,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip kecil ───────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color       : AppColors.kSoftGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.kTextSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color   : AppColors.kTextSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}