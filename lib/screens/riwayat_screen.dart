// lib/screens/riwayat_screen.dart
// v2.1.0 — Fase 3 Langkah 3.4 SELESAI
//
// PERUBAHAN DARI v1.x:
// ✅ UPDATE: Group by MK + Kelas — header: "Pemrograman Mobile — Kelas A"
// ✅ TAMBAH: Chip filter: Semua | Hadir | Terlambat | Absen | Online | Offline | Tamu
// ✅ TAMBAH: Ringkasan global: persentase terpisah untuk mode Online dan Offline
// ✅ TAMBAH: Badge 'Tamu' pada pertemuan yang diikuti sebagai tamu
// ✅ TAMBAH: Nama dosen dan mode kelas di setiap item pertemuan
// ✅ UPDATE: Warna chart donut: Navy=hadir, Gold=terlambat, Red=absen
// ✅ UPDATE: Tema UMS — Navy + Gold

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:presensi_app/widgets/ums_app_bar.dart';

// ── Konstanta filter chip ─────────────────────────────────────

enum _FilterChip {
  semua,
  hadir,
  terlambat,
  absen,
  online,
  offline,
  tamu,
}

extension _FilterChipLabel on _FilterChip {
  String get label {
    switch (this) {
      case _FilterChip.semua    : return 'Semua';
      case _FilterChip.hadir    : return 'Hadir';
      case _FilterChip.terlambat: return 'Terlambat';
      case _FilterChip.absen    : return 'Absen';
      case _FilterChip.online   : return 'Online';
      case _FilterChip.offline  : return 'Offline';
      case _FilterChip.tamu     : return 'Tamu';
    }
  }
}

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  bool    _isLoading = true;
  String? _errorMsg;

  Map<String, dynamic>       _statistik = {};
  List<Map<String, dynamic>> _riwayat   = [];

  // v2.1.0: Group by "matakuliah — kelas"
  // Key format: "Nama MK||KodeKelas" untuk bisa split kembali
  Map<String, List<Map<String, dynamic>>> _grouped = {};

  String? _expandedKey;

  // v2.1.0: Filter chip aktif
  _FilterChip _activeFilter = _FilterChip.semua;

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  // ── Fetch data ────────────────────────────────────────────

  Future<void> _fetchRiwayat() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/presensi/riwayat');
      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final list  = (data['riwayat']   as List? ?? [])
            .cast<Map<String, dynamic>>();
        final stats = data['statistik']  as Map<String, dynamic>? ?? {};

        // v2.1.0: Group by MK + Kelas
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final item in list) {
          final mk    = item['matakuliah']  as String? ?? 'Tidak diketahui';
          final kelas = item['kode_kelas']  as String? ?? '';
          // Key: "NamaMK||KodeKelas" — kosong jika tidak ada kelas
          final key   = kelas.isEmpty ? mk : '$mk||$kelas';
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(item);
        }

        setState(() {
          _statistik = stats;
          _riwayat   = list;
          _grouped   = grouped;
          if (grouped.isNotEmpty) _expandedKey = grouped.keys.first;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg  = 'Gagal memuat riwayat';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg  = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ── Filter logic ──────────────────────────────────────────

  /// Apakah item lolos filter aktif
  bool _itemLulusFilter(Map<String, dynamic> item) {
    if (_activeFilter == _FilterChip.semua) return true;
    final status = item['status']       as String? ?? '';
    final mode   = item['mode_kelas']   as String? ?? '';
    final isTamu = item['is_tamu']      as bool?   ?? false;
    switch (_activeFilter) {
      case _FilterChip.hadir    : return status == 'hadir';
      case _FilterChip.terlambat: return status == 'terlambat';
      case _FilterChip.absen    : return status == 'absen';
      case _FilterChip.online   : return mode   == 'online';
      case _FilterChip.offline  : return mode   == 'offline';
      case _FilterChip.tamu     : return isTamu;
      case _FilterChip.semua    : return true;
    }
  }

  // ── Warna & ikon status ───────────────────────────────────

  Color _statusColor(String status) {
    return AppColors.statusColor(status);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'hadir'    : return Icons.check_circle_rounded;
      case 'terlambat': return Icons.access_time_rounded;
      case 'absen'    : return Icons.cancel_rounded;
      case 'izin'     : return Icons.info_rounded;
      case 'sakit'    : return Icons.local_hospital_rounded;
      default         : return Icons.help_rounded;
    }
  }

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')}/'
             '${dt.year}  '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // ── Hitung persentase kehadiran per group ─────────────────

  double _hitungPersen(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return 0;
    final efektif = list.where((p) =>
        p['status'] == 'hadir' || p['status'] == 'terlambat').length;
    return efektif / list.length * 100;
  }

  // ── Parse key group → nama MK + kode kelas ───────────────

  _GroupHeader _parseGroupKey(String key) {
    final parts = key.split('||');
    if (parts.length == 2) {
      return _GroupHeader(mk: parts[0], kelas: parts[1]);
    }
    return _GroupHeader(mk: key, kelas: '');
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      appBar: UMSAppBar(
        title  : 'Riwayat Kehadiran',
        showBack: true,
        actions: [
          IconButton(
            icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchRiwayat,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _errorMsg != null
              ? _buildError()
              : _riwayat.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildLoading() => const Center(
      child: CircularProgressIndicator(color: AppColors.kNavy));

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, size: 64,
            color: AppColors.kStatusAbsen.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text(_errorMsg!,
            style: AppTypography.body2, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed : _fetchRiwayat,
          icon : const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Coba Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kNavy,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history_edu_rounded, size: 80,
            color: AppColors.kSoftGray),
        const SizedBox(height: 16),
        Text('Belum ada riwayat kehadiran',
            style: AppTypography.heading3.copyWith(
                color: AppColors.kTextSecondary)),
        const SizedBox(height: 8),
        Text('Lakukan presensi terlebih dahulu',
            style: AppTypography.body2),
      ],
    ),
  );

  Widget _buildContent() {
    final total     = _statistik['total']      as int?    ?? 0;
    final hadir     = _statistik['hadir']      as int?    ?? 0;
    final terlambat = _statistik['terlambat']  as int?    ?? 0;
    final absen     = _statistik['absen']      as int?    ?? 0;
    final persen    = _statistik['persentase'] as double? ?? 0.0;

    // v2.1.0: Hitung statistik mode terpisah
    final totalOnline  = _riwayat
        .where((p) => p['mode_kelas'] == 'online').length;
    final hadirOnline  = _riwayat
        .where((p) =>
            p['mode_kelas'] == 'online' &&
            (p['status'] == 'hadir' || p['status'] == 'terlambat'))
        .length;
    final pOnline = totalOnline > 0
        ? hadirOnline / totalOnline * 100
        : 0.0;

    final totalOffline = _riwayat
        .where((p) => p['mode_kelas'] == 'offline').length;
    final hadirOffline = _riwayat
        .where((p) =>
            p['mode_kelas'] == 'offline' &&
            (p['status'] == 'hadir' || p['status'] == 'terlambat'))
        .length;
    final pOffline = totalOffline > 0
        ? hadirOffline / totalOffline * 100
        : 0.0;

    // Apply filter ke _riwayat untuk hitung jumlah lolos
    final jumlahLolos = _riwayat.where(_itemLulusFilter).length;

    return RefreshIndicator(
      onRefresh: _fetchRiwayat,
      color    : AppColors.kNavy,
      child: CustomScrollView(
        slivers: [
          // ── Ringkasan global ───────────────────────────
          SliverToBoxAdapter(
            child: _buildRingkasan(
              total    : total,
              hadir    : hadir,
              terlambat: terlambat,
              absen    : absen,
              persen   : persen,
              pOnline  : pOnline,
              pOffline : pOffline,
            ),
          ),

          // ── v2.1.0: Filter chip ────────────────────────
          SliverToBoxAdapter(
            child: _buildFilterChips(jumlahLolos),
          ),

          // ── Judul ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Detail per Matakuliah (${_grouped.length})',
                style: AppTypography.sectionTitle,
              ),
            ),
          ),

          // ── List group MK + Kelas ──────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final key    = _grouped.keys.elementAt(idx);
                final items  = _grouped[key]!;
                final header = _parseGroupKey(key);

                // Filter items dalam group
                final filteredItems =
                    items.where(_itemLulusFilter).toList();
                if (filteredItems.isEmpty &&
                    _activeFilter != _FilterChip.semua) {
                  return const SizedBox.shrink();
                }

                final pct    = _hitungPersen(
                    filteredItems.isEmpty ? items : filteredItems);
                final isOpen = _expandedKey == key;

                return _MatakuliahKelasCard(
                  groupKey   : key,
                  header     : header,
                  items      : filteredItems.isEmpty ? items : filteredItems,
                  allItems   : items,
                  persentase : pct,
                  isExpanded : isOpen,
                  onTap      : () => setState(() =>
                      _expandedKey = isOpen ? null : key),
                  statusColor: _statusColor,
                  statusIcon : _statusIcon,
                  formatWaktu: _formatWaktu,
                );
              },
              childCount: _grouped.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Widget: Ringkasan global ──────────────────────────────

  Widget _buildRingkasan({
    required int    total,
    required int    hadir,
    required int    terlambat,
    required int    absen,
    required double persen,
    required double pOnline,
    required double pOffline,
  }) {
    return Container(
      color  : AppColors.kNavy,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child  : Column(
        children: [
          // Donut chart + legend
          SizedBox(
            height: 180,
            child : Row(
              children: [
                // Chart
                SizedBox(
                  width: 160,
                  child: total == 0
                      ? Center(
                          child: Text(
                            'Tidak ada data',
                            style: AppTypography.body2.copyWith(
                                color: Colors.white54),
                          ),
                        )
                      : PieChart(
                          PieChartData(
                            sectionsSpace   : 2,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                value : hadir.toDouble(),
                                // v2.1.0: Navy = hadir
                                color : Colors.white,
                                title : hadir > 0 ? '$hadir' : '',
                                radius: 40,
                                titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.kNavy),
                              ),
                              PieChartSectionData(
                                value : terlambat.toDouble(),
                                // v2.1.0: Gold = terlambat
                                color : AppColors.kGold,
                                title : terlambat > 0 ? '$terlambat' : '',
                                radius: 40,
                                titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.kNavyDark),
                              ),
                              PieChartSectionData(
                                value : absen.toDouble(),
                                // v2.1.0: Red = absen
                                color : AppColors.kStatusAbsen,
                                title : absen > 0 ? '$absen' : '',
                                radius: 40,
                                titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // Legend + persentase
                Expanded(
                  child: Column(
                    mainAxisAlignment : MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${persen.toStringAsFixed(1)}%',
                        style: AppTypography.heading1.copyWith(
                          color   : Colors.white,
                          fontSize: 36,
                        ),
                      ),
                      Text(
                        'Kehadiran Efektif',
                        style: AppTypography.caption.copyWith(
                            color: Colors.white60),
                      ),
                      const SizedBox(height: 10),
                      _LegendItem(color: Colors.white,
                          label: 'Hadir ($hadir)'),
                      _LegendItem(color: AppColors.kGold,
                          label: 'Terlambat ($terlambat)'),
                      _LegendItem(color: AppColors.kStatusAbsen,
                          label: 'Absen ($absen)'),
                      _LegendItem(color: Colors.white38,
                          label: 'Total ($total)'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // v2.1.0: Ringkasan mode Online vs Offline
          if (total > 0)
            _buildModeRingkasan(
              pOnline : pOnline,
              pOffline: pOffline,
              totalOnline : _riwayat
                  .where((p) => p['mode_kelas'] == 'online').length,
              totalOffline: _riwayat
                  .where((p) => p['mode_kelas'] == 'offline').length,
            ),
        ],
      ),
    );
  }

  // v2.1.0: Strip mode online vs offline ─────────────────────

  Widget _buildModeRingkasan({
    required double pOnline,
    required double pOffline,
    required int    totalOnline,
    required int    totalOffline,
  }) {
    if (totalOnline == 0 && totalOffline == 0) return const SizedBox.shrink();

    return Container(
      margin     : const EdgeInsets.only(top: 12),
      padding    : const EdgeInsets.all(12),
      decoration : BoxDecoration(
        color       : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (totalOnline > 0)
            Expanded(
              child: _ModeStatItem(
                icon   : Icons.laptop_outlined,
                label  : 'Online',
                persen : pOnline,
                total  : totalOnline,
                color  : AppColors.kModeOnline,
              ),
            ),
          if (totalOnline > 0 && totalOffline > 0)
            Container(
              width : 1,
              height: 40,
              color : Colors.white.withOpacity(0.12),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
          if (totalOffline > 0)
            Expanded(
              child: _ModeStatItem(
                icon   : Icons.location_on_outlined,
                label  : 'Tatap Muka',
                persen : pOffline,
                total  : totalOffline,
                color  : AppColors.kModeOffline,
              ),
            ),
        ],
      ),
    );
  }

  // ── Widget: Filter chip ───────────────────────────────────

  Widget _buildFilterChips(int jumlahLolos) {
    return Container(
      color  : AppColors.kSurface,
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
      child  : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filter:', style: AppTypography.label),
              const SizedBox(width: 8),
              if (_activeFilter != _FilterChip.semua)
                Text(
                  '$jumlahLolos hasil',
                  style: AppTypography.label.copyWith(
                    color: AppColors.kNavy),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _FilterChip.values.map((chip) {
                final isActive = chip == _activeFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label    : Text(chip.label),
                    selected : isActive,
                    onSelected: (_) => setState(
                        () => _activeFilter = chip),
                    selectedColor: AppColors.kNavy,
                    backgroundColor: AppColors.kSoftGray,
                    labelStyle: AppTypography.badge.copyWith(
                      color   : isActive
                          ? Colors.white
                          : AppColors.kTextSecondary,
                      fontSize: 11,
                    ),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 0),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GROUP HEADER — parse key "NamaMK||KodeKelas"
// ══════════════════════════════════════════════════════════════

class _GroupHeader {
  final String mk;
  final String kelas;
  const _GroupHeader({required this.mk, required this.kelas});
  bool get hasKelas => kelas.isNotEmpty;
}

// ══════════════════════════════════════════════════════════════
// v2.1.0: CARD EXPANDABLE — GROUP MK + KELAS
// ══════════════════════════════════════════════════════════════

class _MatakuliahKelasCard extends StatelessWidget {
  final String     groupKey;
  final _GroupHeader header;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> allItems; // semua item tanpa filter
  final double     persentase;
  final bool       isExpanded;
  final VoidCallback onTap;
  final Color  Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String?) formatWaktu;

  const _MatakuliahKelasCard({
    required this.groupKey,
    required this.header,
    required this.items,
    required this.allItems,
    required this.persentase,
    required this.isExpanded,
    required this.onTap,
    required this.statusColor,
    required this.statusIcon,
    required this.formatWaktu,
  });

  Color get _barColor => AppColors.persentaseColor(persentase);

  @override
  Widget build(BuildContext context) {
    // Hitung jumlah tamu di group ini
    final jumlahTamu = allItems
        .where((p) => p['is_tamu'] == true).length;

    return Card(
      margin   : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape    : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        onTap       : onTap,
        child       : Padding(
          padding: const EdgeInsets.all(16),
          child  : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header group ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama MK
                        Text(
                          header.mk,
                          style: AppTypography.bodyBold,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // v2.1.0: Badge kelas + info pertemuan + tamu
                        Wrap(
                          spacing   : 6,
                          runSpacing: 4,
                          children  : [
                            if (header.hasKelas)
                              KelasBadge(kodeKelas: header.kelas),
                            Text(
                              '${allItems.length} pertemuan',
                              style: AppTypography.caption,
                            ),
                            if (jumlahTamu > 0)
                              _TamuCountChip(count: jumlahTamu),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge persentase
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _barColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${persentase.toStringAsFixed(0)}%',
                      style: AppTypography.bodyBold.copyWith(
                        color   : _barColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppColors.kTextSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value          : persentase / 100,
                  backgroundColor: AppColors.kSoftGray,
                  valueColor     : AlwaysStoppedAnimation<Color>(_barColor),
                  minHeight      : 8,
                ),
              ),

              // ── Expanded: list pertemuan ───────────────
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...items.map((p) => _PertemuanRow(
                  item       : p,
                  statusColor: statusColor,
                  statusIcon : statusIcon,
                  formatWaktu: formatWaktu,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// v2.1.0: BARIS PERTEMUAN — tambah dosen, mode, badge tamu
// ══════════════════════════════════════════════════════════════

class _PertemuanRow extends StatelessWidget {
  final Map<String, dynamic>  item;
  final Color  Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String?) formatWaktu;

  const _PertemuanRow({
    required this.item,
    required this.statusColor,
    required this.statusIcon,
    required this.formatWaktu,
  });

  @override
  Widget build(BuildContext context) {
    final status    = item['status']         as String? ?? '';
    final pertemuan = item['pertemuan_ke']   as int?    ?? 0;
    final waktu     = item['waktu_presensi'] as String?;
    final mode      = item['mode_kelas']     as String? ?? '';
    final akurasi   = item['akurasi_wajah']  as double?;
    final catatan   = item['catatan']        as String?;
    // v2.1.0 — field baru
    final isTamu    = item['is_tamu']        as bool?   ?? false;
    final dosenNama = item['dosen_nama']     as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nomor pertemuan ────────────────────────────
          Container(
            width : 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$pertemuan',
                style: AppTypography.bodyBold.copyWith(
                  color   : statusColor(status),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Detail tengah ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waktu presensi
                Text(
                  waktu != null
                      ? formatWaktu(waktu)
                      : 'Tidak hadir',
                  style: AppTypography.body2.copyWith(
                    color: waktu != null
                        ? AppColors.kTextPrimary
                        : AppColors.kTextSecondary,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                // v2.1.0: Badge mode + akurasi + dosen
                Wrap(
                  spacing   : 6,
                  runSpacing: 4,
                  children  : [
                    if (mode.isNotEmpty)
                      ModeBadge(mode: mode, fontSize: 9),
                    if (akurasi != null)
                      _SmallInfo(
                          label: '${akurasi.toStringAsFixed(1)}%'),
                    if (isTamu)
                      const TamuBadge(),
                  ],
                ),

                // v2.1.0: Nama dosen
                if (dosenNama != null && dosenNama.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 10,
                          color: AppColors.kTextSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          dosenNama,
                          style  : AppTypography.caption.copyWith(
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                if (catatan != null && catatan.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '📝 $catatan',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.kInfo, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          // ── Badge status ───────────────────────────────
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon(status),
                    color: statusColor(status), size: 11),
                const SizedBox(width: 3),
                Text(
                  status.toUpperCase(),
                  style: AppTypography.badge.copyWith(
                    color   : statusColor(status),
                    fontSize: 9,
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

// ══════════════════════════════════════════════════════════════
// WIDGET PENDUKUNG
// ══════════════════════════════════════════════════════════════

class _LegendItem extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width : 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption.copyWith(
                  color: Colors.white70)),
        ],
      ),
    );
  }
}

/// Strip statistik per mode (online / offline)
class _ModeStatItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final double   persen;
  final int      total;
  final Color    color;

  const _ModeStatItem({
    required this.icon,
    required this.label,
    required this.persen,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.caption.copyWith(color: Colors.white60)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${persen.toStringAsFixed(1)}%',
          style: AppTypography.bodyBold.copyWith(
              color: Colors.white, fontSize: 16),
        ),
        Text(
          '$total pertemuan',
          style: AppTypography.caption.copyWith(color: Colors.white38),
        ),
      ],
    );
  }
}

/// Chip kecil jumlah tamu dalam group
class _TamuCountChip extends StatelessWidget {
  final int count;
  const _TamuCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color       : AppColors.kWarning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(
            color: AppColors.kWarning.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined,
              size: 9, color: AppColors.kWarning),
          const SizedBox(width: 3),
          Text(
            '$count tamu',
            style: AppTypography.badge.copyWith(
              color   : AppColors.kWarning,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info kecil (akurasi, dsb.)
class _SmallInfo extends StatelessWidget {
  final String label;
  const _SmallInfo({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.caption.copyWith(fontSize: 10),
    );
  }
}