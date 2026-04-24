// lib/screens/dosen/dashboard_dosen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/providers/auth_provider.dart';

class DashboardDosen extends StatefulWidget {
  /// sesiData (opsional) — bisa berisi {sesi_id} jika datang dari buka sesi
  final Map<String, dynamic>? sesiData;

  const DashboardDosen({super.key, this.sesiData});

  @override
  State<DashboardDosen> createState() => _DashboardDosenState();
}

class _DashboardDosenState extends State<DashboardDosen> {
  // ── State utama ───────────────────────────────────────────
  String? _sesiId;
  List<Map<String, dynamic>> _peserta    = [];
  Map<String, dynamic>       _ringkasan  = {'hadir': 0, 'terlambat': 0, 'absen': 0};
  Map<String, dynamic>?      _sesiInfo;

  bool   _isLoading    = true;
  bool   _isPolling    = false;
  String? _errorMsg;

  // ── Polling timer ─────────────────────────────────────────
  Timer? _pollingTimer;
  static const _pollInterval = Duration(seconds: 5);

  // ── Filter tab ────────────────────────────────────────────
  String _filterStatus = 'semua'; // 'semua' | 'hadir' | 'terlambat' | 'absen'

  @override
  void initState() {
    super.initState();
    _sesiId = widget.sesiData?['sesi_id'] as String?
           ?? widget.sesiData?['id']      as String?;

    if (_sesiId != null) {
      _fetchPeserta();
      _startPolling();
    } else {
      // Tidak ada sesi yang dipilih — fetch sesi aktif
      _fetchSesiAktif();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      if (_sesiId != null && mounted) _fetchPeserta(silent: true);
    });
  }

  // ── Fetch sesi aktif terakhir dosen ──────────────────────
  Future<void> _fetchSesiAktif() async {
    setState(() => _isLoading = true);
    try {
      // GET /sesi/aktif-dosen — list sesi aktif yang dibuat dosen ini
      final response = await ApiClient().get('/sesi/aktif-dosen');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sesiList = data['sesi_list'] as List<dynamic>? ?? [];
        if (sesiList.isNotEmpty) {
          final sesiTerbaru = sesiList.first as Map<String, dynamic>;
          setState(() {
            _sesiId   = sesiTerbaru['id'] as String;
            _sesiInfo = sesiTerbaru;
          });
          await _fetchPeserta();
          _startPolling();
        } else {
          setState(() {
            _isLoading = false;
            _errorMsg  = 'Tidak ada sesi aktif. Buka sesi terlebih dahulu.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg  = 'Gagal memuat sesi: $e';
      });
    }
  }

  // ── Fetch peserta dari GET /sesi/:id/peserta ──────────────
  Future<void> _fetchPeserta({bool silent = false}) async {
    if (_sesiId == null) return;
    if (!silent) setState(() => _isLoading = true);
    if (_isPolling) return;
    _isPolling = true;

    try {
      final response = await ApiClient().get('/sesi/$_sesiId/peserta');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _ringkasan = (data['ringkasan'] as Map<String, dynamic>?) ??
              {'hadir': 0, 'terlambat': 0, 'absen': 0};
          _peserta   = (data['detail'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ?? [];
          _errorMsg  = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _errorMsg = 'Gagal memuat data: $e');
      }
    } finally {
      _isPolling = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Filter peserta berdasarkan status ─────────────────────
  List<Map<String, dynamic>> get _filteredPeserta {
    if (_filterStatus == 'semua') return _peserta;
    return _peserta.where((p) => p['status'] == _filterStatus).toList();
  }

  // ── Dialog ubah status manual ─────────────────────────────
  Future<void> _showUbahStatusDialog(Map<String, dynamic> peserta) async {
    String selectedStatus = peserta['status'] as String? ?? 'hadir';
    final catatanController = TextEditingController(
      text: peserta['catatan'] as String? ?? '',
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            'Ubah Status: ${peserta['nama'] ?? 'Mahasiswa'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info mahasiswa
              Container(
                padding   : const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color        : Colors.grey.shade100,
                  borderRadius : BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NIM: ${peserta['nim'] ?? '-'}',
                      style: const TextStyle(fontSize: 13)),
                    Text('Status saat ini: ${(peserta['status'] as String? ?? '').toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        color   : _statusColor(peserta['status'] as String? ?? ''),
                        fontWeight: FontWeight.bold,
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dropdown status baru
              const Text('Status Baru:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value    : selectedStatus,
                decoration: InputDecoration(
                  filled   : true,
                  fillColor: Colors.white,
                  border   : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                ),
                items: ['hadir', 'terlambat', 'absen', 'izin', 'sakit'].map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color : _statusColor(s),
                            shape : BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedStatus = val ?? selectedStatus),
              ),
              const SizedBox(height: 12),

              // Keterangan
              TextField(
                controller : catatanController,
                maxLines   : 2,
                decoration : InputDecoration(
                  labelText : 'Keterangan (opsional)',
                  hintText  : 'mis: izin dokter, sakit demam...',
                  filled    : true,
                  fillColor : Colors.white,
                  border    : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _ubahStatus(
        presensiId    : peserta['presensi_id'] as String? ?? '',
        statusBaru    : selectedStatus,
        catatan       : catatanController.text.trim(),
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
        _showSnack('Status berhasil diubah menjadi ${statusBaru.toUpperCase()}');
        await _fetchPeserta();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal ubah status', isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
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

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content         : Text(msg),
      backgroundColor : isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior        : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title          : const Text('Monitor Kehadiran'),
        elevation      : 0,
        actions: [
          // Refresh manual
          IconButton(
            icon   : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _fetchPeserta(),
          ),
          // Logout
          IconButton(
            icon   : const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null && _peserta.isEmpty
              ? _buildErrorView()
              : _buildDashboard(user?.namaLengkap ?? 'Dosen'),

      // FAB ke halaman buka sesi
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/dosen/buka-sesi'),
        icon     : const Icon(Icons.add_rounded),
        label    : const Text('Buka Sesi'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMsg ?? 'Belum ada sesi aktif',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/dosen/buka-sesi'),
              icon : const Icon(Icons.play_circle_rounded),
              label: const Text('Buka Sesi Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding        : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape          : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(String namaDosen) {
    return RefreshIndicator(
      onRefresh: _fetchPeserta,
      child: CustomScrollView(
        slivers: [
          // ── Header info sesi ──────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color  : const Color(0xFF1E3A5F),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius         : 18,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        child          : const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(namaDosen,
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (_sesiInfo != null)
                            Text(
                              '${_sesiInfo!['matakuliah'] ?? ''} — Pertemuan ${_sesiInfo!['pertemuan_ke'] ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Indicator polling aktif
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color       : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border      : Border.all(color: Colors.greenAccent, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _PulseDot(),
                            const SizedBox(width: 4),
                            Text(
                              'Live',
                              style: const TextStyle(
                                color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Ringkasan angka ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _StatCard(
                    label: 'Hadir',
                    value: _ringkasan['hadir']?.toString() ?? '0',
                    color: Colors.green.shade600,
                    icon : Icons.check_circle_rounded,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    label: 'Terlambat',
                    value: _ringkasan['terlambat']?.toString() ?? '0',
                    color: Colors.orange.shade700,
                    icon : Icons.access_time_rounded,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    label: 'Absen',
                    value: _ringkasan['absen']?.toString() ?? '0',
                    color: Colors.red.shade600,
                    icon : Icons.cancel_rounded,
                  )),
                ],
              ),
            ),
          ),

          // ── Filter tab ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['semua', 'hadir', 'terlambat', 'absen', 'izin', 'sakit'].map((f) {
                    final selected = _filterStatus == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label    : Text(f == 'semua' ? 'Semua (${_peserta.length})' : f.toUpperCase()),
                        selected : selected,
                        onSelected: (_) => setState(() => _filterStatus = f),
                        selectedColor: _filterStatus == 'semua'
                            ? const Color(0xFF1E3A5F)
                            : _statusColor(f),
                        labelStyle: TextStyle(
                          color     : selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize  : 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Daftar peserta ────────────────────────────────
          _filteredPeserta.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _filterStatus == 'semua'
                            ? 'Belum ada mahasiswa yang presensi'
                            : 'Tidak ada mahasiswa dengan status "${_filterStatus.toUpperCase()}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final p = _filteredPeserta[i];
                      return _PesertaCard(
                        peserta    : p,
                        statusColor: _statusColor(p['status'] as String? ?? ''),
                        statusIcon : _statusIcon(p['status'] as String? ?? ''),
                        onTap      : () => _showUbahStatusDialog(p),
                      );
                    },
                    childCount: _filteredPeserta.length,
                  ),
                ),

          // Bottom padding untuk FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color        : Colors.white,
        borderRadius : BorderRadius.circular(14),
        boxShadow    : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset    : const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color     : color,
              fontSize  : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Peserta card ──────────────────────────────────────────────

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
    final status   = peserta['status']         as String? ?? '';
    final nama     = peserta['nama']           as String? ?? 'Mahasiswa';
    final nim      = peserta['nim']            as String? ?? '-';
    final waktu    = peserta['waktu_presensi'] as String? ?? '';
    final akurasi  = peserta['akurasi_wajah']  as double?;
    final mode     = peserta['mode_kelas']     as String? ?? '';

    String waktuLabel = '-';
    if (waktu.isNotEmpty) {
      try {
        final dt = DateTime.parse(waktu).toLocal();
        waktuLabel =
            '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } catch (_) {
        waktuLabel = waktu;
      }
    }

    return Card(
      margin    : const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation : 1,
      shape     : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child     : InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap       : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar dengan inisial
              CircleAvatar(
                radius         : 22,
                backgroundColor: statusColor.withOpacity(0.12),
                child          : Text(
                  nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                  style: TextStyle(
                    color     : statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize  : 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info mahasiswa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nim,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    if (akurasi != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Akurasi wajah: ${akurasi.toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),

              // Status & waktu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color       : statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color     : statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize  : 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (waktuLabel != '-') ...[
                    const SizedBox(height: 4),
                    Text(
                      waktuLabel,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                  if (mode.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      mode == 'online' ? '💻' : '📍',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),

              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pulse dot animasi ─────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();

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
      vsync  : this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width : 8, height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}