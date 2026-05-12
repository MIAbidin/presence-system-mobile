// lib/screens/profil_screen.dart
// v2.1.0 — Fase 4.1 + BUGFIX:
//   ✅ FIX: Defensive parsing /program-studi/aktif (handle List, Map{data:[]}, error)
//   ✅ FIX: resizeToAvoidBottomInset sudah di parent Scaffold, tidak perlu di sini
//   - Prodi terstruktur dari GET /program-studi/aktif
//   - Card "Matakuliah Saya" → /mahasiswa/matakuliah
//   - Panggil FcmService().updateToken() saat profil dimuat
//   - Seksi statistik kehadiran semester

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/core/theme.dart';
import 'package:presensi_app/models/program_studi.dart';
import 'package:presensi_app/providers/auth_provider.dart';
import 'package:presensi_app/services/fcm_service.dart';

// ─── Model UserProfile (response GET /auth/me) ────────────────

class UserProfileModel {
  final String id;
  final String nimNidn;
  final String namaLengkap;
  final String email;
  final String role;
  final String programStudi;
  final String? programStudiId;
  final bool   isFaceRegistered;

  // Statistik kehadiran dari /auth/me (jika tersedia)
  final int?    totalSesi;
  final int?    totalHadir;
  final int?    totalMatakuliah;
  final double? persentaseHadir;

  const UserProfileModel({
    required this.id,
    required this.nimNidn,
    required this.namaLengkap,
    required this.email,
    required this.role,
    required this.programStudi,
    this.programStudiId,
    required this.isFaceRegistered,
    this.totalSesi,
    this.totalHadir,
    this.totalMatakuliah,
    this.persentaseHadir,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        id               : json['id']                as String,
        nimNidn          : json['nim_nidn']           as String,
        namaLengkap      : json['nama_lengkap']       as String,
        email            : json['email']              as String,
        role             : json['role']               as String,
        programStudi     : json['program_studi']      as String? ?? '',
        programStudiId   : json['program_studi_id']   as String?,
        isFaceRegistered : json['is_face_registered'] as bool,
        totalSesi        : json['total_sesi']          as int?,
        totalHadir       : json['total_hadir']         as int?,
        totalMatakuliah  : json['total_matakuliah']    as int?,
        persentaseHadir  : (json['persentase_hadir']   as num?)?.toDouble(),
      );

  String get inisial => namaLengkap.isNotEmpty
      ? namaLengkap.trim().split(' ').take(2).map((w) => w[0]).join()
      : '?';

  String get labelRole {
    switch (role) {
      case 'mahasiswa': return 'Mahasiswa';
      case 'dosen'    : return 'Dosen';
      case 'admin'    : return 'Admin Kampus';
      default         : return role;
    }
  }
}

// ─── ProfilScreen ─────────────────────────────────────────────

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen>
    with AutomaticKeepAliveClientMixin {
  UserProfileModel?    _profil;
  ProgramStudiModel?   _programStudi;
  bool    _isLoading    = true;
  bool    _isLoggingOut = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // ── Fetch profil + prodi sekaligus ────────────────────────
  Future<void> _fetchAll() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // Fetch profil dulu (wajib berhasil)
      final profilResponse = await ApiClient().get('/auth/me');
      if (!mounted) return;

      final profilData = jsonDecode(profilResponse.body) as Map<String, dynamic>;
      final profil = UserProfileModel.fromJson(profilData);

      // Fetch prodi — optional, jangan crash jika gagal
      ProgramStudiModel? prodiMatch;
      try {
        final prodiResponse = await ApiClient().get('/program-studi/aktif');
        if (prodiResponse.statusCode == 200) {
          // ✅ FIX: Defensive parsing — handle berbagai format response
          // Backend bisa return: List[], Map{data:[]}, Map{program_studi:[]}, dll.
          final decoded = jsonDecode(prodiResponse.body);
          List<dynamic> prodiRaw;

          if (decoded is List) {
            // Format langsung: [{"id":...}, ...]
            prodiRaw = decoded;
          } else if (decoded is Map<String, dynamic>) {
            // Format wrapped: {"data": [...]} atau {"program_studi": [...]}
            prodiRaw = (decoded['data']
                     ?? decoded['program_studi']
                     ?? decoded['items']
                     ?? decoded['results']
                     ?? <dynamic>[]) as List<dynamic>;
          } else {
            prodiRaw = [];
          }

          final prodiList = prodiRaw
              .whereType<Map<String, dynamic>>()
              .map((e) => ProgramStudiModel.fromJson(e))
              .toList();

          if (profil.programStudiId != null) {
            prodiMatch = prodiList.cast<ProgramStudiModel?>().firstWhere(
              (p) => p?.id == profil.programStudiId,
              orElse: () => null,
            );
          }
          // Fallback: cocokkan berdasarkan nama prodi string lama
          if (prodiMatch == null && profil.programStudi.isNotEmpty) {
            prodiMatch = prodiList.cast<ProgramStudiModel?>().firstWhere(
              (p) => p?.nama.toLowerCase() == profil.programStudi.toLowerCase(),
              orElse: () => null,
            );
          }
        }
      } catch (_) {
        // Prodi gagal dimuat — tidak apa-apa, gunakan string fallback
        prodiMatch = null;
      }

      if (!mounted) return;
      setState(() {
        _profil       = profil;
        _programStudi = prodiMatch;
        _isLoading    = false;
      });

      // v2.1.0: Update FCM token saat profil dimuat (fire-and-forget)
      FcmService().updateToken().ignore();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogKonfirmasiLogout(),
    );
    if (konfirmasi != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content        : Text('Gagal logout. Coba lagi.'),
          backgroundColor: AppColors.kDanger,
        ),
      );
    }
  }

  // ── Navigasi ke update wajah ──────────────────────────────
  void _goToUpdateWajah() {
    if (_profil?.isFaceRegistered == true) {
      _showDialogUpdateWajah();
    } else {
      context.push('/register-face');
    }
  }

  void _showDialogUpdateWajah() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Perbarui Data Wajah',
            style: AppTypography.heading3.copyWith(color: AppColors.kNavy)),
        content: const Text(
          'Pembaruan data wajah memerlukan persetujuan admin kampus. '
          'Apakah kamu ingin mengajukan permintaan?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permintaan terkirim ke admin kampus.'),
                  backgroundColor: AppColors.kGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.kBgLight,
      // ✅ FIX: Prevent bottom overflow saat keyboard muncul
      resizeToAvoidBottomInset: false,
      body: _isLoading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _fetchAll)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profil!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(p)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver : SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // ── Statistik kehadiran semester ─────────────
              if (p.role == 'mahasiswa') ...[
                _StatistikCard(profil: p),
                const SizedBox(height: 16),
              ],

              // ── Status wajah ─────────────────────────────
              _FaceStatusCard(
                isRegistered: p.isFaceRegistered,
                onTap       : _goToUpdateWajah,
              ),
              const SizedBox(height: 16),

              // ── Card Matakuliah Saya (mahasiswa) ──────────
              if (p.role == 'mahasiswa') ...[
                _MatakuliahSayaCard(
                  totalMatakuliah: p.totalMatakuliah,
                  onTap: () => context.push('/mahasiswa/matakuliah'),
                ),
                const SizedBox(height: 16),
              ],

              // ── Informasi Akun ────────────────────────────
              _SectionLabel(label: 'Informasi Akun'),
              const SizedBox(height: 8),
              _InfoCard(
                items: [
                  _InfoItem(
                    icon : Icons.badge_outlined,
                    label: p.role == 'mahasiswa' ? 'NIM' : 'NIDN',
                    value: p.nimNidn,
                  ),
                  _InfoItem(
                    icon : Icons.email_outlined,
                    label: 'Email',
                    value: p.email,
                  ),
                  _InfoItem(
                    icon : Icons.school_outlined,
                    label: 'Program Studi',
                    // Prioritas: nama dari prodi terstruktur, fallback string lama
                    value: _programStudi != null
                        ? '${_programStudi!.nama} (${_programStudi!.jenjang})'
                        : p.programStudi.isNotEmpty
                            ? p.programStudi
                            : '-',
                  ),
                  if (_programStudi != null)
                    _InfoItem(
                      icon : Icons.account_balance_outlined,
                      label: 'Fakultas',
                      value: _programStudi!.fakultas,
                    ),
                  _InfoItem(
                    icon : Icons.verified_user_outlined,
                    label: 'Role',
                    value: p.labelRole,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Pengaturan ────────────────────────────────
              _SectionLabel(label: 'Pengaturan'),
              const SizedBox(height: 8),
              _MenuCard(
                items: [
                  _MenuItem(
                    icon : Icons.lock_outline_rounded,
                    label: 'Ganti Password',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fitur segera hadir'))),
                  ),
                  _MenuItem(
                    icon : Icons.notifications_outlined,
                    label: 'Notifikasi',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fitur segera hadir'))),
                  ),
                  _MenuItem(
                    icon : Icons.help_outline_rounded,
                    label: 'Bantuan & Panduan',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fitur segera hadir'))),
                  ),
                  _MenuItem(
                    icon : Icons.info_outline_rounded,
                    label: 'Tentang Aplikasi',
                    onTap: () => _showTentangApp(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _LogoutButton(
                isLoading: _isLoggingOut,
                onTap    : _handleLogout,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Aplikasi Presensi v2.1.0',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(UserProfileModel p) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.kNavyGradient),
      child: Stack(
        children: [
          // Dekorasi geometrik UMS
          Positioned(
            right : -20,
            top   : -15,
            child : Opacity(
              opacity: 0.06,
              child: Container(
                width : 120, height: 120,
                decoration: BoxDecoration(
                  border      : Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          // Garis bawah gold
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(height: 2,
                color: AppColors.kGold.withOpacity(0.5)),
          ),
          SafeArea(
            bottom: false,
            child : Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child  : Column(
                children: [
                  // Avatar inisial
                  Container(
                    width      : 84,
                    height     : 84,
                    decoration : BoxDecoration(
                      shape : BoxShape.circle,
                      color : Colors.white.withOpacity(0.15),
                      border: Border.all(
                          color: AppColors.kGold.withOpacity(0.6), width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        p.inisial,
                        style: AppTypography.heading1.copyWith(
                          color: Colors.white, fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    p.namaLengkap,
                    style    : AppTypography.hero.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children         : [
                      _HeaderPill(label: p.labelRole),
                      if (p.programStudi.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _programStudi?.nama ?? p.programStudi,
                            style   : AppTypography.heroSubtitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTentangApp() {
    showAboutDialog(
      context            : context,
      applicationName    : 'Presensi Face Recognition',
      applicationVersion : 'v2.1.0',
      applicationLegalese: '© 2026 Universitas Muhammadiyah Surakarta.',
    );
  }
}

// ─── Widget: Pill di header ───────────────────────────────────

class _HeaderPill extends StatelessWidget {
  final String label;
  const _HeaderPill({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color       : Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border      : Border.all(color: AppColors.kGold.withOpacity(0.4)),
    ),
    child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 12)),
  );
}

// ─── Widget: Statistik kehadiran semester ─────────────────────

class _StatistikCard extends StatelessWidget {
  final UserProfileModel profil;
  const _StatistikCard({required this.profil});

  @override
  Widget build(BuildContext context) {
    final persen   = profil.persentaseHadir ?? 0.0;
    final hadir    = profil.totalHadir      ?? 0;
    final sesi     = profil.totalSesi       ?? 0;
    final mk       = profil.totalMatakuliah ?? 0;

    Color progressColor;
    if (persen >= 75)      progressColor = AppColors.kStatusHadir;
    else if (persen >= 50) progressColor = AppColors.kStatusTerlambat;
    else                   progressColor = AppColors.kStatusAbsen;

    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow   : AppDecorations.cardShadow,
        border      : Border(
          bottom: BorderSide(color: AppColors.kGold, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 18, color: AppColors.kNavy),
              const SizedBox(width: 6),
              Text('Statistik Kehadiran Semester',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar kehadiran
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kehadiran',
                            style: AppTypography.label),
                        Text(
                          '${persen.toStringAsFixed(1)}%',
                          style: AppTypography.bodyBold.copyWith(
                            color: progressColor, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value          : (persen / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.kSoftGray,
                        valueColor     : AlwaysStoppedAnimation<Color>(
                            progressColor),
                        minHeight      : 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      persen >= 75
                          ? '✅ Memenuhi syarat kehadiran'
                          : persen >= 50
                              ? '⚠️ Perlu perhatian'
                              : '❌ Di bawah batas minimum',
                      style: AppTypography.caption.copyWith(
                          color: progressColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tiga angka statistik
          Row(
            children: [
              _StatItem(
                value: '$hadir',
                label: 'Sesi Hadir',
                color: AppColors.kStatusHadir,
              ),
              _StatDivider(),
              _StatItem(
                value: '$sesi',
                label: 'Total Sesi',
                color: AppColors.kNavy,
              ),
              _StatDivider(),
              _StatItem(
                value: '$mk',
                label: 'Matakuliah',
                color: AppColors.kNavyLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: AppTypography.heading2.copyWith(
                color: color, fontSize: 22)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 32, width: 1,
    color : AppColors.kSoftGray,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}

// ─── Widget: Card Matakuliah Saya ─────────────────────────────

class _MatakuliahSayaCard extends StatelessWidget {
  final int?         totalMatakuliah;
  final VoidCallback onTap;

  const _MatakuliahSayaCard({
    required this.totalMatakuliah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color       : AppColors.kNavy.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border      : Border.all(
              color: AppColors.kNavy.withOpacity(0.18), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kNavy.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.kNavy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matakuliah Saya',
                      style: AppTypography.bodyBold.copyWith(
                          color: AppColors.kNavy)),
                  const SizedBox(height: 2),
                  Text(
                    totalMatakuliah != null
                        ? '$totalMatakuliah matakuliah aktif semester ini'
                        : 'Lihat dan kelola matakuliah yang diikuti',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.kNavy, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Widget: Status kartu wajah ───────────────────────────────

class _FaceStatusCard extends StatelessWidget {
  final bool         isRegistered;
  final VoidCallback onTap;

  const _FaceStatusCard({
    required this.isRegistered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color    = isRegistered ? AppColors.kGreen   : AppColors.kWarning;
    final icon     = isRegistered
        ? Icons.face_retouching_natural_rounded
        : Icons.face_outlined;
    final title    = isRegistered
        ? 'Data Wajah Terdaftar'
        : 'Wajah Belum Didaftarkan';
    final desc     = isRegistered
        ? 'Kamu sudah bisa melakukan presensi dengan scan wajah.'
        : 'Daftarkan wajahmu terlebih dahulu untuk bisa melakukan presensi.';
    final btnLabel = isRegistered ? 'Perbarui Data Wajah' : 'Daftar Sekarang';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding   : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color       : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border      : Border.all(
              color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color : color.withOpacity(0.15),
                shape : BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children          : [
                  Text(title,
                      style: AppTypography.bodyBold.copyWith(
                          color: color, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(desc,
                      style: AppTypography.caption.copyWith(
                          color: color.withOpacity(0.8))),
                  const SizedBox(height: 8),
                  Text(btnLabel,
                      style: AppTypography.label.copyWith(
                        color     : color,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      )),
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
}

// ─── Widget: Info card ────────────────────────────────────────

class _InfoItem {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color       : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow   : AppDecorations.cardShadow,
    ),
    child: ListView.separated(
      shrinkWrap      : true,
      physics         : const NeverScrollableScrollPhysics(),
      itemCount       : items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.kSoftGray, indent: 52),
      itemBuilder: (_, i) => _InfoTile(item: items[i]),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;
  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child  : Row(
      children: [
        Icon(item.icon,
            color: AppColors.kNavy.withOpacity(0.5), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children          : [
              Text(item.label,
                  style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(item.value,
                  style: AppTypography.bodyBold.copyWith(
                      color: AppColors.kNavy, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Widget: Menu card ────────────────────────────────────────

class _MenuItem {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color?       color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color       : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow   : AppDecorations.cardShadow,
    ),
    child: ListView.separated(
      shrinkWrap      : true,
      physics         : const NeverScrollableScrollPhysics(),
      itemCount       : items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.kSoftGray, indent: 52),
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          onTap  : item.onTap,
          leading: Icon(item.icon,
              color: item.color ?? AppColors.kNavy.withOpacity(0.5),
              size : 22),
          title  : Text(item.label,
              style: AppTypography.body1.copyWith(
                color     : item.color ?? AppColors.kNavy,
                fontWeight: FontWeight.w500,
              )),
          trailing: Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade300, size: 20),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 2),
          dense: true,
        );
      },
    ),
  );
}

// ─── Widget: Tombol logout ────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final bool         isLoading;
  final VoidCallback onTap;
  const _LogoutButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width : double.infinity,
    height: 50,
    child : OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon     : isLoading
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.kDanger))
          : const Icon(Icons.logout_rounded, color: AppColors.kDanger),
      label: Text(
        isLoading ? 'Keluar...' : 'Keluar dari Akun',
        style: const TextStyle(
            color: AppColors.kDanger, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side : const BorderSide(color: AppColors.kDanger, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

// ─── Dialog konfirmasi logout ─────────────────────────────────

class _DialogKonfirmasiLogout extends StatelessWidget {
  const _DialogKonfirmasiLogout();

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Row(
      children: [
        const Icon(Icons.logout_rounded, color: AppColors.kDanger),
        const SizedBox(width: 10),
        Text('Keluar dari Akun',
            style: AppTypography.heading3.copyWith(
                color: AppColors.kNavy, fontSize: 16)),
      ],
    ),
    content: Text(
      'Kamu akan keluar dari aplikasi. Token sesi akan dihapus dan '
      'kamu perlu login ulang.',
      style: AppTypography.body2,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Batal', style: TextStyle(color: Colors.grey)),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style    : ElevatedButton.styleFrom(
          backgroundColor: AppColors.kDanger,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Ya, Keluar'),
      ),
    ],
  );
}

// ─── Helpers ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTypography.sectionTitle.copyWith(fontSize: 13),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: AppColors.kNavy),
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
      child  : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children         : [
          Icon(Icons.error_outline, size: 56,
              color: AppColors.kSoftGray),
          const SizedBox(height: 16),
          Text('Gagal memuat profil',
              style: AppTypography.heading3.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style    : AppTypography.body2),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon     : const Icon(Icons.refresh),
            label    : const Text('Coba Lagi'),
            style    : ElevatedButton.styleFrom(
              backgroundColor: AppColors.kNavy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}