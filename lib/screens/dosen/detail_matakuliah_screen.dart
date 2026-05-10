// lib/screens/dosen/detail_matakuliah_screen.dart
// FASE 7 UPDATE:
// - 7.1: Tab Kelas BARU (index 3) — list kelas A/B/C + mahasiswa per kelas
//         via GET /kelas/mahasiswa/{kelas_id}
// - 7.2: Field MODE (Offline/Online) WAJIB di form jadwal pengganti
//         + validasi client-side jam selesai > jam mulai
//         + indikator pertemuan yang sudah punya jadwal pengganti
//
// Total tab: 4 (Mahasiswa | Jadwal | Riwayat | Kelas)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/widgets/kelas_badge.dart';
import 'package:presensi_app/widgets/mode_badge.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy    = Color(0xFF003366); // UMS Navy (tema baru)
const _kAccent  = Color(0xFF2D6A4F); // UMS Green
const _kGold    = Color(0xFFFDB813); // UMS Gold
const _kWarning = Color(0xFFFFA726);
const _kDanger  = Color(0xFFEF5350);
const _kPurple  = Color(0xFF7C3AED);
const _kBgLight = Color(0xFFF8F9FA); // UMS BgLight

// ══════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════

class MatakuliahDetail {
  final String  id;
  final String  kode;
  final String  nama;
  final int     sks;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final String? ruangan;
  final double? koordinatLat;
  final double? koordinatLng;
  final bool    izinTamu;
  final int     totalAsli;
  final int     totalTamu;
  final List<MahasiswaItem>       mahasiswa;
  final List<JadwalPenggantiItem> jadwalPengganti;
  final List<RiwayatSesiItem>     riwayatSesi;

  // [BARU 7.1] List kelas (A/B/C) yang ada di MK ini
  final List<KelasItem>           kelasList;

  const MatakuliahDetail({
    required this.id,
    required this.kode,
    required this.nama,
    required this.sks,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.ruangan,
    this.koordinatLat,
    this.koordinatLng,
    required this.izinTamu,
    required this.totalAsli,
    required this.totalTamu,
    required this.mahasiswa,
    required this.jadwalPengganti,
    required this.riwayatSesi,
    this.kelasList = const [],
  });

  factory MatakuliahDetail.fromJson(Map<String, dynamic> j) =>
      MatakuliahDetail(
        id              : j['matakuliah_id']   as String,
        kode            : j['kode']            as String,
        nama            : j['nama']            as String,
        sks             : j['sks']             as int,
        hari            : j['hari']            as String?,
        jamMulai        : j['jam_mulai']       as String?,
        jamSelesai      : j['jam_selesai']     as String?,
        ruangan         : j['ruangan']         as String?,
        koordinatLat    : (j['koordinat_lat']  as num?)?.toDouble(),
        koordinatLng    : (j['koordinat_lng']  as num?)?.toDouble(),
        izinTamu        : j['izin_tamu']       as bool? ?? false,
        totalAsli       : j['total_asli']      as int?  ?? 0,
        totalTamu       : j['total_tamu']      as int?  ?? 0,
        mahasiswa       : ((j['mahasiswa']       as List<dynamic>?) ?? [])
            .map((e) => MahasiswaItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        jadwalPengganti : ((j['jadwal_pengganti'] as List<dynamic>?) ?? [])
            .map((e) => JadwalPenggantiItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        riwayatSesi     : ((j['riwayat_sesi']    as List<dynamic>?) ?? [])
            .map((e) => RiwayatSesiItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        // [BARU 7.1] parse kelas_list dari response jika ada
        kelasList       : ((j['kelas_list']      as List<dynamic>?) ?? [])
            .map((e) => KelasItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MahasiswaItem {
  final String  mahasiswaId;
  final String  nim;
  final String  namaLengkap;
  final String  programStudi;
  final bool    isTamu;
  final String? kelasAsal;

  const MahasiswaItem({
    required this.mahasiswaId,
    required this.nim,
    required this.namaLengkap,
    required this.programStudi,
    required this.isTamu,
    this.kelasAsal,
  });

  factory MahasiswaItem.fromJson(Map<String, dynamic> j) => MahasiswaItem(
    mahasiswaId : j['mahasiswa_id']  as String,
    nim         : j['nim']           as String,
    namaLengkap : j['nama_lengkap']  as String,
    programStudi: j['program_studi'] as String,
    isTamu      : j['is_tamu']       as bool? ?? false,
    kelasAsal   : j['kelas_asal']    as String?,
  );

  String get inisial => namaLengkap.isNotEmpty
      ? namaLengkap.trim().split(' ').take(2).map((w) => w[0]).join()
      : '?';
}

// ── [BARU 7.1] Model Kelas ────────────────────────────────────

class KelasItem {
  final String  id;
  final String  kodeKelas;
  final String? dosenNama;
  final String? ruanganNama;
  final String? hari;
  final String? jamMulai;
  final String? jamSelesai;
  final int?    slotMulai;
  final int?    slotSelesai;
  final bool    izinTamu;
  final int     enrolled;

  const KelasItem({
    required this.id,
    required this.kodeKelas,
    this.dosenNama,
    this.ruanganNama,
    this.hari,
    this.jamMulai,
    this.jamSelesai,
    this.slotMulai,
    this.slotSelesai,
    this.izinTamu = false,
    this.enrolled = 0,
  });

  factory KelasItem.fromJson(Map<String, dynamic> j) => KelasItem(
    id          : j['id']           as String,
    kodeKelas   : j['kode_kelas']   as String? ?? '',
    dosenNama   : j['dosen_nama']   as String?,
    ruanganNama : j['ruangan_nama'] as String?,
    hari        : j['hari']         as String?,
    jamMulai    : j['jam_mulai']    as String?,
    jamSelesai  : j['jam_selesai']  as String?,
    slotMulai   : j['slot_mulai']   as int?,
    slotSelesai : j['slot_selesai'] as int?,
    izinTamu    : j['izin_tamu']    as bool? ?? false,
    enrolled    : j['enrolled']     as int?  ?? j['jumlah_mahasiswa'] as int? ?? 0,
  );

  String get labelJam {
    if (jamMulai == null && jamSelesai == null) return '-';
    return '${jamMulai ?? "?"} – ${jamSelesai ?? "?"}';
  }

  String get labelSlot {
    if (slotMulai == null) return '';
    final selesai = slotSelesai ?? slotMulai;
    return 'Slot $slotMulai–$selesai';
  }
}

// ── [BARU 7.1] Model Mahasiswa dalam Kelas ───────────────────

class MahasiswaKelasItem {
  final String  mahasiswaId;
  final String  nim;
  final String  namaLengkap;
  final String  programStudi;
  final bool    isTamu;
  final String? kelasAsal;

  const MahasiswaKelasItem({
    required this.mahasiswaId,
    required this.nim,
    required this.namaLengkap,
    required this.programStudi,
    required this.isTamu,
    this.kelasAsal,
  });

  factory MahasiswaKelasItem.fromJson(Map<String, dynamic> j) =>
      MahasiswaKelasItem(
        mahasiswaId : j['mahasiswa_id']  as String,
        nim         : j['nim']           as String,
        namaLengkap : j['nama_lengkap']  as String,
        programStudi: j['program_studi'] as String? ?? '',
        isTamu      : j['is_tamu']       as bool?   ?? false,
        kelasAsal   : j['kelas_asal']    as String?,
      );

  String get inisial {
    final parts = namaLengkap.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (namaLengkap.isNotEmpty) return namaLengkap[0].toUpperCase();
    return '?';
  }
}

class JadwalPenggantiItem {
  final String  id;
  final int     pertemuanKe;
  final String? jamMulaiBaru;
  final String? jamSelesaiBaru;
  final String? ruanganBaru;
  final String? keterangan;

  // [BARU 7.2] Field mode
  final String? mode; // 'offline' | 'online' | null

  const JadwalPenggantiItem({
    required this.id,
    required this.pertemuanKe,
    this.jamMulaiBaru,
    this.jamSelesaiBaru,
    this.ruanganBaru,
    this.keterangan,
    this.mode,
  });

  factory JadwalPenggantiItem.fromJson(Map<String, dynamic> j) =>
      JadwalPenggantiItem(
        id            : j['id']               as String,
        pertemuanKe   : j['pertemuan_ke']     as int,
        jamMulaiBaru  : j['jam_mulai_baru']   as String?,
        jamSelesaiBaru: j['jam_selesai_baru'] as String?,
        ruanganBaru   : j['ruangan_baru']     as String?,
        keterangan    : j['keterangan']       as String?,
        mode          : j['mode']             as String?,
      );
}

class RiwayatSesiItem {
  final String  sesiId;
  final int     pertemuanKe;
  final String  mode;
  final String? waktuBuka;
  final String? waktuTutup;
  final String  status;
  final int     totalMhs;
  final int     hadir;
  final int     terlambat;
  final int     absen;
  final double  persentase;

  const RiwayatSesiItem({
    required this.sesiId,
    required this.pertemuanKe,
    required this.mode,
    this.waktuBuka,
    this.waktuTutup,
    required this.status,
    required this.totalMhs,
    required this.hadir,
    required this.terlambat,
    required this.absen,
    required this.persentase,
  });

  factory RiwayatSesiItem.fromJson(Map<String, dynamic> j) =>
      RiwayatSesiItem(
        sesiId      : j['sesi_id']      as String,
        pertemuanKe : j['pertemuan_ke'] as int,
        mode        : j['mode']         as String? ?? '-',
        waktuBuka   : j['waktu_buka']   as String?,
        waktuTutup  : j['waktu_tutup']  as String?,
        status      : j['status']       as String? ?? '-',
        totalMhs    : j['total_mhs']    as int?    ?? 0,
        hadir       : j['hadir']        as int?    ?? 0,
        terlambat   : j['terlambat']    as int?    ?? 0,
        absen       : j['absen']        as int?    ?? 0,
        persentase  : (j['persentase']  as num?)?.toDouble() ?? 0.0,
      );
}

// ══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════

class DetailMatakuliahScreen extends StatefulWidget {
  final String matakuliahId;

  const DetailMatakuliahScreen({super.key, required this.matakuliahId});

  @override
  State<DetailMatakuliahScreen> createState() =>
      _DetailMatakuliahScreenState();
}

class _DetailMatakuliahScreenState extends State<DetailMatakuliahScreen>
    with SingleTickerProviderStateMixin {

  // [7.1] TabController kini 4 tab: Mahasiswa | Jadwal | Riwayat | Kelas
  late TabController _tabController;

  MatakuliahDetail? _data;
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response =
          await ApiClient().get('/dosen/matakuliah/${widget.matakuliahId}');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _data      = MatakuliahDetail.fromJson(json);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      body: _isLoading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _fetchDetail)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return NestedScrollView(
      headerSliverBuilder: (ctx, _) => [
        SliverAppBar(
          pinned         : true,
          expandedHeight : 180,
          backgroundColor: _kNavy,
          foregroundColor: Colors.white,
          elevation      : 0,
          leading: IconButton(
            icon     : const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/dosen/home');
              }
            },
          ),
          actions: [
            IconButton(
              icon     : const Icon(Icons.refresh_rounded),
              onPressed: _fetchDetail,
              tooltip  : 'Refresh',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin : Alignment.topLeft,
                  end   : Alignment.bottomRight,
                  colors: [_kNavy, Color(0xFF1A4A80)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color       : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(d.kode,
                              style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 12,
                                fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('${d.sks} SKS',
                            style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                          const Spacer(),
                          _IzinTamuBadge(izinTamu: d.izinTamu),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(d.nama,
                        style: const TextStyle(
                          color     : Colors.white,
                          fontSize  : 20,
                          fontWeight: FontWeight.bold),
                        maxLines : 2,
                        overflow : TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (d.hari != null) ...[
                            const Icon(Icons.calendar_today_rounded,
                              size: 13, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text('${d.hari}  ·  '
                              '${d.jamMulai ?? '-'} – ${d.jamSelesai ?? '-'}',
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                          if (d.ruangan != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.room_outlined,
                              size: 13, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text(d.ruangan!,
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // [7.1] 4 tab: tambah 'Kelas'
          bottom: TabBar(
            controller          : _tabController,
            indicatorColor      : _kGold,       // Gold UMS untuk indicator
            indicatorWeight     : 3,
            labelColor          : Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle          : const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Mahasiswa (${d.totalAsli + d.totalTamu})'),
              const Tab(text: 'Jadwal'),
              Tab(text: 'Riwayat (${d.riwayatSesi.length})'),
              // [BARU 7.1]
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kelas'),
                    if (d.kelasList.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color       : _kGold.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text('${d.kelasList.length}',
                          style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children  : [
          _MahasiswaTab(
            matakuliahId : widget.matakuliahId,
            mahasiswaList: d.mahasiswa,
            izinTamu     : d.izinTamu,
            onRefresh    : _fetchDetail,
          ),
          // [7.2] JadwalTab kini terima jadwalPengganti untuk indikator
          _JadwalTab(
            matakuliahId   : widget.matakuliahId,
            data           : d,
            onRefresh      : _fetchDetail,
          ),
          _RiwayatTab(riwayatSesi: d.riwayatSesi),
          // [BARU 7.1] Tab Kelas
          _KelasTab(
            matakuliahId: widget.matakuliahId,
            kelasList   : d.kelasList,
            onRefresh   : _fetchDetail,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 1 — MAHASISWA (tidak berubah signifikan)
// ══════════════════════════════════════════════════════════════

class _MahasiswaTab extends StatefulWidget {
  final String             matakuliahId;
  final List<MahasiswaItem> mahasiswaList;
  final bool               izinTamu;
  final VoidCallback       onRefresh;

  const _MahasiswaTab({
    required this.matakuliahId,
    required this.mahasiswaList,
    required this.izinTamu,
    required this.onRefresh,
  });

  @override
  State<_MahasiswaTab> createState() => _MahasiswaTabState();
}

class _MahasiswaTabState extends State<_MahasiswaTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  String _filterChip = 'semua';
  bool   _izinTamu   = false;
  bool   _isTogglingTamu = false;

  @override
  void initState() {
    super.initState();
    _izinTamu = widget.izinTamu;
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MahasiswaItem> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return widget.mahasiswaList.where((m) {
      final matchSearch = q.isEmpty ||
          m.namaLengkap.toLowerCase().contains(q) ||
          m.nim.toLowerCase().contains(q);
      final matchFilter = _filterChip == 'semua' ||
          (_filterChip == 'asli' && !m.isTamu) ||
          (_filterChip == 'tamu' && m.isTamu);
      return matchSearch && matchFilter;
    }).toList();
  }

  Future<void> _toggleIzinTamu(bool value) async {
    setState(() => _isTogglingTamu = true);
    try {
      final response = await ApiClient().patch(
        '/dosen/matakuliah/${widget.matakuliahId}/izin-tamu',
        body: {'izin_tamu': value},
      );
      if (response.statusCode == 200) {
        setState(() => _izinTamu = value);
        _showSnack(value
          ? 'Izin tamu diaktifkan'
          : 'Izin tamu dinonaktifkan');
        widget.onRefresh();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal ubah izin tamu', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isTogglingTamu = false);
    }
  }

  Future<void> _hapusTamu(MahasiswaItem mhs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Akses Tamu?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          '${mhs.namaLengkap} tidak akan bisa presensi di kelas ini lagi.\n'
          'Riwayat presensi tetap tersimpan.',
          style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white),
            child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await ApiClient().delete(
        '/dosen/matakuliah/${widget.matakuliahId}/tamu/${mhs.mahasiswaId}',
      );
      if (response.statusCode == 200) {
        _showSnack('${mhs.namaLengkap} berhasil dihapus dari daftar tamu');
        widget.onRefresh();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal hapus tamu', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showTambahTamuDialog() {
    final nimCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Tamu Manual',
            style: TextStyle(
              color: _kNavy, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan NIM mahasiswa yang akan diizinkan sebagai tamu.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller  : nimCtrl,
                keyboardType: TextInputType.number,
                autofocus   : true,
                decoration  : InputDecoration(
                  labelText: 'NIM Mahasiswa',
                  hintText : 'Contoh: 2021001003',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kNavy, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final nim = nimCtrl.text.trim();
                if (nim.isEmpty) return;
                setModal(() => isLoading = true);
                try {
                  final response = await ApiClient().post(
                    '/dosen/matakuliah/${widget.matakuliahId}/tamu',
                    body: {'nim': nim},
                  );
                  if (!ctx.mounted) return;
                  if (response.statusCode == 201) {
                    Navigator.pop(ctx);
                    _showSnack('Mahasiswa berhasil ditambahkan sebagai tamu');
                    widget.onRefresh();
                  } else {
                    final err = jsonDecode(response.body);
                    _showSnack(err['detail'] ?? 'Gagal tambah tamu',
                      isError: true);
                    setModal(() => isLoading = false);
                  }
                } on ApiException catch (e) {
                  _showSnack(e.message, isError: true);
                  setModal(() => isLoading = false);
                } catch (e) {
                  _showSnack('Error: $e', isError: true);
                  setModal(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content        : Text(msg),
      backgroundColor: isError ? _kDanger : Colors.green.shade700,
      behavior       : SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered  = _filtered;
    final totalAsli = widget.mahasiswaList.where((m) => !m.isTamu).length;
    final totalTamu = widget.mahasiswaList.where((m) => m.isTamu).length;

    return Column(
      children: [
        Container(
          color  : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child  : Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Izinkan Mahasiswa Tamu',
                          style: TextStyle(
                            color     : _kNavy,
                            fontWeight: FontWeight.bold,
                            fontSize  : 14)),
                        Text(
                          _izinTamu
                            ? 'Mahasiswa kelas lain bisa langsung presensi'
                            : 'Hanya mahasiswa terdaftar yang bisa presensi',
                          style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  _isTogglingTamu
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kNavy))
                      : Switch.adaptive(
                          value    : _izinTamu,
                          onChanged: _toggleIzinTamu,
                          activeColor: _kAccent,
                        ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width : double.infinity,
                child : OutlinedButton.icon(
                  onPressed: _showTambahTamuDialog,
                  icon : const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Tambah Tamu Manual via NIM'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    side: const BorderSide(color: _kNavy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Container(
          color  : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child  : Column(
            children: [
              TextField(
                controller : _searchCtrl,
                decoration : InputDecoration(
                  hintText    : 'Cari nama atau NIM...',
                  prefixIcon  : const Icon(Icons.search_rounded, size: 20),
                  suffixIcon  : _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon    : const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchCtrl.clear())
                      : null,
                  filled      : true,
                  fillColor   : _kBgLight,
                  border      : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide  : BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _FilterChip(
                    label   : 'Semua (${widget.mahasiswaList.length})',
                    selected: _filterChip == 'semua',
                    onTap   : () => setState(() => _filterChip = 'semua'),
                    color   : _kNavy,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label   : 'Asli ($totalAsli)',
                    selected: _filterChip == 'asli',
                    onTap   : () => setState(() => _filterChip = 'asli'),
                    color   : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label   : 'Tamu ($totalTamu)',
                    selected: _filterChip == 'tamu',
                    onTap   : () => setState(() => _filterChip = 'tamu'),
                    color   : Colors.orange.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(
                  icon : Icons.people_outline_rounded,
                  pesan: _searchCtrl.text.isNotEmpty
                      ? 'Tidak ada hasil untuk "${_searchCtrl.text}"'
                      : 'Belum ada mahasiswa terdaftar',
                )
              : ListView.separated(
                  padding        : const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount      : filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder    : (ctx, i) => _MahasiswaCard(
                    mhs         : filtered[i],
                    onHapusTamu : filtered[i].isTamu
                        ? () => _hapusTamu(filtered[i])
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}

class _MahasiswaCard extends StatelessWidget {
  final MahasiswaItem mhs;
  final VoidCallback? onHapusTamu;

  const _MahasiswaCard({required this.mhs, this.onHapusTamu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset    : const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius         : 22,
            backgroundColor: mhs.isTamu
                ? Colors.orange.shade100
                : _kNavy.withOpacity(0.1),
            child: Text(mhs.inisial,
              style: TextStyle(
                color     : mhs.isTamu
                    ? Colors.orange.shade700 : _kNavy,
                fontWeight: FontWeight.bold,
                fontSize  : 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(mhs.namaLengkap,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _kNavy),
                        overflow: TextOverflow.ellipsis),
                    ),
                    if (mhs.isTamu) ...[
                      const SizedBox(width: 6),
                      const TamuBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(mhs.nim,
                  style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
                if (mhs.isTamu && mhs.kelasAsal != null)
                  Text('dari ${mhs.kelasAsal}',
                    style: TextStyle(
                      color: Colors.orange.shade600, fontSize: 11)),
                Text(mhs.programStudi,
                  style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          if (onHapusTamu != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'hapus') onHapusTamu!();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'hapus',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_rounded,
                        color: _kDanger, size: 18),
                      SizedBox(width: 8),
                      Text('Hapus Akses Tamu',
                        style: TextStyle(color: _kDanger)),
                    ],
                  ),
                ),
              ],
              child: Icon(Icons.more_vert_rounded,
                color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 2 — JADWAL (7.2: tambah field mode + validasi jam)
// ══════════════════════════════════════════════════════════════

class _JadwalTab extends StatefulWidget {
  final String           matakuliahId;
  final MatakuliahDetail data;
  final VoidCallback     onRefresh;

  const _JadwalTab({
    required this.matakuliahId,
    required this.data,
    required this.onRefresh,
  });

  @override
  State<_JadwalTab> createState() => _JadwalTabState();
}

class _JadwalTabState extends State<_JadwalTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int?    _selectedPertemuan;
  String? _jamMulaiBaru;
  String? _jamSelesaiBaru;

  // [BARU 7.2] Field mode jadwal pengganti
  String? _modeBaru; // 'offline' | 'online' | null (tidak diubah)

  final _ruanganCtrl    = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  bool    _isSaving     = false;

  // [BARU 7.2] Set pertemuan yang sudah punya jadwal pengganti
  Set<int> get _pertemuanDenganPengganti {
    return widget.data.jadwalPengganti
        .map((jp) => jp.pertemuanKe)
        .toSet();
  }

  @override
  void dispose() {
    _ruanganCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  // [7.2] Parse jam "HH:MM" → TimeOfDay untuk perbandingan
  TimeOfDay? _parseJam(String? jam) {
    if (jam == null) return null;
    final parts = jam.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  // [7.2] Konversi TimeOfDay → menit untuk perbandingan
  int _toMenit(TimeOfDay t) => t.hour * 60 + t.minute;

  // [7.2] Validasi jam selesai > jam mulai
  bool _jamValid() {
    if (_jamMulaiBaru == null || _jamSelesaiBaru == null) return true;
    final mulai   = _parseJam(_jamMulaiBaru);
    final selesai = _parseJam(_jamSelesaiBaru);
    if (mulai == null || selesai == null) return true;
    return _toMenit(selesai) > _toMenit(mulai);
  }

  Future<void> _pickTime(bool isMulai) async {
    final now    = TimeOfDay.now();
    final picked = await showTimePicker(
      context     : context,
      initialTime : now,
      helpText    : isMulai ? 'Pilih Jam Mulai Baru' : 'Pilih Jam Selesai Baru',
      builder     : (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy)),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isMulai) _jamMulaiBaru   = formatted;
        else         _jamSelesaiBaru = formatted;
      });
    }
  }

  Future<void> _simpan() async {
    if (_selectedPertemuan == null) {
      _showSnack('Pilih nomor pertemuan terlebih dahulu', isError: true);
      return;
    }

    // [7.2] Validasi semua field minimal satu diisi
    if (_jamMulaiBaru == null && _jamSelesaiBaru == null &&
        _ruanganCtrl.text.isEmpty && _keteranganCtrl.text.isEmpty &&
        _modeBaru == null) {
      _showSnack('Minimal satu perubahan harus diisi', isError: true);
      return;
    }

    // [7.2] Validasi jam selesai > jam mulai
    if (!_jamValid()) {
      _showSnack('Jam selesai harus lebih besar dari jam mulai', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'pertemuan_ke': _selectedPertemuan,
        if (_jamMulaiBaru   != null) 'jam_mulai_baru'   : _jamMulaiBaru,
        if (_jamSelesaiBaru != null) 'jam_selesai_baru' : _jamSelesaiBaru,
        if (_ruanganCtrl.text.isNotEmpty)
          'ruangan_baru': _ruanganCtrl.text.trim(),
        if (_keteranganCtrl.text.isNotEmpty)
          'keterangan'  : _keteranganCtrl.text.trim(),
        // [BARU 7.2] Sertakan mode jika dipilih
        if (_modeBaru != null) 'mode': _modeBaru,
      };

      final response = await ApiClient().post(
        '/dosen/matakuliah/${widget.matakuliahId}/jadwal-pengganti',
        body: body,
      );

      if (response.statusCode == 201) {
        _showSnack('Jadwal pengganti pertemuan $_selectedPertemuan berhasil disimpan');
        setState(() {
          _selectedPertemuan = null;
          _jamMulaiBaru      = null;
          _jamSelesaiBaru    = null;
          _modeBaru          = null; // [7.2] reset mode
        });
        _ruanganCtrl.clear();
        _keteranganCtrl.clear();
        widget.onRefresh();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal simpan', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _hapus(JadwalPenggantiItem jp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Jadwal Pengganti?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Jadwal pengganti pertemuan ${jp.pertemuanKe} akan dihapus.\n'
          'Sistem akan kembali menggunakan jadwal reguler.',
          style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white),
            child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await ApiClient().delete(
        '/dosen/matakuliah/${widget.matakuliahId}/jadwal-pengganti/${jp.pertemuanKe}',
      );
      if (response.statusCode == 200) {
        _showSnack('Jadwal pengganti pertemuan ${jp.pertemuanKe} dihapus');
        widget.onRefresh();
      } else {
        final err = jsonDecode(response.body);
        _showSnack(err['detail'] ?? 'Gagal hapus', isError: true);
      }
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = widget.data;
    final sudahAdaPengganti = _pertemuanDenganPengganti;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Jadwal reguler ──────────────────────────────────
          _SectionCard(
            title: '📅 Jadwal Reguler',
            child: Column(
              children: [
                _InfoRow(label: 'Hari',
                  value: d.hari ?? 'Belum diset'),
                const Divider(height: 16),
                _InfoRow(label: 'Jam',
                  value: (d.jamMulai != null && d.jamSelesai != null)
                      ? '${d.jamMulai} – ${d.jamSelesai}'
                      : 'Belum diset'),
                const Divider(height: 16),
                _InfoRow(label: 'Ruangan',
                  value: d.ruangan ?? 'Belum diset'),
                const Divider(height: 16),
                _InfoRow(label: 'Koordinat GPS',
                  value: (d.koordinatLat != null && d.koordinatLng != null)
                      ? '${d.koordinatLat!.toStringAsFixed(6)}, '
                        '${d.koordinatLng!.toStringAsFixed(6)}'
                      : 'Belum diset (hubungi admin)'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Form jadwal pengganti ────────────────────────────
          _SectionCard(
            title: '🔄 Tambah Jadwal Pengganti',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buat jadwal pengganti untuk pertemuan tertentu. '
                  'Tidak mengubah jadwal reguler.',
                  style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),

                // [7.2] Dropdown pertemuan — tampilkan indikator
                // untuk pertemuan yang sudah punya jadwal pengganti
                DropdownButtonFormField<int>(
                  value     : _selectedPertemuan,
                  decoration: InputDecoration(
                    labelText: 'Pertemuan ke-',
                    filled   : true,
                    fillColor: _kBgLight,
                    border   : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide(
                        color: Colors.grey.shade300)),
                  ),
                  items: List.generate(16, (i) => i + 1).map((n) {
                    final sudahAda = sudahAdaPengganti.contains(n);
                    return DropdownMenuItem(
                      value: n,
                      child: Row(
                        children: [
                          Text('Pertemuan ke-$n'),
                          // [7.2] Indikator pertemuan yang sudah ada pengganti
                          if (sudahAda) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _kGold.withOpacity(0.5), width: 1)),
                              child: const Text('Ada Pengganti',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB8860B),
                                  fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedPertemuan = v),
                ),
                const SizedBox(height: 12),

                // Jam mulai & selesai baru
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerField(
                        label     : 'Jam Mulai Baru',
                        value     : _jamMulaiBaru,
                        onPickTime: () => _pickTime(true),
                        onClear   : () => setState(() => _jamMulaiBaru = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimePickerField(
                        label     : 'Jam Selesai Baru',
                        value     : _jamSelesaiBaru,
                        onPickTime: () => _pickTime(false),
                        onClear   : () => setState(() => _jamSelesaiBaru = null),
                        // [7.2] Highlight merah jika jam tidak valid
                        isError   : _jamMulaiBaru != null &&
                                    _jamSelesaiBaru != null &&
                                    !_jamValid(),
                      ),
                    ),
                  ],
                ),

                // [7.2] Pesan error jam
                if (_jamMulaiBaru != null &&
                    _jamSelesaiBaru != null &&
                    !_jamValid())
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                          size: 14, color: _kDanger),
                        const SizedBox(width: 4),
                        Text(
                          'Jam selesai harus lebih besar dari jam mulai',
                          style: TextStyle(
                            color: _kDanger, fontSize: 11)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Ruangan baru
                TextField(
                  controller : _ruanganCtrl,
                  decoration : InputDecoration(
                    labelText: 'Ruangan Baru (opsional)',
                    hintText : 'Contoh: C-202',
                    prefixIcon: const Icon(Icons.room_outlined),
                    filled   : true,
                    fillColor: _kBgLight,
                    border   : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide(
                        color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 12),

                // [BARU 7.2] ── Dropdown Mode ──────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Pelaksanaan Baru',
                      style: TextStyle(
                        color    : Colors.grey.shade600,
                        fontSize : 13,
                        fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color       : _kBgLight,
                        borderRadius: BorderRadius.circular(10),
                        border      : Border.all(
                          color: Colors.grey.shade300, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Pilihan: Tidak diubah
                          _ModeRadioTile(
                            value   : null,
                            groupVal: _modeBaru,
                            label   : 'Tidak diubah (ikut reguler)',
                            icon    : Icons.sync_rounded,
                            color   : Colors.grey.shade600,
                            onChanged: (v) => setState(() => _modeBaru = v),
                          ),
                          const Divider(height: 1),
                          // Pilihan: Tatap Muka (Offline)
                          _ModeRadioTile(
                            value   : 'offline',
                            groupVal: _modeBaru,
                            label   : 'Tatap Muka (Offline)',
                            icon    : Icons.location_on_outlined,
                            color   : _kAccent,
                            onChanged: (v) => setState(() => _modeBaru = v),
                          ),
                          const Divider(height: 1),
                          // Pilihan: Online
                          _ModeRadioTile(
                            value   : 'online',
                            groupVal: _modeBaru,
                            label   : 'Online',
                            icon    : Icons.laptop_outlined,
                            color   : _kNavy,
                            onChanged: (v) => setState(() => _modeBaru = v),
                          ),
                        ],
                      ),
                    ),
                    // Info dampak ke presensi
                    if (_modeBaru != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_modeBaru == 'online'
                                    ? _kNavy : _kAccent).withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_modeBaru == 'online'
                                  ? _kNavy : _kAccent).withOpacity(0.2))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                size: 14,
                                color: _modeBaru == 'online'
                                    ? _kNavy : _kAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _modeBaru == 'online'
                                      ? 'Mahasiswa akan diminta memasukkan '
                                        'kode sesi saat presensi pertemuan ini.'
                                      : 'Mahasiswa akan divalidasi GPS saat '
                                        'presensi pertemuan ini.',
                                  style: TextStyle(
                                    color: _modeBaru == 'online'
                                        ? _kNavy : _kAccent,
                                    fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Keterangan
                TextField(
                  controller : _keteranganCtrl,
                  maxLines   : 2,
                  decoration : InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    hintText : 'Contoh: Pindah karena ruang dipakai seminar',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled   : true,
                    fillColor: _kBgLight,
                    border   : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide  : BorderSide(
                        color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child : ElevatedButton.icon(
                    onPressed: _isSaving ? null : _simpan,
                    icon : _isSaving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Jadwal Pengganti',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── List jadwal pengganti tersimpan ──────────────────
          if (d.jadwalPengganti.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: '📋 Jadwal Pengganti Tersimpan (${d.jadwalPengganti.length})',
              child: Column(
                children: d.jadwalPengganti
                    .map((jp) => _JadwalPenggantiCard(
                          jp    : jp,
                          onHapus: () => _hapus(jp),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── [BARU 7.2] Radio tile untuk pilihan mode ──────────────────

class _ModeRadioTile extends StatelessWidget {
  final String?  value;
  final String?  groupVal;
  final String   label;
  final IconData icon;
  final Color    color;
  final void Function(String?) onChanged;

  const _ModeRadioTile({
    required this.value,
    required this.groupVal,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  bool get _selected => value == groupVal;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap       : () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _selected ? color : Colors.grey.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color     : _selected ? color : Colors.grey.shade700,
                  fontSize  : 13,
                  fontWeight: _selected ? FontWeight.w600 : FontWeight.normal),
              ),
            ),
            Radio<String?>(
              value         : value,
              groupValue    : groupVal,
              onChanged     : (v) => onChanged(v),
              activeColor   : color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time picker field (update: tambah isError) ────────────────

class _TimePickerField extends StatelessWidget {
  final String       label;
  final String?      value;
  final VoidCallback onPickTime;
  final VoidCallback onClear;
  final bool         isError;

  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onPickTime,
    required this.onClear,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isError ? _kDanger : Colors.grey.shade300;
    return GestureDetector(
      onTap: onPickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color : _kBgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isError ? 1.5 : 1)),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
              size: 18,
              color: isError ? _kDanger : Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      color   : isError ? _kDanger : Colors.grey.shade500,
                      fontSize: 11)),
                  Text(
                    value ?? 'Pilih jam',
                    style: TextStyle(
                      color     : value != null
                          ? (isError ? _kDanger : _kNavy)
                          : Colors.grey.shade400,
                      fontSize  : 14,
                      fontWeight: value != null
                          ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.clear_rounded,
                  size: 16, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}

// ── Card jadwal pengganti (update: tampilkan mode) ────────────

class _JadwalPenggantiCard extends StatelessWidget {
  final JadwalPenggantiItem jp;
  final VoidCallback        onHapus;

  const _JadwalPenggantiCard({required this.jp, required this.onHapus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin    : const EdgeInsets.only(bottom: 8),
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGold.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width : 36, height: 36,
            decoration: BoxDecoration(
              color: _kGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('${jp.pertemuanKe}',
                style: TextStyle(
                  color     : _kGold.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize  : 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header pertemuan + badge mode
                Row(
                  children: [
                    Text('Pertemuan ke-${jp.pertemuanKe}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                    if (jp.mode != null) ...[
                      const SizedBox(width: 8),
                      // [7.2] Tampilkan mode badge
                      ModeBadge(mode: jp.mode!, fontSize: 9),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (jp.jamMulaiBaru != null || jp.jamSelesaiBaru != null)
                  Text(
                    '🕐 ${jp.jamMulaiBaru ?? '-'} – ${jp.jamSelesaiBaru ?? '-'}',
                    style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
                if (jp.ruanganBaru != null)
                  Text('📍 ${jp.ruanganBaru}',
                    style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
                if (jp.keterangan != null && jp.keterangan!.isNotEmpty)
                  Text('📝 ${jp.keterangan}',
                    style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon     : const Icon(Icons.delete_outline_rounded,
              color: _kDanger, size: 20),
            onPressed: onHapus,
            tooltip  : 'Hapus jadwal pengganti',
            padding  : EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 3 — RIWAYAT (tidak berubah signifikan)
// ══════════════════════════════════════════════════════════════

class _RiwayatTab extends StatelessWidget {
  final List<RiwayatSesiItem> riwayatSesi;

  const _RiwayatTab({required this.riwayatSesi});

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (riwayatSesi.isEmpty) {
      return const _EmptyState(
        icon : Icons.history_edu_rounded,
        pesan: 'Belum ada sesi yang pernah dibuat',
        sub  : 'Buka sesi dari beranda untuk mulai mengajar',
      );
    }

    return ListView.separated(
      padding        : const EdgeInsets.all(16),
      itemCount      : riwayatSesi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder    : (ctx, i) {
        final s = riwayatSesi[i];

        Color barColor;
        if (s.persentase >= 75)      barColor = Colors.green.shade600;
        else if (s.persentase >= 50) barColor = _kWarning;
        else                         barColor = _kDanger;

        return GestureDetector(
          onTap: () => context.go('/dosen/rekap/${s.sesiId}'),
          child: Container(
            padding   : const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color       : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color     : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset    : const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('Pertemuan ${s.pertemuanKe}',
                        style: const TextStyle(
                          color     : _kNavy,
                          fontWeight: FontWeight.bold,
                          fontSize  : 12)),
                    ),
                    const SizedBox(width: 8),
                    ModeBadge(mode: s.mode),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.status == 'aktif'
                            ? _kAccent.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        s.status == 'aktif' ? '🟢 AKTIF' : 'SELESAI',
                        style: TextStyle(
                          color: s.status == 'aktif'
                              ? _kAccent : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_formatWaktu(s.waktuBuka),
                  style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value          : s.totalMhs > 0
                        ? (s.hadir + s.terlambat) / s.totalMhs : 0,
                    backgroundColor: Colors.grey.shade100,
                    valueColor     : AlwaysStoppedAnimation<Color>(barColor),
                    minHeight      : 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatLabel(value: s.hadir,    label: 'Hadir',
                      color: Colors.green.shade600),
                    const SizedBox(width: 10),
                    _StatLabel(value: s.terlambat, label: 'Terlambat',
                      color: _kWarning),
                    const SizedBox(width: 10),
                    _StatLabel(value: s.absen,    label: 'Absen',
                      color: _kDanger),
                    const Spacer(),
                    Text(
                      '${s.persentase.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color     : barColor,
                        fontSize  : 16,
                        fontWeight: FontWeight.bold)),
                    Text(' /${s.totalMhs}',
                      style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade300, size: 18),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB 4 — KELAS (BARU 7.1)
// ══════════════════════════════════════════════════════════════

class _KelasTab extends StatefulWidget {
  final String        matakuliahId;
  final List<KelasItem> kelasList;
  final VoidCallback  onRefresh;

  const _KelasTab({
    required this.matakuliahId,
    required this.kelasList,
    required this.onRefresh,
  });

  @override
  State<_KelasTab> createState() => _KelasTabState();
}

class _KelasTabState extends State<_KelasTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // State: kelas yang sedang di-expand untuk melihat list mahasiswa
  String? _expandedKelasId;
  final Map<String, List<MahasiswaKelasItem>> _mahasiswaCache = {};
  final Map<String, bool>  _loadingKelas  = {};
  final Map<String, String?> _errorKelas  = {};

  Future<void> _fetchMahasiswaKelas(String kelasId) async {
    if (_mahasiswaCache.containsKey(kelasId)) return;
    setState(() {
      _loadingKelas[kelasId] = true;
      _errorKelas[kelasId]   = null;
    });
    try {
      final response = await ApiClient().get('/kelas/mahasiswa/$kelasId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = ((data['mahasiswa'] as List<dynamic>?) ?? [])
            .map((e) => MahasiswaKelasItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _mahasiswaCache[kelasId] = list;
          _loadingKelas[kelasId]   = false;
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _errorKelas[kelasId]   = err['detail'] ?? 'Gagal memuat';
          _loadingKelas[kelasId] = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorKelas[kelasId]   = e.message;
        _loadingKelas[kelasId] = false;
      });
    } catch (e) {
      setState(() {
        _errorKelas[kelasId]   = e.toString();
        _loadingKelas[kelasId] = false;
      });
    }
  }

  void _toggleKelas(String kelasId) {
    setState(() {
      if (_expandedKelasId == kelasId) {
        _expandedKelasId = null;
      } else {
        _expandedKelasId = kelasId;
        _fetchMahasiswaKelas(kelasId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.kelasList.isEmpty) {
      return const _EmptyState(
        icon : Icons.class_outlined,
        pesan: 'Belum ada kelas terdaftar',
        sub  : 'Hubungi admin untuk menambahkan kelas pada matakuliah ini',
      );
    }

    return ListView.separated(
      padding        : const EdgeInsets.all(16),
      itemCount      : widget.kelasList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder    : (ctx, i) {
        final kelas = widget.kelasList[i];
        return _KelasCard(
          kelas           : kelas,
          isExpanded      : _expandedKelasId == kelas.id,
          isLoading       : _loadingKelas[kelas.id] ?? false,
          errorMsg        : _errorKelas[kelas.id],
          mahasiswaList   : _mahasiswaCache[kelas.id] ?? [],
          onTap           : () => _toggleKelas(kelas.id),
          onRetry         : () {
            _mahasiswaCache.remove(kelas.id);
            _fetchMahasiswaKelas(kelas.id);
          },
        );
      },
    );
  }
}

class _KelasCard extends StatelessWidget {
  final KelasItem              kelas;
  final bool                   isExpanded;
  final bool                   isLoading;
  final String?                errorMsg;
  final List<MahasiswaKelasItem> mahasiswaList;
  final VoidCallback           onTap;
  final VoidCallback           onRetry;

  const _KelasCard({
    required this.kelas,
    required this.isExpanded,
    required this.isLoading,
    required this.errorMsg,
    required this.mahasiswaList,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final kelasColor = _kelasColor(kelas.kodeKelas);

    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset    : const Offset(0, 2)),
        ],
        border: isExpanded
            ? Border.all(color: kelasColor.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // ── Header kelas ─────────────────────────────────────
          InkWell(
            onTap       : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar kelas
                  Container(
                    width : 44, height: 44,
                    decoration: BoxDecoration(
                      color       : kelasColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                    child: Center(
                      child: Text(kelas.kodeKelas,
                        style: TextStyle(
                          color     : kelasColor,
                          fontWeight: FontWeight.bold,
                          fontSize  : 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            KelasBadge(kodeKelas: kelas.kodeKelas),
                            const SizedBox(width: 8),
                            // Badge izin tamu
                            if (kelas.izinTamu)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                                child: const Text('Tamu OK',
                                  style: TextStyle(
                                    color: _kAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Dosen
                        if (kelas.dosenNama != null)
                          Text(kelas.dosenNama!,
                            style: const TextStyle(
                              color     : _kNavy,
                              fontWeight: FontWeight.w600,
                              fontSize  : 13),
                            overflow: TextOverflow.ellipsis),
                        // Jadwal + ruangan
                        Row(
                          children: [
                            if (kelas.hari != null) ...[
                              Icon(Icons.calendar_today_rounded,
                                size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Text(kelas.hari!,
                                style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11)),
                              const SizedBox(width: 6),
                            ],
                            if (kelas.slotMulai != null) ...[
                              Icon(Icons.access_time_rounded,
                                size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Text(kelas.labelJam,
                                style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11)),
                            ] else if (kelas.jamMulai != null) ...[
                              Icon(Icons.access_time_rounded,
                                size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Text(kelas.labelJam,
                                style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11)),
                            ],
                            if (kelas.ruanganNama != null) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.room_outlined,
                                size: 11, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(kelas.ruanganNama!,
                                  style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Jumlah mahasiswa + expand icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${kelas.enrolled}',
                        style: TextStyle(
                          color     : kelasColor,
                          fontSize  : 18,
                          fontWeight: FontWeight.bold)),
                      Text('mahasiswa',
                        style: TextStyle(
                          color   : Colors.grey.shade400,
                          fontSize: 10)),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns   : isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade400, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded: list mahasiswa ──────────────────────────
          AnimatedCrossFade(
            duration       : const Duration(milliseconds: 250),
            crossFadeState : isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild : const SizedBox.shrink(),
            secondChild: isExpanded
                ? _buildMahasiswaList(kelasColor)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMahasiswaList(Color kelasColor) {
    return Column(
      children: [
        Divider(height: 1, color: kelasColor.withOpacity(0.2)),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: _kNavy, strokeWidth: 2),
          )
        else if (errorMsg != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(errorMsg!,
                  style: const TextStyle(color: _kDanger, fontSize: 13)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Coba Lagi')),
              ],
            ),
          )
        else if (mahasiswaList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded,
                  size: 36, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Text('Belum ada mahasiswa di kelas ini',
                  style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          )
        else
          // List mahasiswa dalam kelas
          Column(
            children: [
              // Header count
              Builder(builder: (ctx) {
                final asli = mahasiswaList.where((m) => !m.isTamu).length;
                final tamu = mahasiswaList.where((m) => m.isTamu).length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      Text('${mahasiswaList.length} mahasiswa',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (tamu > 0)
                        Text('$asli asli · $tamu tamu',
                          style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11)),
                    ],
                  ),
                );
              }),
              ...mahasiswaList.asMap().entries.map((entry) {
                final idx = entry.key;
                final mhs = entry.value;
                final isLast = idx == mahasiswaList.length - 1;
                return _MahasiswaKelasRow(
                  mhs    : mhs,
                  isLast : isLast,
                  color  : kelasColor,
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
      ],
    );
  }

  Color _kelasColor(String kode) {
    switch (kode.toUpperCase()) {
      case 'A' : return _kNavy;
      case 'B' : return _kAccent;
      case 'C' : return _kPurple;
      case 'D' : return Colors.orange.shade700;
      default  : return _kNavy;
    }
  }
}

class _MahasiswaKelasRow extends StatelessWidget {
  final MahasiswaKelasItem mhs;
  final bool               isLast;
  final Color              color;

  const _MahasiswaKelasRow({
    required this.mhs,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius         : 18,
                backgroundColor: color.withOpacity(0.10),
                child          : Text(mhs.inisial,
                  style: TextStyle(
                    color     : color,
                    fontWeight: FontWeight.bold,
                    fontSize  : 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(mhs.namaLengkap,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize  : 13,
                              color     : _kNavy),
                            overflow: TextOverflow.ellipsis),
                        ),
                        if (mhs.isTamu) ...[
                          const SizedBox(width: 6),
                          const TamuBadge(),
                        ],
                      ],
                    ),
                    Text(mhs.nim,
                      style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11)),
                    if (mhs.isTamu && mhs.kelasAsal != null)
                      Text('dari ${mhs.kelasAsal}',
                        style: TextStyle(
                          color: Colors.orange.shade600, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color : Colors.grey.shade100,
            indent: 52,
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════

class _IzinTamuBadge extends StatelessWidget {
  final bool izinTamu;
  const _IzinTamuBadge({required this.izinTamu});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: izinTamu
          ? _kAccent.withOpacity(0.2)
          : Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: izinTamu ? _kAccent : Colors.white38)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          izinTamu ? Icons.people_rounded : Icons.people_outline_rounded,
          color: izinTamu ? _kAccent : Colors.white70,
          size : 14),
        const SizedBox(width: 4),
        Text(
          izinTamu ? 'Tamu OK' : 'Tamu OFF',
          style: TextStyle(
            color     : izinTamu ? _kAccent : Colors.white70,
            fontSize  : 11,
            fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : Colors.grey.shade300)),
      child: Text(label,
        style: TextStyle(
          color     : selected ? Colors.white : Colors.grey.shade600,
          fontSize  : 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding   : const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: const TextStyle(
            color     : _kNavy,
            fontSize  : 15,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ),
      Expanded(
        child: Text(value,
          style: const TextStyle(
            color: _kNavy, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    ],
  );
}

class _StatLabel extends StatelessWidget {
  final int    value;
  final String label;
  final Color  color;

  const _StatLabel({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$value',
        style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(width: 3),
      Text(label,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   pesan;
  final String?  sub;

  const _EmptyState({
    required this.icon,
    required this.pesan,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(pesan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kNavy, fontSize: 15, fontWeight: FontWeight.bold)),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(sub!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ],
      ),
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: _kNavy),
  );
}

class _ErrorView extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Gagal memuat detail',
            style: TextStyle(
              color: _kNavy, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon : const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white)),
        ],
      ),
    ),
  );
}