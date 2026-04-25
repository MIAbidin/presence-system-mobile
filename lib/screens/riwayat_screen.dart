// lib/screens/riwayat_screen.dart

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  bool   _isLoading = true;
  String? _errorMsg;

  Map<String, dynamic>  _statistik = {};
  List<Map<String, dynamic>> _riwayat = [];

  // Grouped by matakuliah: { 'Pemrograman Mobile': [presensi, ...], ... }
  Map<String, List<Map<String, dynamic>>> _grouped = {};

  // Which matakuliah is expanded
  String? _expandedMk;

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/presensi/riwayat');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['riwayat'] as List? ?? [];
        final stats = data['statistik'] as Map<String, dynamic>? ?? {};

        // Group by matakuliah name
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final item in list) {
          final mk = item['matakuliah'] as String? ?? 'Tidak diketahui';
          grouped.putIfAbsent(mk, () => []);
          grouped[mk]!.add(item as Map<String, dynamic>);
        }

        setState(() {
          _statistik = stats;
          _riwayat   = list.cast<Map<String, dynamic>>();
          _grouped   = grouped;
          if (grouped.isNotEmpty) _expandedMk = grouped.keys.first;
        });
      } else {
        setState(() => _errorMsg = 'Gagal memuat riwayat');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'hadir'    : return Colors.green.shade600;
      case 'terlambat': return Colors.orange.shade700;
      case 'absen'    : return Colors.red.shade600;
      case 'izin'     : return Colors.blue.shade600;
      case 'sakit'    : return Colors.purple.shade600;
      default         : return Colors.grey;
    }
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
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  '
             '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }

  // Hitung persentase per matakuliah
  double _hitungPersen(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return 0;
    final efektif = list.where((p) =>
      p['status'] == 'hadir' || p['status'] == 'terlambat').length;
    return efektif / list.length * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Riwayat Kehadiran'),
        elevation      : 0,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scan'),
        ),
        actions: [
          IconButton(
            icon     : const Icon(Icons.refresh_rounded),
            onPressed: _fetchRiwayat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? _buildError()
              : _riwayat.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(_errorMsg!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _fetchRiwayat, child: const Text('Coba Lagi')),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history_edu_rounded, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('Belum ada riwayat kehadiran',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Lakukan presensi terlebih dahulu',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ],
    ),
  );

  Widget _buildContent() {
    final total     = _statistik['total']         as int?    ?? 0;
    final hadir     = _statistik['hadir']         as int?    ?? 0;
    final terlambat = _statistik['terlambat']     as int?    ?? 0;
    final absen     = _statistik['absen']         as int?    ?? 0;
    final persen    = _statistik['persentase']    as double? ?? 0.0;

    return RefreshIndicator(
      onRefresh: _fetchRiwayat,
      child: CustomScrollView(
        slivers: [
          // ── Ringkasan global ────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color  : const Color(0xFF1E3A5F),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child  : Column(
                children: [
                  // Donut chart + legend
                  SizedBox(
                    height: 180,
                    child : Row(
                      children: [
                        // Chart
                        SizedBox(
                          width : 160,
                          child : total == 0
                              ? const Center(
                                  child: Text('Tidak ada data',
                                    style: TextStyle(color: Colors.white54)))
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    sections: [
                                      PieChartSectionData(
                                        value: hadir.toDouble(),
                                        color: Colors.greenAccent,
                                        title: hadir > 0 ? '$hadir' : '',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: terlambat.toDouble(),
                                        color: Colors.orangeAccent,
                                        title: terlambat > 0 ? '$terlambat' : '',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: absen.toDouble(),
                                        color: Colors.redAccent,
                                        title: absen > 0 ? '$absen' : '',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        // Legend + persentase besar
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${persen.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color     : Colors.white,
                                  fontSize  : 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Kehadiran Efektif',
                                style: TextStyle(color: Colors.white60, fontSize: 13)),
                              const SizedBox(height: 12),
                              _LegendItem(color: Colors.greenAccent,  label: 'Hadir ($hadir)'),
                              _LegendItem(color: Colors.orangeAccent, label: 'Terlambat ($terlambat)'),
                              _LegendItem(color: Colors.redAccent,    label: 'Absen ($absen)'),
                              _LegendItem(color: Colors.white38,      label: 'Total ($total)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── List matakuliah ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Detail per Matakuliah (${_grouped.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize  : 15,
                  color     : Color(0xFF1E3A5F),
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, idx) {
                final mkName = _grouped.keys.elementAt(idx);
                final items  = _grouped[mkName]!;
                final pct    = _hitungPersen(items);
                final isOpen = _expandedMk == mkName;

                return _MatakuliahCard(
                  mkName     : mkName,
                  items      : items,
                  persentase : pct,
                  isExpanded : isOpen,
                  onTap      : () => setState(() =>
                    _expandedMk = isOpen ? null : mkName),
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
}

// ── Matakuliah expandable card ────────────────────────────────

class _MatakuliahCard extends StatelessWidget {
  final String mkName;
  final List<Map<String, dynamic>> items;
  final double persentase;
  final bool   isExpanded;
  final VoidCallback onTap;
  final Color  Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String?) formatWaktu;

  const _MatakuliahCard({
    required this.mkName,
    required this.items,
    required this.persentase,
    required this.isExpanded,
    required this.onTap,
    required this.statusColor,
    required this.statusIcon,
    required this.formatWaktu,
  });

  Color get _barColor {
    if (persentase >= 75) return Colors.green.shade600;
    if (persentase >= 50) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin    : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation : 1,
      shape     : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child     : InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap       : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mkName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('${items.length} pertemuan',
                          style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Persentase badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color       : _barColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${persentase.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color     : _barColor,
                        fontWeight: FontWeight.bold,
                        fontSize  : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value          : persentase / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor     : AlwaysStoppedAnimation<Color>(_barColor),
                  minHeight      : 8,
                ),
              ),

              // Expanded detail
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

class _PertemuanRow extends StatelessWidget {
  final Map<String, dynamic> item;
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
    final status     = item['status']         as String? ?? '';
    final pertemuan  = item['pertemuan_ke']   as int?    ?? 0;
    final waktu      = item['waktu_presensi'] as String?;
    final mode       = item['mode_kelas']     as String? ?? '';
    final akurasi    = item['akurasi_wajah']  as double?;
    final catatan    = item['catatan']        as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Nomor pertemuan
          Container(
            width : 32,
            height: 32,
            decoration: BoxDecoration(
              color       : statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$pertemuan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color     : statusColor(status),
                  fontSize  : 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waktu & mode
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waktu != null ? formatWaktu(waktu) : 'Tidak hadir',
                  style: TextStyle(
                    fontSize: 12,
                    color   : waktu != null ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (akurasi != null)
                  Text(
                    'Akurasi: ${akurasi.toStringAsFixed(1)}%  •  ${mode == 'online' ? '💻 Online' : '📍 Offline'}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                if (catatan != null && catatan.isNotEmpty)
                  Text('📝 $catatan',
                    style: TextStyle(color: Colors.blue.shade600, fontSize: 11)),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color       : statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon(status), color: statusColor(status), size: 12),
                const SizedBox(width: 3),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color     : statusColor(status),
                    fontSize  : 10,
                    fontWeight: FontWeight.bold,
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
            width : 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}