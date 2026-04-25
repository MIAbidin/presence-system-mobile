// lib/screens/dosen/rekap_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';

class RekapScreen extends StatefulWidget {
  final String sesiId;
  const RekapScreen({super.key, required this.sesiId});

  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> {
  bool   _isLoading = true;
  bool   _isExporting = false;
  String? _errorMsg;

  Map<String, dynamic>         _sesiInfo  = {};
  Map<String, dynamic>         _statistik = {};
  List<Map<String, dynamic>>   _detail    = [];

  @override
  void initState() {
    super.initState();
    _fetchRekap();
  }

  Future<void> _fetchRekap() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/presensi/rekap/${widget.sesiId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _sesiInfo  = data;
          _statistik = data['statistik'] as Map<String, dynamic>? ?? {};
          _detail    = (data['detail'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ?? [];
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() => _errorMsg = err['detail'] ?? 'Gagal memuat rekap');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      // Panggil endpoint export — response berupa file Excel
      // Di Flutter, kita download & simpan menggunakan path_provider
      // Untuk sementara tampilkan snackbar sukses
      _showSnack('Fitur ekspor memerlukan package path_provider & open_file. '
                 'Gunakan endpoint: GET /presensi/rekap/${widget.sesiId}/export');
    } finally {
      setState(() => _isExporting = false);
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

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.blue.shade700,
      behavior        : SnackBarBehavior.floating,
      duration        : const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Rekap Presensi'),
        elevation      : 0,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dosen/dashboard'),
        ),
        actions: [
          // Tombol ekspor
          IconButton(
            icon   : _isExporting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            tooltip: 'Ekspor Excel',
            onPressed: _isExporting ? null : _exportExcel,
          ),
          IconButton(
            icon     : const Icon(Icons.refresh_rounded),
            onPressed: _fetchRekap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_errorMsg!),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _fetchRekap, child: const Text('Coba Lagi')),
                  ],
                ))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final mk         = _sesiInfo['matakuliah']   as String? ?? '-';
    final pertemuan  = _sesiInfo['pertemuan_ke'] as int?    ?? 0;
    final mode       = _sesiInfo['mode']         as String? ?? '-';
    final waktuBuka  = _sesiInfo['waktu_buka']   as String?;
    final waktuTutup = _sesiInfo['waktu_tutup']  as String?;

    final hadir     = _statistik['hadir']         as int?    ?? 0;
    final terlambat = _statistik['terlambat']     as int?    ?? 0;
    final absen     = _statistik['absen']         as int?    ?? 0;
    final izin      = _statistik['izin']          as int?    ?? 0;
    final sakit     = _statistik['sakit']         as int?    ?? 0;
    final total     = _statistik['total']         as int?    ?? 0;
    final persen    = _statistik['persentase']    as double? ?? 0.0;

    return RefreshIndicator(
      onRefresh: _fetchRekap,
      child: CustomScrollView(
        slivers: [
          // ── Info sesi ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color  : const Color(0xFF1E3A5F),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mk,
                    style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoChip('Pertemuan $pertemuan'),
                      const SizedBox(width: 8),
                      _InfoChip(mode == 'online' ? '💻 Online' : '📍 Offline'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (waktuBuka != null)
                    Text(
                      'Dibuka: ${_formatWaktu(waktuBuka)}'
                      '${waktuTutup != null ? '  •  Ditutup: ${_formatWaktu(waktuTutup)}' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                ],
              ),
            ),
          ),

          // ── Statistik cards ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Persentase kehadiran
                  Container(
                    padding   : const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color        : Colors.white,
                      borderRadius : BorderRadius.circular(14),
                      boxShadow    : [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8, offset: const Offset(0,2))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Persentase Kehadiran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              '${persen.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize  : 22,
                                color     : persen >= 75
                                    ? Colors.green.shade600
                                    : persen >= 50
                                        ? Colors.orange.shade700
                                        : Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value          : persen / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor     : AlwaysStoppedAnimation<Color>(
                              persen >= 75 ? Colors.green.shade600
                                : persen >= 50 ? Colors.orange.shade700
                                    : Colors.red.shade600),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Total $total mahasiswa terdaftar',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid statistik
                  GridView.count(
                    crossAxisCount    : 3,
                    shrinkWrap        : true,
                    physics           : const NeverScrollableScrollPhysics(),
                    crossAxisSpacing  : 10,
                    mainAxisSpacing   : 10,
                    childAspectRatio  : 1.4,
                    children: [
                      _StatMini(label: 'Hadir',     value: hadir,     color: Colors.green.shade600),
                      _StatMini(label: 'Terlambat', value: terlambat, color: Colors.orange.shade700),
                      _StatMini(label: 'Absen',     value: absen,     color: Colors.red.shade600),
                      _StatMini(label: 'Izin',      value: izin,      color: Colors.blue.shade600),
                      _StatMini(label: 'Sakit',     value: sakit,     color: Colors.purple.shade600),
                      _StatMini(label: 'Total',     value: total,     color: Colors.grey.shade600),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Header daftar ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text('Detail Kehadiran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize  : 15,
                      color     : Color(0xFF1E3A5F))),
                  const Spacer(),
                  Text('${_detail.length} mahasiswa',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          ),

          // ── List mahasiswa ─────────────────────────────
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
                      final p      = _detail[i];
                      final status = p['status'] as String? ?? '';
                      final nama   = p['nama']   as String? ?? '-';
                      final nim    = p['nim']    as String? ?? '-';
                      final waktu  = p['waktu_presensi'] as String?;
                      final akurasi= p['akurasi_wajah']  as double?;
                      final mode   = p['mode_kelas']     as String? ?? '';
                      final catatan= p['catatan']        as String?;

                      return Card(
                        margin   : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 1,
                        shape    : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Nomor urut
                              Container(
                                width : 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i+1}',
                                    style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 10),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nama,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(nim,
                                      style: TextStyle(
                                        color: Colors.grey.shade500, fontSize: 12)),
                                    if (waktu != null)
                                      Text(
                                        '${_formatWaktu(waktu)}  •  ${mode == 'online' ? '💻' : '📍'}'
                                        '${akurasi != null ? '  •  ${akurasi.toStringAsFixed(1)}%' : ''}',
                                        style: TextStyle(
                                          color: Colors.grey.shade500, fontSize: 11)),
                                    if (catatan != null && catatan.isNotEmpty)
                                      Text('📝 $catatan',
                                        style: TextStyle(
                                          color: Colors.blue.shade600, fontSize: 11)),
                                  ],
                                ),
                              ),

                              // Status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color       : _statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color     : _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize  : 11,
                                  ),
                                ),
                              ),
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

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color       : Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label,
      style: const TextStyle(color: Colors.white, fontSize: 12)),
  );
}

class _StatMini extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding   : const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color        : Colors.white,
      borderRadius : BorderRadius.circular(12),
      boxShadow    : [BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 6, offset: const Offset(0,2))],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize  : 22,
            color     : color,
          ),
        ),
        Text(label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    ),
  );
}