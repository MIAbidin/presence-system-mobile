// lib/screens/dosen/rekap_screen.dart
// FASE 8 UPDATE:
// - RekapListScreen: badge kelas & mode, filter kelas_id, filter mode
// - RekapScreen: info kelas & mode di header
// - Fix ekspor: Share.shareXFiles + getTemporaryDirectory (iOS compat)
// - Progress overlay saat ekspor lebih informatif

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:presensi_app/core/storage.dart';
import 'package:presensi_app/core/constants.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';
import 'package:share_plus/share_plus.dart';

// ══════════════════════════════════════════════════════════════
// REKAP LIST SCREEN — Tab Rekap (Fase 8 update)
// ══════════════════════════════════════════════════════════════

class RekapListScreen extends StatefulWidget {
  const RekapListScreen({super.key});

  @override
  State<RekapListScreen> createState() => _RekapListScreenState();
}

class _RekapListScreenState extends State<RekapListScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool    _isLoading = true;
  String? _errorMsg;

  List<Map<String, dynamic>> _allSesi      = [];
  List<Map<String, dynamic>> _filteredSesi = [];

  // ── Filter state ──────────────────────────────────────────
  String  _filterMk    = 'semua';
  String  _filterMode  = 'semua';
  String  _filterKelas = 'semua'; // [BARU Fase 8]

  List<String> _mkList    = [];
  List<String> _kelasList = []; // [BARU Fase 8]

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/sesi/riwayat-dosen');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final list     = (data['sesi_list'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final mkSet    = <String>{};
      final kelasSet = <String>{}; // [BARU Fase 8]

      for (final s in list) {
        final mk    = s['matakuliah']  as String? ?? '';
        final kelas = s['kode_kelas']  as String? ?? ''; // [BARU Fase 8]
        if (mk.isNotEmpty)    mkSet.add(mk);
        if (kelas.isNotEmpty) kelasSet.add(kelas);
      }

      setState(() {
        _allSesi    = list;
        _mkList     = mkSet.toList()..sort();
        _kelasList  = kelasSet.toList()..sort(); // [BARU Fase 8]
        _isLoading  = false;
      });
      _applyFilter();
    } on ApiException catch (e) {
      setState(() { _errorMsg = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredSesi = _allSesi.where((s) {
        final mk    = s['matakuliah']  as String? ?? '';
        final mode  = s['mode']        as String? ?? '';
        final kelas = s['kode_kelas']  as String? ?? ''; // [BARU Fase 8]

        final mkOk    = _filterMk    == 'semua' || mk    == _filterMk;
        final modeOk  = _filterMode  == 'semua' || mode  == _filterMode;
        final kelasOk = _filterKelas == 'semua' || kelas == _filterKelas; // [BARU]

        return mkOk && modeOk && kelasOk;
      }).toList();
    });
  }

  bool get _hasActiveFilter =>
      _filterMk != 'semua' || _filterMode != 'semua' || _filterKelas != 'semua';

  void _resetFilter() {
    setState(() {
      _filterMk    = 'semua';
      _filterMode  = 'semua';
      _filterKelas = 'semua';
    });
    _applyFilter();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aktif'  : return AppColors.kGreen;
      case 'selesai': return AppColors.kTextSecondary;
      default       : return AppColors.kNavy;
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
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              color  : AppColors.kNavy,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Rekap Presensi',
                          style: AppTypography.hero.copyWith(fontSize: 20)),
                      ),
                      IconButton(
                        icon     : const Icon(Icons.refresh_rounded, color: Colors.white),
                        onPressed: _fetchRiwayat,
                        tooltip  : 'Refresh'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredSesi.length} sesi ditemukan',
                    style: AppTypography.heroSubtitle,
                  ),
                  const SizedBox(height: 14),

                  // ── Filter row (Fase 8: tambah filter Kelas) ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipDropdown(
                          label    : 'Matakuliah',
                          value    : _filterMk,
                          items    : ['semua', ..._mkList],
                          onChanged: (v) { setState(() => _filterMk = v); _applyFilter(); },
                        ),
                        const SizedBox(width: 8),

                        // [BARU Fase 8] Filter Kelas
                        if (_kelasList.isNotEmpty) ...[
                          _FilterChipDropdown(
                            label    : 'Kelas',
                            value    : _filterKelas,
                            items    : ['semua', ..._kelasList],
                            onChanged: (v) { setState(() => _filterKelas = v); _applyFilter(); },
                          ),
                          const SizedBox(width: 8),
                        ],

                        // [BARU Fase 8] Filter Mode (Offline/Online)
                        _FilterChipDropdown(
                          label    : 'Mode',
                          value    : _filterMode,
                          items    : ['semua', 'offline', 'online'],
                          onChanged: (v) { setState(() => _filterMode = v); _applyFilter(); },
                        ),
                        const SizedBox(width: 8),

                        if (_hasActiveFilter)
                          GestureDetector(
                            onTap : _resetFilter,
                            child : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close_rounded,
                                    color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Reset',
                                    style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            // ── Konten ──────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? _buildSkeleton()
                  : _errorMsg != null
                      ? _buildError()
                      : _filteredSesi.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchRiwayat,
                              color    : AppColors.kNavy,
                              child    : ListView.builder(
                                padding    : const EdgeInsets.all(16),
                                itemCount  : _filteredSesi.length,
                                itemBuilder: (ctx, i) {
                                  final s = _filteredSesi[i];
                                  return _RekapListCard(
                                    sesi       : s,
                                    formatWaktu: _formatWaktu,
                                    statusColor: _statusColor(
                                      s['status'] as String? ?? ''),
                                    onTap: () {
                                      final id = s['sesi_id'] as String? ?? '';
                                      if (id.isNotEmpty) {
                                        context.go('/dosen/rekap/$id');
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding    : const EdgeInsets.all(16),
      itemCount  : 5,
      itemBuilder: (_, __) => Container(
        margin : const EdgeInsets.only(bottom: 10),
        height : 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Gagal memuat rekap',
            style: AppTypography.heading3.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(_errorMsg!,
            textAlign: TextAlign.center,
            style: AppTypography.body2),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            child: ElevatedButton.icon(
              onPressed: _fetchRiwayat,
              icon : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.summarize_outlined, size: 72, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Text('Belum ada sesi',
          style: AppTypography.heading3.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          _hasActiveFilter
              ? 'Tidak ada sesi yang cocok dengan filter'
              : 'Buka sesi dari tab Beranda untuk mulai mengajar',
          textAlign: TextAlign.center,
          style: AppTypography.body2),
      ],
    ),
  );
}

// ── Filter chip dropdown ──────────────────────────────────────
class _FilterChipDropdown extends StatelessWidget {
  final String       label;
  final String       value;
  final List<String> items;
  final void Function(String) onChanged;

  const _FilterChipDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  String _display(String v) {
    if (v == 'semua') return label;
    return v[0].toUpperCase() + v.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'semua';
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Filter $label',
                    style: AppTypography.heading3.copyWith(fontSize: 16))),
                const Divider(height: 1),
                ...items.map((item) => ListTile(
                  title: Text(_display(item)),
                  trailing: value == item
                      ? Icon(Icons.check_rounded, color: AppColors.kNavy)
                      : null,
                  onTap: () => Navigator.pop(ctx, item),
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (result != null) onChanged(result);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.kNavy : Colors.white38,
            width: isActive ? 1.5 : 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? _display(value) : label,
              style: TextStyle(
                color: isActive ? AppColors.kNavy : Colors.white,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
              color: isActive ? AppColors.kNavy : Colors.white,
              size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Rekap List Card (Fase 8: badge kelas & mode) ──────────────
class _RekapListCard extends StatelessWidget {
  final Map<String, dynamic>  sesi;
  final String Function(String?) formatWaktu;
  final Color    statusColor;
  final VoidCallback onTap;

  const _RekapListCard({
    required this.sesi,
    required this.formatWaktu,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mk         = sesi['matakuliah']    as String? ?? '-';
    final mode       = sesi['mode']          as String? ?? '-';
    final kodeKelas  = sesi['kode_kelas']    as String? ?? ''; // [BARU Fase 8]
    final pertemuan  = sesi['pertemuan_ke']  as int?    ?? 0;
    final status     = sesi['status']        as String? ?? '-';
    final waktuBuka  = sesi['waktu_buka']    as String?;
    final total      = sesi['total_mhs']     as int?    ?? 0;
    final hadir      = sesi['hadir']         as int?    ?? 0;
    final terlambat  = sesi['terlambat']     as int?    ?? 0;
    final absen      = sesi['absen']         as int?    ?? 0;
    final persentase = sesi['persentase']    as double? ?? 0.0;
    final efektif    = hadir + terlambat;

    final barColor = AppColors.persentaseColor(persentase);

    return Card(
      margin    : const EdgeInsets.only(bottom: 10),
      elevation : 1,
      shape     : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Baris 1: Nama MK + Status ──────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(mk,
                      style: AppTypography.bodyBold.copyWith(
                        color: AppColors.kNavyDark, fontSize: 14),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      status == 'aktif' ? '🟢 AKTIF' : 'SELESAI',
                      style: TextStyle(
                        color: statusColor, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Baris 2: Badge Pertemuan + Kelas + Mode + Waktu ──
              // [BARU Fase 8] Tambah KelasBadge & ModeBadge
              Row(
                children: [
                  _InfoBadgeLocal(
                    label: 'Pertemuan $pertemuan',
                    color: Colors.blue.shade700,
                    bg   : Colors.blue.shade50),
                  const SizedBox(width: 6),

                  // [BARU] Badge kelas
                  if (kodeKelas.isNotEmpty) ...[
                    KelasBadge(kodeKelas: kodeKelas),
                    const SizedBox(width: 6),
                  ],

                  // [BARU] Badge mode
                  ModeBadge(mode: mode, fontSize: 10),

                  const Spacer(),
                  Text(formatWaktu(waktuBuka),
                    style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: 10),

              // ── Progress bar ────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value          : total > 0 ? efektif / total : 0,
                  backgroundColor: Colors.grey.shade100,
                  valueColor     : AlwaysStoppedAnimation<Color>(barColor),
                  minHeight      : 6)),
              const SizedBox(height: 8),

              // ── Statistik ───────────────────────────────────
              Row(
                children: [
                  _StatBadgeLocal(value: hadir,    label: 'Hadir',
                    color: AppColors.kStatusHadir),
                  const SizedBox(width: 8),
                  _StatBadgeLocal(value: terlambat, label: 'Terlambat',
                    color: AppColors.kStatusTerlambat),
                  const SizedBox(width: 8),
                  _StatBadgeLocal(value: absen,    label: 'Absen',
                    color: AppColors.kStatusAbsen),
                  const Spacer(),
                  Text(
                    '${persentase.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: barColor, fontSize: 16,
                      fontWeight: FontWeight.bold)),
                  Text(' /$total',
                    style: AppTypography.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadgeLocal extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;

  const _InfoBadgeLocal({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label,
      style: TextStyle(color: color, fontSize: 11,
        fontWeight: FontWeight.w600)),
  );
}

class _StatBadgeLocal extends StatelessWidget {
  final int    value;
  final String label;
  final Color  color;

  const _StatBadgeLocal({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$value',
        style: TextStyle(color: color, fontSize: 13,
          fontWeight: FontWeight.bold)),
      const SizedBox(width: 3),
      Text(label,
        style: AppTypography.caption),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
// REKAP SCREEN — Detail satu sesi (FASE 8: fix ekspor + kelas/mode)
// ══════════════════════════════════════════════════════════════

class RekapScreen extends StatefulWidget {
  final String sesiId;
  const RekapScreen({super.key, required this.sesiId});

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  bool    _isLoading   = true;
  bool    _isExporting = false;
  String? _errorMsg;
  String? _eksporStatus;

  Map<String, dynamic>       _sesiInfo  = {};
  Map<String, dynamic>       _statistik = {};
  List<Map<String, dynamic>> _detail    = [];

  @override
  void initState() {
    super.initState();
    _fetchRekap();
  }

  Future<void> _fetchRekap() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/presensi/rekap/${widget.sesiId}');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _sesiInfo  = data;
        _statistik = data['statistik'] as Map<String, dynamic>? ?? {};
        _detail    = (data['detail'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ?? [];
      });
    } on ApiException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Ekspor Excel — FASE 8 FIX ────────────────────────────
  // Menggunakan getTemporaryDirectory() untuk kompatibilitas iOS
  // Share via Share.shareXFiles (share_plus)
  Future<void> _eksporExcel() async {
    setState(() {
      _isExporting  = true;
      _eksporStatus = 'Menyiapkan file...';
    });

    try {
      final token = await AppStorage.getAccessToken();
      final url =
          '${AppConstants.baseUrl}/presensi/rekap/${widget.sesiId}/export';

      setState(() => _eksporStatus = 'Mengunduh dari server...');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        setState(() => _eksporStatus = 'Menyimpan file...');

        // Ambil nama file dari header
        final cd    = response.headers['content-disposition'] ?? '';
        final match = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);
        final fileName = match?.group(1) ??
            'rekap_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // ✅ FASE 8 FIX: getTemporaryDirectory() — bekerja di Android & iOS
        final dir      = await getTemporaryDirectory();
        final filePath = '${dir.path}/$fileName';
        final file     = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _isExporting  = false;
          _eksporStatus = null;
        });

        // ✅ FASE 8 FIX: Share.shareXFiles untuk Android & iOS
        final mk        = _sesiInfo['matakuliah']   as String? ?? 'Rekap';
        final kodeKelas = _sesiInfo['kode_kelas']   as String? ?? '';
        final pertemuan = _sesiInfo['pertemuan_ke'] as int?    ?? 0;

        final shareText = [
          'Rekap Presensi — $mk',
          if (kodeKelas.isNotEmpty) 'Kelas $kodeKelas',
          'Pertemuan $pertemuan',
        ].join(' · ');

        await Share.shareXFiles(
          [XFile(filePath)],
          text   : shareText,
          subject: shareText,
        );

      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isExporting  = false;
        _eksporStatus = null;
      });
      if (mounted) _showSnack('❌ Gagal ekspor: $e', isError: true);
    }
  }

  // ── Show ekspor sheet ────────────────────────────────────
  void _showEksporSheet() {
    final mk        = _sesiInfo['matakuliah']   as String? ?? '-';
    final pertemuan = _sesiInfo['pertemuan_ke'] as int?    ?? 0;
    final kodeKelas = _sesiInfo['kode_kelas']   as String? ?? ''; // [BARU]

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Ekspor Rekap',
              style: AppTypography.heading3),
            const SizedBox(height: 4),
            // [BARU Fase 8] Tampilkan info kelas di subtitle
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$mk · Pertemuan $pertemuan',
                    style: AppTypography.body2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (kodeKelas.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  KelasBadge(kodeKelas: kodeKelas),
                ],
              ],
            ),
            const SizedBox(height: 20),

            _EksporOptionTile(
              icon : Icons.table_chart_rounded,
              color: Colors.green.shade700,
              label: 'Ekspor Excel (.xlsx)',
              sub  : 'Download & bagikan file rekap via WhatsApp, email, dll.',
              onTap: () {
                Navigator.pop(ctx);
                _eksporExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'hadir'    : return AppColors.kStatusHadir;
      case 'terlambat': return AppColors.kStatusTerlambat;
      case 'absen'    : return AppColors.kStatusAbsen;
      case 'izin'     : return AppColors.kStatusIzin;
      case 'sakit'    : return AppColors.kStatusSakit;
      default         : return Colors.grey;
    }
  }

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}:'
             '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? AppColors.kStatusAbsen : AppColors.kGreen,
      behavior       : SnackBarBehavior.floating,
      duration       : const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      appBar: AppBar(
        backgroundColor: AppColors.kNavy,
        foregroundColor: Colors.white,
        title          : const Text('Rekap Presensi'),
        elevation      : 0,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dosen/rekap-list');
            }
          },
        ),
        actions: [
          // ── Progress ekspor (Fase 8: lebih informatif) ───
          if (_isExporting)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text(
                      _eksporStatus ?? '...',
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon     : const Icon(Icons.download_rounded),
              tooltip  : 'Ekspor Excel',
              onPressed: _isLoading ? null : _showEksporSheet),

          IconButton(
            icon     : const Icon(Icons.refresh_rounded),
            onPressed: _fetchRekap),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton()
          : _errorMsg != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(6, (i) => Container(
          margin : const EdgeInsets.only(bottom: 10),
          height : 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10)),
        )),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(_errorMsg!,
          textAlign: TextAlign.center,
          style: AppTypography.body2),
        const SizedBox(height: 16),
        SizedBox(
          width: 140,
          child: ElevatedButton(
            onPressed: _fetchRekap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kNavy,
              foregroundColor: Colors.white),
            child: const Text('Coba Lagi')),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    final mk        = _sesiInfo['matakuliah']    as String? ?? '-';
    final pertemuan = _sesiInfo['pertemuan_ke']  as int?    ?? 0;
    final mode      = _sesiInfo['mode']          as String? ?? '-';
    final kodeKelas = _sesiInfo['kode_kelas']    as String? ?? ''; // [BARU]
    final dosenNama = _sesiInfo['dosen_nama']    as String? ?? '';  // [BARU]
    final waktuBuka = _sesiInfo['waktu_buka']    as String?;
    final waktuTutup= _sesiInfo['waktu_tutup']   as String?;

    final hadir     = _statistik['hadir']      as int?    ?? 0;
    final terlambat = _statistik['terlambat']  as int?    ?? 0;
    final absen     = _statistik['absen']      as int?    ?? 0;
    final izin      = _statistik['izin']       as int?    ?? 0;
    final sakit     = _statistik['sakit']      as int?    ?? 0;
    final total     = _statistik['total']      as int?    ?? 0;
    final persen    = _statistik['persentase'] as double? ?? 0.0;

    final barColor = AppColors.persentaseColor(persen);

    return RefreshIndicator(
      onRefresh: _fetchRekap,
      child: CustomScrollView(
        slivers: [
          // ── Header info sesi (Fase 8: kelas & mode) ──────
          SliverToBoxAdapter(
            child: Container(
              color  : AppColors.kNavy,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mk,
                    style: AppTypography.hero.copyWith(fontSize: 17)),
                  const SizedBox(height: 8),

                  // [BARU Fase 8] Row badge: Pertemuan + Kelas + Mode
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _HeaderBadge(label: 'Pertemuan $pertemuan'),
                      if (kodeKelas.isNotEmpty)
                        _HeaderBadge(label: 'Kelas $kodeKelas'),
                      _HeaderBadge(
                        label: mode == 'online' ? '💻 Online' : '📍 Tatap Muka'),
                    ],
                  ),

                  // [BARU Fase 8] Tampilkan nama dosen
                  if (dosenNama.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                          color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Text(dosenNama,
                          style: AppTypography.heroSubtitle),
                      ],
                    ),
                  ],

                  if (waktuBuka != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '📅 ${_formatWaktu(waktuBuka)}'
                      '${waktuTutup != null ? "  →  ${_formatWaktu(waktuTutup)}" : "  (masih aktif)"}',
                      style: AppTypography.heroSubtitle),
                  ],
                ],
              ),
            ),
          ),

          // ── Statistik ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Card persentase
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8, offset: const Offset(0, 2))
                      ]),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Persentase Kehadiran',
                              style: AppTypography.bodyBold.copyWith(
                                fontSize: 14, color: AppColors.kNavyDark)),
                            Text(
                              '${persen.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24, color: barColor)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value          : total > 0
                                ? (hadir + terlambat) / total : 0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor     : AlwaysStoppedAnimation<Color>(barColor),
                            minHeight      : 10)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(color: AppColors.kStatusHadir,
                              label: 'Hadir ($hadir)'),
                            const SizedBox(width: 12),
                            _LegendDot(color: AppColors.kStatusTerlambat,
                              label: 'Terlambat ($terlambat)'),
                            const SizedBox(width: 12),
                            _LegendDot(color: AppColors.kStatusAbsen,
                              label: 'Absen ($absen)'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Total $total mahasiswa terdaftar',
                          style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid stat
                  GridView.count(
                    crossAxisCount  : 3,
                    shrinkWrap      : true,
                    physics         : const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing : 8,
                    childAspectRatio: 1.4,
                    children: [
                      _StatMini(label: 'Hadir',    value: hadir,
                        color: AppColors.kStatusHadir),
                      _StatMini(label: 'Terlambat', value: terlambat,
                        color: AppColors.kStatusTerlambat),
                      _StatMini(label: 'Absen',    value: absen,
                        color: AppColors.kStatusAbsen),
                      _StatMini(label: 'Izin',     value: izin,
                        color: AppColors.kStatusIzin),
                      _StatMini(label: 'Sakit',    value: sakit,
                        color: AppColors.kStatusSakit),
                      _StatMini(label: 'Total',    value: total,
                        color: AppColors.kTextSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Header detail ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text('Detail Kehadiran',
                    style: AppTypography.sectionTitle),
                  const Spacer(),
                  Text('${_detail.length} mahasiswa',
                    style: AppTypography.caption),
                ],
              ),
            ),
          ),

          // ── List detail mahasiswa ────────────────────────
          _detail.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('Belum ada data presensi',
                        style: AppTypography.body2)),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final p        = _detail[i];
                      final status   = p['status']          as String? ?? '';
                      final nama     = p['nama']            as String? ?? '-';
                      final nim      = p['nim']             as String? ?? '-';
                      final waktu    = p['waktu_presensi']  as String?;
                      final akurasi  = p['akurasi_wajah']   as double?;
                      final modeK    = p['mode_kelas']      as String? ?? '';
                      final catatan  = p['catatan']         as String?;
                      final isTamu   = p['is_tamu']         as bool?   ?? false;
                      final kelasAsal= p['kelas_asal']      as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Nomor urut
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.kSoftGray,
                                  shape: BoxShape.circle),
                                child: Center(
                                  child: Text('${i + 1}',
                                    style: AppTypography.badge.copyWith(
                                      color: AppColors.kNavy,
                                      fontSize: 12)))),
                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(nama,
                                            style: AppTypography.bodyBold.copyWith(
                                              fontSize: 13),
                                            overflow: TextOverflow.ellipsis)),
                                        if (isTamu) ...[
                                          const SizedBox(width: 6),
                                          const TamuBadge(),
                                        ],
                                      ],
                                    ),
                                    Text(nim, style: AppTypography.caption),
                                    if (isTamu && kelasAsal != null)
                                      Text('dari $kelasAsal',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.kWarning)),
                                    if (waktu != null)
                                      Row(
                                        children: [
                                          Text(_formatWaktu(waktu),
                                            style: AppTypography.caption),
                                          if (akurasi != null) ...[
                                            const SizedBox(width: 6),
                                            Text('${akurasi.toStringAsFixed(1)}%',
                                              style: AppTypography.caption),
                                          ],
                                          const SizedBox(width: 6),
                                          // [BARU Fase 8] ModeBadge kecil
                                          if (modeK.isNotEmpty)
                                            ModeBadge(mode: modeK,
                                              fontSize: 9, showIcon: false),
                                        ],
                                      ),
                                    if (catatan != null && catatan.isNotEmpty)
                                      Text('📝 $catatan',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.kInfo)),
                                  ],
                                ),
                              ),

                              // Status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16)),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10))),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _detail.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET HELPERS
// ══════════════════════════════════════════════════════════════

/// Badge putih transparan untuk header AppBar (info sesi)
class _HeaderBadge extends StatelessWidget {
  final String label;
  const _HeaderBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label,
      style: const TextStyle(
        color: Colors.white, fontSize: 12,
        fontWeight: FontWeight.w600)),
  );
}

class _StatMini extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;

  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2)),
      ]),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22, color: color)),
        Text(label,
          style: AppTypography.caption),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: AppTypography.caption),
    ],
  );
}

class _EksporOptionTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   sub;
  final VoidCallback onTap;

  const _EksporOptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap       : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(
                    color: color, fontWeight: FontWeight.bold,
                    fontSize: 14)),
                Text(sub,
                  style: AppTypography.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
            color: color.withOpacity(0.5)),
        ],
      ),
    ),
  );
}

/// Badge tamu — diambil dari mode_badge.dart (re-export lokal agar file standalone)
class TamuBadge extends StatelessWidget {
  const TamuBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color       : AppColors.kWarning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border      : Border.all(
          color: AppColors.kWarning.withOpacity(0.40), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined,
              size: 10, color: AppColors.kWarning),
          const SizedBox(width: 3),
          Text('Tamu',
            style: AppTypography.badge.copyWith(
              color   : AppColors.kWarning,
              fontSize: 10,
            )),
        ],
      ),
    );
  }
}