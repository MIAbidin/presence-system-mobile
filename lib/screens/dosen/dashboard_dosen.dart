// lib/screens/dosen/dashboard_dosen.dart
// UPDATE Fase 4 — Dijadikan tab Monitor dalam MainDosenScreen
// Perubahan:
// - Tambah AutomaticKeepAliveClientMixin
// - Hapus appBar (sudah di MainDosenScreen level atas tidak ada appBar global,
//   tapi tambah header internal)
// - Tambah parameter initialSesiId, onSesiAktifChanged, onGoToBeranda
// - Expose loadSesi() via GlobalKey agar MainDosenScreen bisa trigger dari luar
// - Empty state arahkan ke tab Beranda bukan FAB ke /dosen/buka-sesi

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
  /// Jika tidak null, langsung load peserta sesi ini saat init
  final String? initialSesiId;

  /// Callback ke MainDosenScreen: update badge sesi aktif di bottom nav
  final void Function(bool)? onSesiAktifChanged;

  /// Callback ke MainDosenScreen: pindah ke tab Beranda
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

// State di-expose (public) agar GlobalKey bisa akses loadSesi()
class DashboardDosenState extends State<DashboardDosen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // ── State ─────────────────────────────────────────────────
  String? _sesiId;
  List<Map<String, dynamic>> _peserta   = [];
  Map<String, dynamic> _ringkasan       = {
    'hadir': 0, 'terlambat': 0, 'absen': 0};
  Map<String, dynamic>? _sesiInfo;

  // List sesi aktif (ditampilkan saat _sesiId null)
  List<Map<String, dynamic>> _sesiAktifList = [];

  bool    _isLoading       = true;
  bool    _isPolling       = false;
  bool    _isLoadingSesi   = false;
  String? _errorMsg;

  Timer?  _pollingTimer;
  static const _pollInterval = Duration(seconds: 5);

  String _filterStatus = 'semua';

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
    super.dispose();
  }

  // ── Public method — dipanggil dari MainDosenScreen via GlobalKey ──
  void loadSesi(String sesiId) {
    _pollingTimer?.cancel();
    setState(() {
      _sesiId      = sesiId;
      _peserta     = [];
      _sesiInfo    = null;
      _filterStatus= 'semua';
      _isLoading   = true;
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

  // ── Fetch sesi aktif dosen (jika tidak ada sesiId) ────────
  Future<void> _fetchSesiAktif() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final response = await ApiClient().get('/sesi/aktif-dosen');
      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final list     = (data['sesi_list'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Update badge di bottom nav
      widget.onSesiAktifChanged?.call(list.isNotEmpty);

      if (list.isNotEmpty) {
        setState(() {
          _sesiAktifList = list;
          _isLoading     = false;
        });
      } else {
        widget.onSesiAktifChanged?.call(false);
        setState(() {
          _sesiAktifList = [];
          _isLoading     = false;
        });
      }
    } on ApiException catch (e) {
      setState(() { _errorMsg = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _isLoading = false; });
    }
  }

  // ── Fetch peserta sesi ────────────────────────────────────
  Future<void> _fetchPeserta({bool silent = false}) async {
    if (_sesiId == null) return;
    if (_isPolling) return;
    if (!silent) setState(() => _isLoading = true);
    _isPolling = true;

    try {
      final response =
          await ApiClient().get('/sesi/$_sesiId/peserta');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _ringkasan = (data['ringkasan'] as Map<String, dynamic>?)
              ?? {'hadir': 0, 'terlambat': 0, 'absen': 0};
          _peserta   = (data['detail'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ?? [];
          _sesiInfo  = data;
          _errorMsg  = null;
        });
        // Update badge
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

  // ── Pilih sesi dari list ───────────────────────────────────
  void _pilihSesi(String sesiId) {
    loadSesi(sesiId);
  }

  // ── Kembali ke list sesi ───────────────────────────────────
  void _kembaliKeList() {
    _pollingTimer?.cancel();
    setState(() {
      _sesiId   = null;
      _peserta  = [];
      _sesiInfo = null;
    });
    _fetchSesiAktif();
  }

  // ── Filter ────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredPeserta {
    if (_filterStatus == 'semua') return _peserta;
    return _peserta
        .where((p) => p['status'] == _filterStatus)
        .toList();
  }

  // ── Dialog ubah status ────────────────────────────────────
  Future<void> _showUbahStatusDialog(
      Map<String, dynamic> peserta) async {
    String selectedStatus =
        peserta['status'] as String? ?? 'hadir';
    final catatanCtrl = TextEditingController(
      text: peserta['catatan'] as String? ?? '',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(
            'Ubah Status: ${peserta['nama'] ?? 'Mahasiswa'}',
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize      : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info mahasiswa
              Container(
                padding   : const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color       : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIM: ${peserta['nim'] ?? '-'}',
                      style: const TextStyle(fontSize: 12)),
                    Text(
                      'Status: ${(peserta['status'] as String? ?? '').toUpperCase()}',
                      style: TextStyle(
                        fontSize  : 12,
                        color     : _statusColor(
                          peserta['status'] as String? ?? ''),
                        fontWeight: FontWeight.bold)),
                    if (peserta['is_tamu'] == true)
                      Text(
                        'Tamu dari: ${peserta['kelas_asal'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 11,
                          color   : Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Status Baru:',
                style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value    : selectedStatus,
                decoration: InputDecoration(
                  filled   : true,
                  fillColor: Colors.white,
                  border   : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                ),
                items: [
                  'hadir', 'terlambat', 'absen', 'izin', 'sakit',
                ].map((s) => DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Container(
                        width : 10, height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(s),
                          shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(s.toUpperCase(),
                        style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )).toList(),
                onChanged: (v) => setModal(
                    () => selectedStatus = v ?? selectedStatus),
              ),
              const SizedBox(height: 10),
              TextField(
                controller : catatanCtrl,
                maxLines   : 2,
                decoration : InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText : 'mis: izin dokter...',
                  filled   : true,
                  fillColor: Colors.white,
                  border   : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
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
                foregroundColor: Colors.white),
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
          if (catatan != null && catatan.isNotEmpty)
            'catatan': catatan,
        },
      );
      if (response.statusCode == 200) {
        _showSnack('Status diubah → ${statusBaru.toUpperCase()}');
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
        title  : const Text('Akhiri Sesi?',
          style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Sesi akan ditutup. Mahasiswa yang belum presensi '
          'akan dicatat Absen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white),
            child: const Text('Akhiri Sesi')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiClient().post('/sesi/tutup?sesi_id=$_sesiId');
      _showSnack('Sesi berhasil ditutup');
      // Navigasi ke rekap
      if (mounted && _sesiId != null) {
        context.go('/dosen/rekap/$_sesiId');
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

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

    // Jika tidak ada sesiId → tampilkan list sesi aktif
    if (_sesiId == null) {
      return _buildSesiListView();
    }

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
                        ? 'Tidak ada sesi aktif'
                        : '${_sesiAktifList.length} sesi sedang aktif',
                    style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kNavy))
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
                                itemBuilder: (ctx, i) {
                                  final s = _sesiAktifList[i];
                                  return _SesiAktifCard(
                                    sesi   : s,
                                    onTap  : () =>
                                        _pilihSesi(s['id'] as String),
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
              'Buka sesi dari tab Beranda untuk mulai\nmemantau kehadiran mahasiswa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onGoToBeranda,
              icon : const Icon(Icons.home_rounded),
              label: const Text('Ke Tab Beranda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
    );
  }

  // ── View: Monitor satu sesi ───────────────────────────────
  Widget _buildMonitorView() {
    final mk         = _sesiInfo?['matakuliah']    as String? ?? '-';
    final pertemuan  = _sesiInfo?['pertemuan_ke']  as int?    ?? 0;
    final mode       = _sesiInfo?['mode']          as String? ?? '-';
    final hadir      = _ringkasan['hadir']      as int? ?? 0;
    final terlambat  = _ringkasan['terlambat']  as int? ?? 0;
    final absen      = _ringkasan['absen']      as int? ?? 0;

    return Scaffold(
      backgroundColor: _kBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              color  : _kNavy,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child  : Column(
                children: [
                  Row(
                    children: [
                      // Tombol kembali ke list
                      IconButton(
                        icon     : const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white),
                        onPressed: _kembaliKeList,
                        tooltip  : 'Kembali ke daftar sesi',
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mk,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                            Text(
                              'Pertemuan $pertemuan  ·  '
                              '${mode == 'online' ? '💻 Online' : '📍 Offline'}',
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Badge live
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.greenAccent, width: 1)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            const Text('Live',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol akhiri sesi
                      IconButton(
                        icon     : const Icon(
                          Icons.stop_circle_rounded,
                          color: Colors.redAccent),
                        onPressed: _tutupSesi,
                        tooltip  : 'Akhiri Sesi',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Stat cards ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: _StatCard(
                    label: 'Hadir',
                    value: hadir,
                    color: Colors.green.shade600,
                    icon : Icons.check_circle_rounded,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Terlambat',
                    value: terlambat,
                    color: _kWarning,
                    icon : Icons.access_time_rounded,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Absen',
                    value: absen,
                    color: _kDanger,
                    icon : Icons.cancel_rounded,
                  )),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'semua', 'hadir', 'terlambat',
                    'absen', 'izin', 'sakit', 'tamu',
                  ].map((f) {
                    final selected = _filterStatus == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          f == 'semua'
                              ? 'Semua (${_peserta.length})'
                              : f == 'tamu'
                                  ? 'Tamu'
                                  : f.toUpperCase(),
                          style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() {
                              // Filter tamu tidak filter by status
                              // tapi by is_tamu = true
                              _filterStatus = f;
                            }),
                        selectedColor: f == 'semua'
                            ? _kNavy
                            : f == 'tamu'
                                ? Colors.orange.shade700
                                : _statusColor(f),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── List peserta ──────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _kNavy))
                  : _buildPesertaList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPesertaList() {
    // Filter tamu khusus
    List<Map<String, dynamic>> filtered;
    if (_filterStatus == 'tamu') {
      filtered = _peserta
          .where((p) => p['is_tamu'] == true)
          .toList();
    } else {
      filtered = _filteredPeserta;
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _filterStatus == 'semua'
              ? 'Belum ada mahasiswa yang presensi'
              : 'Tidak ada dengan status "${_filterStatus.toUpperCase()}"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500)),
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
            onTap      : () => _showUbahStatusDialog(p),
          );
        },
      ),
    );
  }
}

// ─── Widget: Card sesi aktif (pilih sesi) ─────────────────────

class _SesiAktifCard extends StatelessWidget {
  final Map<String, dynamic> sesi;
  final VoidCallback         onTap;

  const _SesiAktifCard({required this.sesi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mk         = sesi['matakuliah']   as String? ?? '-';
    final mode       = sesi['mode']         as String? ?? '-';
    final pertemuan  = sesi['pertemuan_ke'] as int?    ?? 0;
    final kode       = sesi['kode_sesi']    as String?;
    final detik      = sesi['detik_tersisa'] as int?;

    return Card(
      margin    : const EdgeInsets.only(bottom: 10),
      elevation : 2,
      shape     : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14)),
      child     : InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ikon mode
              Container(
                width : 44, height: 44,
                decoration: BoxDecoration(
                  color: _kNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  mode == 'online'
                      ? Icons.video_call_rounded
                      : Icons.location_on_rounded,
                  color: _kNavy, size: 22),
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
                      '${mode == 'online' ? '💻 Online' : '📍 Offline'}',
                      style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
                    if (kode != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text('Kode: ',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11)),
                          Text(kode,
                            style: const TextStyle(
                              color: _kNavy, fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2)),
                          if (detik != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: detik < 300
                                    ? _kDanger : _kAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(8)),
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

// ─── Widget: Stat card ────────────────────────────────────────

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
    padding   : const EdgeInsets.symmetric(
      vertical: 12, horizontal: 8),
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text('$value',
          style: TextStyle(
            color: color, fontSize: 24,
            fontWeight: FontWeight.bold)),
        Text(label,
          style: TextStyle(
            color: Colors.grey.shade600, fontSize: 11)),
      ],
    ),
  );
}

// ─── Widget: Peserta card ─────────────────────────────────────

class _PesertaCard extends StatelessWidget {
  final Map<String, dynamic> peserta;
  final Color    statusColor;
  final IconData statusIcon;
  final VoidCallback onTap;

  const _PesertaCard({
    required this.peserta,
    required this.statusColor,
    required this.statusIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status  = peserta['status']          as String? ?? '';
    final nama    = peserta['nama']            as String? ?? '-';
    final nim     = peserta['nim']             as String? ?? '-';
    final waktu   = peserta['waktu_presensi']  as String? ?? '';
    final akurasi = peserta['akurasi_wajah']   as double?;
    final mode    = peserta['mode_kelas']      as String? ?? '';
    final isTamu  = peserta['is_tamu']         as bool?   ?? false;
    final kelasAsal = peserta['kelas_asal']    as String?;

    String waktuLabel = '-';
    if (waktu.isNotEmpty) {
      try {
        final dt    = DateTime.parse(waktu).toLocal();
        waktuLabel  = '${dt.hour.toString().padLeft(2, '0')}:'
                      '${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        waktuLabel = waktu;
      }
    }

    return Card(
      margin    : const EdgeInsets.only(bottom: 6),
      elevation : 1,
      shape     : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
      child     : InkWell(
        onTap       : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius         : 20,
                backgroundColor: statusColor.withOpacity(0.12),
                child          : Text(
                  nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                        if (isTamu) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange.shade200)),
                            child: Text('Tamu',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(nim,
                      style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11)),
                    if (isTamu && kelasAsal != null)
                      Text('dari $kelasAsal',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 10)),
                    if (akurasi != null)
                      Text(
                        '${waktuLabel != '-' ? '$waktuLabel  ·  ' : ''}'
                        '${akurasi.toStringAsFixed(0)}%  ·  '
                        '${mode == 'online' ? '💻' : '📍'}',
                        style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 10)),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon,
                          color: statusColor, size: 11),
                        const SizedBox(width: 3),
                        Text(status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10)),
                      ],
                    ),
                  ),
                  if (waktuLabel != '-') ...[
                    const SizedBox(height: 3),
                    Text(waktuLabel,
                      style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded,
                color: Colors.grey.shade300, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulse dot ────────────────────────────────────────────────

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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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