// lib/screens/jadwal_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/models/jadwal.dart';

// ─── Konstanta warna (sesuai design system) ───────────────────
const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFF2A5298);
const _kAccent    = Color(0xFF00BFA5);
const _kWarning   = Color(0xFFFFA726);
const _kDanger    = Color(0xFFEF5350);
const _kBgLight   = Color(0xFFF5F7FA);

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

  // ── State: Jadwal Hari Ini ────────────────────────────────
  List<JadwalModel> _jadwalHariIni = [];
  bool   _isLoadingHariIni = true;
  String? _errorHariIni;

  // ── State: Jadwal Mingguan ────────────────────────────────
  Map<String, List<JadwalModel>> _jadwalMingguan = {};
  bool   _isLoadingMingguan = true;
  String? _errorMingguan;

  // Hari yang sedang di-expand di mingguan
  String? _expandedHari;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHariIni();
    _fetchMingguan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final grouped = <String, List<JadwalModel>>{};
        data.forEach((hari, list) {
          grouped[hari] = (list as List<dynamic>)
              .map((e) => JadwalModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        // Default expand ke hari ini
        final hariIni = _namaHariIni();
        setState(() {
          _jadwalMingguan = grouped;
          _expandedHari   = hariIni;
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
    const map = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
      5: 'Jumat', 6: 'Sabtu', 7: 'Minggu',
    };
    return map[DateTime.now().weekday] ?? 'Senin';
  }

  // ── Helper: warna status ──────────────────────────────────
  Color _statusColor(String? status, bool adaSesiAktif) {
    switch (status) {
      case 'hadir'    : return _kAccent;
      case 'terlambat': return _kWarning;
      case 'absen'    : return _kDanger;
      default         : return adaSesiAktif ? _kNavy : Colors.grey.shade400;
    }
  }

  IconData _statusIcon(String? status, bool adaSesiAktif) {
    switch (status) {
      case 'hadir'    : return Icons.check_circle_rounded;
      case 'terlambat': return Icons.access_time_rounded;
      case 'absen'    : return Icons.cancel_rounded;
      default         : return adaSesiAktif
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _kBgLight,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned         : true,
            expandedHeight : 120,
            backgroundColor: _kNavy,
            automaticallyImplyLeading: false,
            elevation      : 0,
            flexibleSpace  : FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin : Alignment.topLeft,
                    end   : Alignment.bottomRight,
                    colors: [_kNavy, _kNavyLight],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jadwal Kuliah',
                          style: TextStyle(
                            color     : Colors.white,
                            fontSize  : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                              .format(DateTime.now()),
                          style: const TextStyle(
                            color  : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller  : _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor  : Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle  : const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
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

  // ─────────────────────────────────────────────────────────
  // TAB 1: Jadwal Hari Ini
  // ─────────────────────────────────────────────────────────

  Widget _buildHariIniTab() {
    if (_isLoadingHariIni) {
      return const Center(child: CircularProgressIndicator(color: _kNavy));
    }
    if (_errorHariIni != null) {
      return _ErrorView(error: _errorHariIni!, onRetry: _fetchHariIni);
    }
    if (_jadwalHariIni.isEmpty) {
      return _EmptyView(
        icon   : Icons.event_available_outlined,
        message: 'Tidak ada jadwal hari ini',
        sub    : 'Nikmati hari libur kuliah kamu 🎉',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHariIni,
      color    : _kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount  : _jadwalHariIni.length,
        itemBuilder: (ctx, i) => _JadwalHariIniCard(
          jadwal     : _jadwalHariIni[i],
          statusColor: _statusColor(
            _jadwalHariIni[i].statusPresensi,
            _jadwalHariIni[i].adaSesiAktif,
          ),
          statusIcon : _statusIcon(
            _jadwalHariIni[i].statusPresensi,
            _jadwalHariIni[i].adaSesiAktif,
          ),
          onPresensi: () => context.go('/scan'),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 2: Jadwal Mingguan
  // ─────────────────────────────────────────────────────────

  Widget _buildMingguanTab() {
    if (_isLoadingMingguan) {
      return const Center(child: CircularProgressIndicator(color: _kNavy));
    }
    if (_errorMingguan != null) {
      return _ErrorView(error: _errorMingguan!, onRetry: _fetchMingguan);
    }

    final hariIni = _namaHariIni();

    return RefreshIndicator(
      onRefresh: _fetchMingguan,
      color    : _kNavy,
      child    : ListView.builder(
        padding    : const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount  : _hariList.length,
        itemBuilder: (ctx, i) {
          final hari     = _hariList[i];
          final items    = _jadwalMingguan[hari] ?? [];
          final isToday  = hari == hariIni;
          final isOpen   = _expandedHari == hari;

          return _HariAccordion(
            hari      : hari,
            items     : items,
            isToday   : isToday,
            isExpanded: isOpen,
            onTap     : () => setState(() =>
              _expandedHari = isOpen ? null : hari),
            statusColor: _statusColor,
            statusIcon : _statusIcon,
            onPresensi : () => context.go('/scan'),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Kartu jadwal hari ini (besar, lengkap)
// ─────────────────────────────────────────────────────────────

class _JadwalHariIniCard extends StatelessWidget {
  final JadwalModel  jadwal;
  final Color        statusColor;
  final IconData     statusIcon;
  final VoidCallback onPresensi;

  const _JadwalHariIniCard({
    required this.jadwal,
    required this.statusColor,
    required this.statusIcon,
    required this.onPresensi,
  });

  @override
  Widget build(BuildContext context) {
    final sesiAktif    = jadwal.adaSesiAktif;
    final sudahPresensi = jadwal.sudahPresensi;

    return Container(
      margin    : const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border      : sesiAktif && !sudahPresensi
            ? Border.all(color: _kNavy.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset    : const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header kartu ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child  : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Garis vertikal warna status
                Container(
                  width : 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color       : statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),

                // Info matakuliah
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color       : _kNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jadwal.kode,
                              style: const TextStyle(
                                color     : _kNavy,
                                fontSize  : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${jadwal.sks} SKS',
                            style: TextStyle(
                              color  : Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        jadwal.nama,
                        style: const TextStyle(
                          color     : _kNavy,
                          fontSize  : 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                            size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            jadwal.labelJam,
                            style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                          ),
                          if (jadwal.ruangan != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.room_outlined,
                              size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                jadwal.ruangan!,
                                style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
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
                _StatusBadge(
                  label: jadwal.labelStatus,
                  color: statusColor,
                  icon : statusIcon,
                ),
              ],
            ),
          ),

          // ── Banner sesi aktif / tombol presensi ────────────
          if (sesiAktif && !sudahPresensi) ...[
            Container(
              margin    : const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding   : const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color       : _kNavy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border      : Border.all(
                  color: _kNavy.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_checked_rounded,
                    color: _kNavy, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sesi sedang berlangsung',
                      style: TextStyle(
                        color     : _kNavy,
                        fontSize  : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onPresensi,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color       : _kNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Presensi',
                        style: TextStyle(
                          color     : Colors.white,
                          fontSize  : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (sudahPresensi) ...[
            Container(
              margin    : const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding   : const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color       : statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    jadwal.statusPresensi == 'hadir'
                        ? 'Presensi tercatat ✓'
                        : jadwal.statusPresensi == 'terlambat'
                            ? 'Tercatat terlambat'
                            : 'Tidak hadir',
                    style: TextStyle(
                      color     : statusColor,
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
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
}

// ─────────────────────────────────────────────────────────────
// Widget: Accordion hari untuk jadwal mingguan
// ─────────────────────────────────────────────────────────────

class _HariAccordion extends StatelessWidget {
  final String   hari;
  final List<JadwalModel> items;
  final bool     isToday;
  final bool     isExpanded;
  final VoidCallback onTap;
  final Color    Function(String?, bool) statusColor;
  final IconData Function(String?, bool) statusIcon;
  final VoidCallback onPresensi;

  const _HariAccordion({
    required this.hari,
    required this.items,
    required this.isToday,
    required this.isExpanded,
    required this.onTap,
    required this.statusColor,
    required this.statusIcon,
    required this.onPresensi,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;

    return Container(
      margin    : const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border      : isToday
            ? Border.all(color: _kNavy.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
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
            onTap        : onTap,
            borderRadius : BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Hari + badge hari ini
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          hari,
                          style: TextStyle(
                            color     : isToday ? _kNavy : Colors.black87,
                            fontSize  : 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color       : _kNavy,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Hari ini',
                              style: TextStyle(
                                color   : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Jumlah matakuliah
                  Text(
                    hasItems ? '${items.length} mk' : 'Libur',
                    style: TextStyle(
                      color  : hasItems
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns   : isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child   : Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade400,
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
                        color       : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.beach_access_rounded,
                            color: Colors.grey.shade300, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tidak ada jadwal',
                            style: TextStyle(
                              color  : Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: items.map((mk) => _MingguanItem(
                        jadwal     : mk,
                        isToday    : isToday,
                        statusColor: statusColor(
                          mk.statusPresensi, mk.adaSesiAktif),
                        statusIcon : statusIcon(
                          mk.statusPresensi, mk.adaSesiAktif),
                        onPresensi : onPresensi,
                      )).toList(),
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
// Widget: Item matakuliah di jadwal mingguan
// ─────────────────────────────────────────────────────────────

class _MingguanItem extends StatelessWidget {
  final JadwalModel  jadwal;
  final bool         isToday;
  final Color        statusColor;
  final IconData     statusIcon;
  final VoidCallback onPresensi;

  const _MingguanItem({
    required this.jadwal,
    required this.isToday,
    required this.statusColor,
    required this.statusIcon,
    required this.onPresensi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin    : const EdgeInsets.only(bottom: 8),
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Jam
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jadwal.jamMulai ?? '-',
                  style: const TextStyle(
                    color     : _kNavy,
                    fontSize  : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  jadwal.jamSelesai ?? '',
                  style: TextStyle(
                    color  : Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Garis vertikal
          Container(
            width : 1,
            height: 36,
            color : Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jadwal.nama,
                  style: const TextStyle(
                    color     : _kNavy,
                    fontSize  : 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (jadwal.ruangan != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    jadwal.ruangan!,
                    style: TextStyle(
                      color  : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status (hanya hari ini)
          if (isToday) ...[
            if (jadwal.adaSesiAktif && !jadwal.sudahPresensi)
              GestureDetector(
                onTap: onPresensi,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color       : _kNavy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Presensi',
                    style: TextStyle(
                      color    : Colors.white,
                      fontSize : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Icon(statusIcon, color: statusColor, size: 20),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Badge status presensi
// ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color       : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color     : color,
              fontSize  : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Empty state
// ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String   message;
  final String   sub;

  const _EmptyView({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color     : _kNavy,
              fontSize  : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget: Error state
// ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
              size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat jadwal',
              style: TextStyle(
                color     : _kNavy,
                fontSize  : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon     : const Icon(Icons.refresh_rounded),
              label    : const Text('Coba Lagi'),
              style    : ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}