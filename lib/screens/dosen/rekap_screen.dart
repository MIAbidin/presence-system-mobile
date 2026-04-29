// lib/screens/dosen/rekap_screen.dart
// FASE 6 UPDATE:
// - RekapScreen: tombol ekspor Excel benar-benar download file
// - Tambah share rekap
// - Progress bar lebih informatif
// - Skeleton loading
// - RekapListScreen: tidak ada perubahan signifikan (sudah bagus)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:presensi_app/core/storage.dart';
import 'package:presensi_app/core/constants.dart';
import 'package:share_plus/share_plus.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kAccent  = Color(0xFF00BFA5);
const _kWarning = Color(0xFFFFA726);
const _kDanger  = Color(0xFFEF5350);
const _kBgLight = Color(0xFFF5F7FA);

// ══════════════════════════════════════════════════════════════
// REKAP LIST SCREEN — Tab Rekap (tidak banyak berubah)
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

  String  _filterMk   = 'semua';
  String  _filterMode = 'semua';
  List<String> _mkList = [];

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

      final mkSet = <String>{};
      for (final s in list) {
        final mk = s['matakuliah'] as String? ?? '';
        if (mk.isNotEmpty) mkSet.add(mk);
      }

      setState(() {
        _allSesi   = list;
        _mkList    = mkSet.toList()..sort();
        _isLoading = false;
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
        final mk   = s['matakuliah'] as String? ?? '';
        final mode = s['mode']       as String? ?? '';
        final mkOk   = _filterMk   == 'semua' || mk   == _filterMk;
        final modeOk = _filterMode == 'semua' || mode == _filterMode;
        return mkOk && modeOk;
      }).toList();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aktif'  : return _kAccent;
      case 'selesai': return Colors.grey.shade500;
      default       : return _kNavy;
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
      backgroundColor: _kBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color  : _kNavy,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Rekap Presensi',
                          style: TextStyle(
                            color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                        onPressed: _fetchRiwayat,
                        tooltip  : 'Refresh'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredSesi.length} sesi ditemukan',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),

                  // Filter row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipDropdown(
                          label    : 'Matakuliah',
                          value    : _filterMk,
                          items    : ['semua', ..._mkList],
                          onChanged: (v) {
                            setState(() => _filterMk = v);
                            _applyFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChipDropdown(
                          label    : 'Mode',
                          value    : _filterMode,
                          items    : ['semua', 'offline', 'online'],
                          onChanged: (v) {
                            setState(() => _filterMode = v);
                            _applyFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        if (_filterMk != 'semua' || _filterMode != 'semua')
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _filterMk   = 'semua';
                                _filterMode = 'semua';
                              });
                              _applyFilter();
                            },
                            child: Container(
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

            // Konten
            Expanded(
              child: _isLoading
                  ? _buildSkeleton()
                  : _errorMsg != null
                      ? _buildError()
                      : _filteredSesi.isEmpty
                          ? _buildEmpty()
                          : RefreshIndicator(
                              onRefresh: _fetchRiwayat,
                              color    : _kNavy,
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
        height : 110,
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
          const Text('Gagal memuat rekap',
            style: TextStyle(
              color: _kNavy, fontSize: 16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMsg!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchRiwayat,
            icon : const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white)),
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
        const Text('Belum ada sesi',
          style: TextStyle(
            color: _kNavy, fontSize: 16,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _filterMk != 'semua' || _filterMode != 'semua'
              ? 'Tidak ada sesi yang cocok dengan filter'
              : 'Buka sesi dari tab Beranda untuk mulai mengajar',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ],
    ),
  );
}

// ── Filter chip dropdown (sama seperti sebelumnya) ────────────
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
                    style: const TextStyle(
                      color: _kNavy, fontSize: 16,
                      fontWeight: FontWeight.bold))),
                const Divider(height: 1),
                ...items.map((item) => ListTile(
                  title: Text(_display(item)),
                  trailing: value == item
                      ? const Icon(Icons.check_rounded, color: _kNavy)
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
            color: isActive ? _kNavy : Colors.white38,
            width: isActive ? 1.5 : 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? _display(value) : label,
              style: TextStyle(
                color: isActive ? _kNavy : Colors.white,
                fontSize: 12,
                fontWeight: isActive
                    ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
              color: isActive ? _kNavy : Colors.white,
              size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Rekap List Card ───────────────────────────────────────────
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
    final mk        = sesi['matakuliah']    as String? ?? '-';
    final mode      = sesi['mode']          as String? ?? '-';
    final pertemuan = sesi['pertemuan_ke']  as int?    ?? 0;
    final status    = sesi['status']        as String? ?? '-';
    final waktuBuka = sesi['waktu_buka']    as String?;
    final total     = sesi['total_mhs']     as int?    ?? 0;
    final hadir     = sesi['hadir']         as int?    ?? 0;
    final terlambat = sesi['terlambat']     as int?    ?? 0;
    final absen     = sesi['absen']         as int?    ?? 0;
    final persentase= sesi['persentase']    as double? ?? 0.0;
    final efektif   = hadir + terlambat;

    Color barColor;
    if (persentase >= 75)      barColor = Colors.green.shade600;
    else if (persentase >= 50) barColor = _kWarning;
    else                       barColor = _kDanger;

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
              Row(
                children: [
                  Expanded(
                    child: Text(mk,
                      style: const TextStyle(
                        color: _kNavy, fontSize: 14,
                        fontWeight: FontWeight.bold),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  _InfoBadge(
                    label: 'Pertemuan $pertemuan',
                    color: Colors.blue.shade700,
                    bg   : Colors.blue.shade50),
                  const SizedBox(width: 6),
                  _InfoBadge(
                    label: mode == 'online' ? '💻 Online' : '📍 Offline',
                    color: mode == 'online'
                        ? Colors.purple.shade700 : _kNavy,
                    bg   : mode == 'online'
                        ? Colors.purple.shade50
                        : _kNavy.withOpacity(0.07)),
                  const Spacer(),
                  Text(formatWaktu(waktuBuka),
                    style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value          : total > 0 ? efektif / total : 0,
                  backgroundColor: Colors.grey.shade100,
                  valueColor     : AlwaysStoppedAnimation<Color>(barColor),
                  minHeight      : 6)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatBadge(value: hadir,    label: 'Hadir',
                    color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  _StatBadge(value: terlambat, label: 'Terlambat',
                    color: _kWarning),
                  const SizedBox(width: 8),
                  _StatBadge(value: absen,    label: 'Absen',
                    color: _kDanger),
                  const Spacer(),
                  Text(
                    '${persentase.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: barColor, fontSize: 16,
                      fontWeight: FontWeight.bold)),
                  Text(' /$total',
                    style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;

  const _InfoBadge({required this.label, required this.color, required this.bg});

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

class _StatBadge extends StatelessWidget {
  final int    value;
  final String label;
  final Color  color;

  const _StatBadge({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$value',
        style: TextStyle(color: color, fontSize: 13,
          fontWeight: FontWeight.bold)),
      const SizedBox(width: 3),
      Text(label,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
// REKAP SCREEN — Detail satu sesi (FASE 6: ekspor fungsional)
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
  String? _eksporStatus; // pesan progress ekspor

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

  // ── Ekspor Excel — download file ke device ────────────────
  Future<void> _eksporExcel() async {
    setState(() {
      _isExporting = true;
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

        // Ambil nama file
        final cd = response.headers['content-disposition'] ?? '';
        final match = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);

        final fileName = match?.group(1) ??
            'rekap_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // 📌 SIMPAN KE APP STORAGE (AMAN)
        final dir = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        final filePath = '${dir!.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _isExporting = false;
          _eksporStatus = null;
        });

        // 📌 SHARE FILE (WAJIB untuk iOS, bagus untuk Android)
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Rekap presensi',
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _eksporStatus = null;
      });

      if (mounted) {
        _showSnack('❌ Gagal ekspor: $e', isError: true);
      }
    }
  }


  Future<void> _bukaFile(String path) async {
    // Coba buka file — kalau tidak bisa (tidak ada app), tampilkan path
    try {
      // Gunakan openFile dari package open_file jika tersedia
      // Fallback: tampilkan snackbar dengan path
      _showSnack('File: $path');
    } catch (e) {
      _showSnack('File disimpan di: $path');
    }
  }

  // ── Show ekspor sheet ─────────────────────────────────────
  void _showEksporSheet() {
    final mk        = _sesiInfo['matakuliah']    as String? ?? '-';
    final pertemuan = _sesiInfo['pertemuan_ke']  as int?    ?? 0;

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
            const Text('Ekspor Rekap',
              style: TextStyle(
                color: _kNavy, fontSize: 17,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$mk · Pertemuan $pertemuan',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),

            // Ekspor Excel
            _EksporOptionTile(
              icon : Icons.table_chart_rounded,
              color: Colors.green.shade700,
              label: 'Ekspor Excel (.xlsx)',
              sub  : 'Download file rekap ke perangkat',
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

  // ── Helpers ───────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'hadir'    : return Colors.green.shade600;
      case 'terlambat': return _kWarning;
      case 'absen'    : return _kDanger;
      case 'izin'     : return Colors.blue.shade600;
      case 'sakit'    : return Colors.purple.shade600;
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
      backgroundColor: isError ? _kDanger : Colors.green.shade700,
      behavior       : SnackBarBehavior.floating,
      duration       : const Duration(seconds: 4),
    ));
  }

  void _showSnackWithAction(
    String msg, {
    required String    actionLabel,
    required VoidCallback onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label    : actionLabel,
        textColor: Colors.white,
        onPressed: onAction),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        backgroundColor: _kNavy,
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
          // Progress ekspor
          if (_isExporting)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text(_eksporStatus ?? '...',
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
          style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _fetchRekap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            foregroundColor: Colors.white),
          child: const Text('Coba Lagi')),
      ],
    ),
  );

  Widget _buildContent() {
    final mk        = _sesiInfo['matakuliah']    as String? ?? '-';
    final pertemuan = _sesiInfo['pertemuan_ke']  as int?    ?? 0;
    final mode      = _sesiInfo['mode']          as String? ?? '-';
    final waktuBuka = _sesiInfo['waktu_buka']    as String?;
    final waktuTutup= _sesiInfo['waktu_tutup']   as String?;

    final hadir     = _statistik['hadir']      as int?    ?? 0;
    final terlambat = _statistik['terlambat']  as int?    ?? 0;
    final absen     = _statistik['absen']      as int?    ?? 0;
    final izin      = _statistik['izin']       as int?    ?? 0;
    final sakit     = _statistik['sakit']      as int?    ?? 0;
    final total     = _statistik['total']      as int?    ?? 0;
    final persen    = _statistik['persentase'] as double? ?? 0.0;

    Color barColor;
    if (persen >= 75)      barColor = Colors.green.shade600;
    else if (persen >= 50) barColor = _kWarning;
    else                   barColor = _kDanger;

    return RefreshIndicator(
      onRefresh: _fetchRekap,
      child: CustomScrollView(
        slivers: [
          // Info sesi
          SliverToBoxAdapter(
            child: Container(
              color  : _kNavy,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mk,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _InfoBadge(
                        label: 'Pertemuan $pertemuan',
                        color: Colors.white,
                        bg   : Colors.white.withOpacity(0.2)),
                      _InfoBadge(
                        label: mode == 'online' ? '💻 Online' : '📍 Offline',
                        color: Colors.white,
                        bg   : Colors.white.withOpacity(0.2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (waktuBuka != null)
                    Text(
                      '📅 ${_formatWaktu(waktuBuka)}'
                      '${waktuTutup != null ? "  →  ${_formatWaktu(waktuTutup)}" : "  (masih aktif)"}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12)),
                ],
              ),
            ),
          ),

          // Statistik
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
                            const Text('Persentase Kehadiran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14, color: _kNavy)),
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
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(color: Colors.green.shade600,
                              label: 'Hadir ($hadir)'),
                            const SizedBox(width: 12),
                            _LegendDot(color: _kWarning,
                              label: 'Terlambat ($terlambat)'),
                            const SizedBox(width: 12),
                            _LegendDot(color: _kDanger,
                              label: 'Absen ($absen)'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Total $total mahasiswa terdaftar',
                          style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
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
                        color: Colors.green.shade600),
                      _StatMini(label: 'Terlambat', value: terlambat,
                        color: _kWarning),
                      _StatMini(label: 'Absen',    value: absen,
                        color: _kDanger),
                      _StatMini(label: 'Izin',     value: izin,
                        color: Colors.blue.shade600),
                      _StatMini(label: 'Sakit',    value: sakit,
                        color: Colors.purple.shade600),
                      _StatMini(label: 'Total',    value: total,
                        color: Colors.grey.shade600),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Header detail
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text('Detail Kehadiran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15, color: _kNavy)),
                  const Spacer(),
                  Text('${_detail.length} mahasiswa',
                    style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          ),

          // List detail
          _detail.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('Belum ada data presensi',
                        style: TextStyle(color: Colors.grey.shade400))),
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
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle),
                                child: Center(
                                  child: Text('${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _kNavy)))),
                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(nama,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                            overflow: TextOverflow.ellipsis)),
                                        if (isTamu) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.orange.shade200)),
                                            child: Text('Tamu',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold))),
                                        ],
                                      ],
                                    ),
                                    Text(nim,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11)),
                                    if (isTamu && kelasAsal != null)
                                      Text('dari $kelasAsal',
                                        style: TextStyle(
                                          color: Colors.orange.shade600,
                                          fontSize: 10)),
                                    if (waktu != null)
                                      Row(
                                        children: [
                                          Text(_formatWaktu(waktu),
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 10)),
                                          if (akurasi != null) ...[
                                            const SizedBox(width: 6),
                                            Text('${akurasi.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 10)),
                                          ],
                                          const SizedBox(width: 6),
                                          Text(modeK == 'online' ? '💻' : '📍',
                                            style: const TextStyle(fontSize: 10)),
                                        ],
                                      ),
                                    if (catatan != null && catatan.isNotEmpty)
                                      Text('📝 $catatan',
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 10)),
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

// ── Stat Mini Widget ──────────────────────────────────────────
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
          style: TextStyle(
            color: Colors.grey.shade500, fontSize: 11)),
      ],
    ),
  );
}

// ── Legend dot ────────────────────────────────────────────────
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
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
    ],
  );
}

// ── Ekspor option tile ────────────────────────────────────────
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
                  style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
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