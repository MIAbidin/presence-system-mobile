// lib/screens/dosen/dashboard_dosen.dart
// FASE 6 UPDATE:
// - Filter "Tamu" benar-benar filter by is_tamu=true
// - Card peserta lebih lengkap: is_tamu, kelas_asal, akurasi, waktu
// - Tambah tombol Ekspor di header monitor
// - Countdown kode online di header
// - Pull-to-refresh di list sesi aktif
// - Dialog ubah status dengan catatan auto-prefill

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy    = Color(0xFF1E3A5F);
const _kAccent  = Color(0xFF00BFA5);
const _kWarning = Color(0xFFFFA726);
const _kDanger  = Color(0xFFEF5350);
const _kBgLight = Color(0xFFF5F7FA);

class DashboardDosen extends StatefulWidget {
  final String? initialSesiId;
  final void Function(bool)? onSesiAktifChanged;
  final VoidCallback? onGoToBeranda;

  const DashboardDosen({
    super.key,
    this.initialSesiId,
    this.onSesiAktifChanged,
    this.onGoToBeranda,
  });

  @override
  State<DashboardDosen> createState() => DashboardDosenState();
}

class DashboardDosenState extends State<DashboardDosen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // ── State ─────────────────────────────────────────────────
  String? _sesiId;
  List<Map<String, dynamic>> _peserta   = [];
  Map<String, dynamic> _ringkasan       = {'hadir': 0, 'terlambat': 0, 'absen': 0};
  Map<String, dynamic>? _sesiInfo;
  List<Map<String, dynamic>> _sesiAktifList = [];

  bool    _isLoading       = true;
  bool    _isPolling       = false;
  String? _errorMsg;

  Timer?  _pollingTimer;
  Timer?  _countdownTimer;
  int     _countdownDetik  = 0;

  static const _pollInterval = Duration(seconds: 5);

  // Filter: semua | hadir | terlambat | absen | izin | sakit | tamu
  String _filterStatus = 'semua';

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.initialSesiId != null) {
      _sesiId = widget.initialSesiId;
      _fetchPeserta();
      _startPolling();
    } else {
      _fetchSesiAktif();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Public: dipanggil dari MainDosenScreen via GlobalKey ──
  void loadSesi(String sesiId) {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _sesiId       = sesiId;
      _peserta      = [];
      _sesiInfo     = null;
      _filterStatus = 'semua';
      _isLoading    = true;
      _countdownDetik = 0;
    });
    _fetchPeserta();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      if (_sesiId != null && mounted) _fetchPeserta(silent: true);
    });
  }

  void _startCountdown(int detik) {
    _countdownTimer?.cancel();
    _countdownDetik = detik;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdownDetik > 0) _countdownDetik--;
      });
    });
  }

  // ── Fetch sesi aktif ──────────────────────────────────────
  Future<void> _fetchSesiAktif() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/sesi/aktif-dosen');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final list     = (data['sesi_list'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      widget.onSesiAktifChanged?.call(list.isNotEmpty);
      setState(() {
        _sesiAktifList = list;
        _isLoading     = false;
      });
    } on ApiException catch (e) {
      setState(() { _errorMsg = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _isLoading = false; });
    }
  }

  // ── Fetch peserta sesi ────────────────────────────────────
  Future<void> _fetchPeserta({bool silent = false}) async {
    if (_sesiId == null || _isPolling) return;
    if (!silent) setState(() => _isLoading = true);
    _isPolling = true;

    try {
      final response = await ApiClient().get('/sesi/$_sesiId/peserta');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sesiInfo = data;

        // Ambil detik tersisa untuk kode online
        final detikTersisa = data['detik_tersisa'] as int?;

        setState(() {
          _ringkasan = (data['ringkasan'] as Map<String, dynamic>?)
              ?? {'hadir': 0, 'terlambat': 0, 'absen': 0};
          _peserta   = (data['detail'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ?? [];
          _sesiInfo  = sesiInfo;
          _errorMsg  = null;
        });

        // Start countdown jika sesi online dan punya detik tersisa
        if (detikTersisa != null && detikTersisa > 0 && !silent) {
          _startCountdown(detikTersisa);
        }

        widget.onSesiAktifChanged?.call(true);
      }
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted && !silent) setState(() => _errorMsg = e.toString());
    } finally {
      _isPolling = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pilihSesi(String sesiId) => loadSesi(sesiId);

  void _kembaliKeList() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _sesiId         = null;
      _peserta        = [];
      _sesiInfo       = null;
      _countdownDetik = 0;
    });
    _fetchSesiAktif();
  }

  // ── Filter peserta ────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredPeserta {
    if (_filterStatus == 'tamu') {
      return _peserta.where((p) => p['is_tamu'] == true).toList();
    }
    if (_filterStatus == 'semua') return _peserta;
    return _peserta.where((p) => p['status'] == _filterStatus).toList();
  }

  // ── Hitung jumlah per filter ──────────────────────────────
  int _countFilter(String filter) {
    if (filter == 'semua') return _peserta.length;
    if (filter == 'tamu')  return _peserta.where((p) => p['is_tamu'] == true).length;
    return _peserta.where((p) => p['status'] == filter).length;
  }

  // ── Dialog ubah status ────────────────────────────────────
  Future<void> _showUbahStatusDialog(Map<String, dynamic> peserta) async {
    String selectedStatus = peserta['status'] as String? ?? 'hadir';
    final catatanCtrl = TextEditingController(
      text: peserta['catatan'] as String? ?? '',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kNavy.withOpacity(0.1),
                child: Text(
                  (peserta['nama'] as String? ?? '?').isNotEmpty
                      ? (peserta['nama'] as String).substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: _kNavy, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  peserta['nama'] as String? ?? 'Mahasiswa',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize      : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info mahasiswa
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogInfoRow(
                      label: 'NIM',
                      value: peserta['nim'] as String? ?? '-'),
                    if (peserta['is_tamu'] == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200)),
                            child: Text('TAMU',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              peserta['kelas_asal'] as String? ?? '-',
                              style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Status saat ini: ',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              peserta['status'] as String? ?? '').withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            (peserta['status'] as String? ?? '').toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(peserta['status'] as String? ?? ''),
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Ubah Status:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              // Status chips
              Wrap(
                spacing: 6, runSpacing: 6,
                children: ['hadir', 'terlambat', 'absen', 'izin', 'sakit']
                    .map((s) {
                  final sel = selectedStatus == s;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedStatus = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? _statusColor(s)
                            : _statusColor(s).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? _statusColor(s)
                              : _statusColor(s).withOpacity(0.3))),
                      child: Text(s.toUpperCase(),
                        style: TextStyle(
                          color: sel ? Colors.white : _statusColor(s),
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catatanCtrl,
                maxLines  : 2,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText : 'mis: izin dokter, sakit demam...',
                  filled   : true,
                  fillColor: Colors.grey.shade50,
                  border   : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
              child: const Text('Simpan')),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _ubahStatus(
        presensiId: peserta['presensi_id'] as String? ?? '',
        statusBaru: selectedStatus,
        catatan   : catatanCtrl.text.trim(),
      );
    }
  }

  Future<void> _ubahStatus({
    required String presensiId,
    required String statusBaru,
    String? catatan,
  }) async {
    try {
      final response = await ApiClient().patch(
        '/presensi/ubah-status',
        body: {
          'presensi_id': presensiId,
          'status_baru': statusBaru,
          if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
        },
      );
      if (response.statusCode == 200) {
        _showSnack('Status diubah → ${statusBaru.toUpperCase()} ✓');
        await _fetchPeserta();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal ubah status', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  // ── Tutup sesi ────────────────────────────────────────────
  Future<void> _tutupSesi() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: _kDanger, size: 22),
            SizedBox(width: 8),
            Text('Akhiri Sesi?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesi akan ditutup sekarang.', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kDanger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8)),
              child: const Text(
                '⚠️ Mahasiswa yang belum presensi akan otomatis dicatat Absen.',
                style: TextStyle(fontSize: 13, color: _kDanger)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            child: const Text('Ya, Akhiri Sesi')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiClient().post('/sesi/tutup?sesi_id=$_sesiId');
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();
      _showSnack('Sesi berhasil ditutup');
      if (mounted && _sesiId != null) {
        context.go('/dosen/rekap/$_sesiId');
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  // ── Ekspor rekap ──────────────────────────────────────────
  void _showEksporSheet() {
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
            Text(
              '${_sesiInfo?['matakuliah'] ?? ''} · '
              'Pertemuan ${_sesiInfo?['pertemuan_ke'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),
            // Excel
            _EksporOptionTile(
              icon   : Icons.table_chart_rounded,
              color  : Colors.green.shade700,
              label  : 'Ekspor Excel (.xlsx)',
              sub    : 'Tabel lengkap dengan statistik ringkasan',
              onTap  : () {
                Navigator.pop(ctx);
                _downloadEkspor('xlsx');
              },
            ),
            const SizedBox(height: 10),
            // Lihat Rekap
            _EksporOptionTile(
              icon   : Icons.summarize_rounded,
              color  : Colors.blue.shade700,
              label  : 'Lihat Rekap Lengkap',
              sub    : 'Buka halaman rekap detail sesi ini',
              onTap  : () {
                Navigator.pop(ctx);
                if (_sesiId != null) context.go('/dosen/rekap/$_sesiId');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadEkspor(String format) async {
    _showSnack('Membuka rekap & ekspor Excel...');
    if (_sesiId != null) context.go('/dosen/rekap/$_sesiId');
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

  String _formatCountdown(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? _kDanger : Colors.green.shade700,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_sesiId == null) return _buildSesiListView();
    return _buildMonitorView();
  }

  // ── View: List sesi aktif ─────────────────────────────────
  Widget _buildSesiListView() {
    return Scaffold(
      backgroundColor: _kBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color  : _kNavy,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monitor Kehadiran',
                    style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _sesiAktifList.isEmpty
                        ? 'Tidak ada sesi aktif saat ini'
                        : '${_sesiAktifList.length} sesi sedang berlangsung',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kNavy))
                  : _errorMsg != null
                      ? _buildErrorView()
                      : _sesiAktifList.isEmpty
                          ? _buildEmptySesiView()
                          : RefreshIndicator(
                              onRefresh: _fetchSesiAktif,
                              color    : _kNavy,
                              child    : ListView.builder(
                                padding    : const EdgeInsets.all(16),
                                itemCount  : _sesiAktifList.length,
                                itemBuilder: (ctx, i) => _SesiAktifCard(
                                  sesi  : _sesiAktifList[i],
                                  onTap : () =>
                                      _pilihSesi(_sesiAktifList[i]['id'] as String),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySesiView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_outlined,
              size: 72, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            const Text('Tidak ada sesi aktif',
              style: TextStyle(
                color: _kNavy, fontSize: 16,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Buka sesi dari tab Beranda untuk\nmemantau kehadiran mahasiswa',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onGoToBeranda,
              icon : const Icon(Icons.home_rounded),
              label: const Text('Ke Tab Beranda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
              size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(_errorMsg!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSesiAktif,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white),
              child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  // ── View: Monitor satu sesi ───────────────────────────────
  Widget _buildMonitorView() {
    final mk        = _sesiInfo?['matakuliah']    as String? ?? '-';
    final pertemuan = _sesiInfo?['pertemuan_ke']  as int?    ?? 0;
    final mode      = _sesiInfo?['mode']          as String? ?? '-';
    final hadir     = _ringkasan['hadir']      as int? ?? 0;
    final terlambat = _ringkasan['terlambat']  as int? ?? 0;
    final absen     = _ringkasan['absen']      as int? ?? 0;
    final total     = _ringkasan['total']      as int? ?? _peserta.length;

    // Kode sesi (dari sesiInfo)
    final kodeSesi = _sesiInfo?['kode_sesi'] as String?;
    final isOnline = mode == 'online';

    return Scaffold(
      backgroundColor: _kBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              color  : _kNavy,
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
              child  : Column(
                children: [
                  // Baris 1: back + info + live + ekspor + stop
                  Row(
                    children: [
                      IconButton(
                        icon     : const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: _kembaliKeList,
                        tooltip  : 'Kembali ke daftar sesi'),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mk,
                              style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold,
                                fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                            Text(
                              'Pertemuan $pertemuan  ·  '
                              '${isOnline ? "💻 Online" : "📍 Offline"}',
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Badge Live
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent, width: 1)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            const Text('Live',
                              style: TextStyle(
                                color: Colors.greenAccent, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      // Ekspor
                      IconButton(
                        icon     : const Icon(Icons.download_rounded, color: Colors.white70),
                        onPressed: _showEksporSheet,
                        tooltip  : 'Ekspor Rekap'),
                      // Akhiri sesi
                      IconButton(
                        icon     : const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                        onPressed: _tutupSesi,
                        tooltip  : 'Akhiri Sesi'),
                    ],
                  ),

                  // Baris 2: kode sesi countdown (hanya online)
                  if (isOnline && kodeSesi != null && _countdownDetik > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded,
                              color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text('Kode: ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13)),
                            Text(kodeSesi,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3)),
                            const Spacer(),
                            Icon(Icons.timer_outlined,
                              size: 14,
                              color: _countdownDetik < 300
                                  ? Colors.redAccent : Colors.greenAccent),
                            const SizedBox(width: 4),
                            Text(
                              _formatCountdown(_countdownDetik),
                              style: TextStyle(
                                color: _countdownDetik < 300
                                    ? Colors.redAccent : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Stat cards ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(child: _StatCard(
                    label: 'Hadir', value: hadir,
                    color: Colors.green.shade600,
                    icon: Icons.check_circle_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Terlambat', value: terlambat,
                    color: _kWarning,
                    icon: Icons.access_time_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Absen', value: absen,
                    color: _kDanger,
                    icon: Icons.cancel_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Total', value: total,
                    color: Colors.grey.shade600,
                    icon: Icons.people_rounded)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Progress bar kehadiran ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Kehadiran Efektif',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text(
                        total > 0
                            ? '${((hadir + terlambat) / total * 100).toStringAsFixed(0)}%'
                            : '0%',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value     : total > 0
                          ? (hadir + terlambat) / total : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor : AlwaysStoppedAnimation<Color>(
                        Colors.green.shade600),
                      minHeight : 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Filter chips ─────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding        : const EdgeInsets.symmetric(horizontal: 12),
                children       : [
                  'semua', 'hadir', 'terlambat', 'absen', 'izin', 'sakit', 'tamu',
                ].map((f) {
                  final selected = _filterStatus == f;
                  final count    = _countFilter(f);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterStatus = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? (f == 'tamu'
                                  ? Colors.orange.shade700
                                  : f == 'semua' ? _kNavy : _statusColor(f))
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : Colors.grey.shade300)),
                        child: Text(
                          f == 'semua'
                              ? 'Semua ($count)'
                              : f == 'tamu'
                                  ? 'Tamu ($count)'
                                  : '${f[0].toUpperCase()}${f.substring(1)} ($count)',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.bold : FontWeight.normal)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── List peserta ──────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kNavy))
                  : _buildPesertaList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPesertaList() {
    final filtered = _filteredPeserta;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
              size: 56, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Text(
              _filterStatus == 'semua'
                  ? 'Belum ada mahasiswa yang presensi'
                  : _filterStatus == 'tamu'
                      ? 'Tidak ada mahasiswa tamu'
                      : 'Tidak ada dengan status "${_filterStatus.toUpperCase()}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPeserta,
      color    : _kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount  : filtered.length,
        itemBuilder: (ctx, i) {
          final p = filtered[i];
          return _PesertaCard(
            peserta    : p,
            statusColor: _statusColor(p['status'] as String? ?? ''),
            statusIcon : _statusIcon(p['status'] as String? ?? ''),
            formatWaktu: _formatWaktu,
            onTap      : () => _showUbahStatusDialog(p),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Sesi Aktif Card
// ══════════════════════════════════════════════════════════════

class _SesiAktifCard extends StatelessWidget {
  final Map<String, dynamic> sesi;
  final VoidCallback         onTap;

  const _SesiAktifCard({required this.sesi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mk        = sesi['matakuliah']    as String? ?? '-';
    final mode      = sesi['mode']          as String? ?? '-';
    final pertemuan = sesi['pertemuan_ke']  as int?    ?? 0;
    final kode      = sesi['kode_sesi']     as String?;
    final detik     = sesi['detik_tersisa'] as int?;
    final isOnline  = mode == 'online';

    return Card(
      margin    : const EdgeInsets.only(bottom: 12),
      elevation : 2,
      shape     : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child     : InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width : 48, height: 48,
                decoration: BoxDecoration(
                  color: _kNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isOnline
                      ? Icons.video_call_rounded
                      : Icons.location_on_rounded,
                  color: _kNavy, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mk,
                      style: const TextStyle(
                        color: _kNavy, fontSize: 14,
                        fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      'Pertemuan $pertemuan  ·  '
                      '${isOnline ? "💻 Online" : "📍 Offline"}',
                      style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
                    if (kode != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.vpn_key_rounded,
                            size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(kode,
                            style: const TextStyle(
                              color: _kNavy, fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                          if (detik != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: detik < 300
                                    ? _kDanger.withOpacity(0.1)
                                    : _kAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: detik < 300 ? _kDanger : _kAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(10)),
                child: const Text('Monitor',
                  style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Peserta Card (FASE 6 — lebih lengkap)
// ══════════════════════════════════════════════════════════════

class _PesertaCard extends StatelessWidget {
  final Map<String, dynamic>  peserta;
  final Color                 statusColor;
  final IconData              statusIcon;
  final String Function(String?) formatWaktu;
  final VoidCallback          onTap;

  const _PesertaCard({
    required this.peserta,
    required this.statusColor,
    required this.statusIcon,
    required this.formatWaktu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status    = peserta['status']           as String? ?? '';
    final nama      = peserta['nama']             as String? ?? '-';
    final nim       = peserta['nim']              as String? ?? '-';
    final waktu     = peserta['waktu_presensi']   as String?;
    final akurasi   = peserta['akurasi_wajah']    as double?;
    final mode      = peserta['mode_kelas']       as String? ?? '';
    final isTamu    = peserta['is_tamu']          as bool?   ?? false;
    final kelasAsal = peserta['kelas_asal']       as String?;
    final catatan   = peserta['catatan']          as String?;

    final waktuLabel = formatWaktu(waktu);
    final inisial    = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    return Card(
      margin    : const EdgeInsets.only(bottom: 8),
      elevation : 1,
      shape     : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Avatar ──────────────────────────────────────
              Stack(
                children: [
                  CircleAvatar(
                    radius         : 22,
                    backgroundColor: statusColor.withOpacity(0.12),
                    child          : Text(inisial,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                  ),
                  // Dot tamu
                  if (isTamu)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 7, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // ── Info ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama + badge tamu
                    Row(
                      children: [
                        Expanded(
                          child: Text(nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13, color: _kNavy),
                            overflow: TextOverflow.ellipsis),
                        ),
                        if (isTamu) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200)),
                            child: Text('Tamu',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    // NIM
                    Text(nim,
                      style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11)),

                    // Kelas asal (jika tamu)
                    if (isTamu && kelasAsal != null)
                      Text('dari $kelasAsal',
                        style: TextStyle(
                          color: Colors.orange.shade600, fontSize: 10)),

                    // Waktu presensi + akurasi + mode
                    if (waktu != null)
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                            size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text(waktuLabel,
                            style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11)),
                          if (akurasi != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.face_retouching_natural_rounded,
                              size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text('${akurasi.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                          ],
                          const SizedBox(width: 6),
                          Text(mode == 'online' ? '💻' : '📍',
                            style: const TextStyle(fontSize: 11)),
                        ],
                      )
                    else
                      Text('Belum presensi',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),

                    // Catatan (jika ada)
                    if (catatan != null && catatan.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                            size: 11, color: Colors.blue.shade400),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(catatan,
                              style: TextStyle(
                                color: Colors.blue.shade600, fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // ── Status + edit icon ───────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 11),
                        const SizedBox(width: 3),
                        Text(status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.edit_rounded,
                    color: Colors.grey.shade300, size: 13),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Stat Card
// ══════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String   label;
  final int      value;
  final Color    color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text('$value',
          style: TextStyle(
            color: color, fontSize: 20,
            fontWeight: FontWeight.bold)),
        Text(label,
          style: TextStyle(
            color: Colors.grey.shade600, fontSize: 9),
          overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Ekspor Option Tile
// ══════════════════════════════════════════════════════════════

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
                    color: color,
                    fontWeight: FontWeight.bold,
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

// ══════════════════════════════════════════════════════════════
// WIDGET: Dialog Info Row
// ══════════════════════════════════════════════════════════════

class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DialogInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('$label: ',
        style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Expanded(
        child: Text(value,
          style: const TextStyle(
            color: _kNavy, fontSize: 12,
            fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
// WIDGET: Pulse Dot
// ══════════════════════════════════════════════════════════════

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
      vsync: this,
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