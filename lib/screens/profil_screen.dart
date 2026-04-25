// lib/screens/profil_screen.dart
// Halaman profil mahasiswa — menampilkan data user dari /auth/me,
// status registrasi wajah, menu pengaturan, dan tombol logout.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:presensi_app/core/api_client.dart';
import 'package:presensi_app/providers/auth_provider.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFF2A5298);
const _kAccent    = Color(0xFF00BFA5);
const _kWarning   = Color(0xFFFFA726);
const _kDanger    = Color(0xFFEF5350);
const _kBgLight   = Color(0xFFF5F7FA);

// ─── Model UserProfile (response GET /auth/me) ────────────────

class UserProfileModel {
  final String   id;
  final String   nimNidn;
  final String   namaLengkap;
  final String   email;
  final String   role;
  final String   programStudi;
  final bool     isFaceRegistered;

  const UserProfileModel({
    required this.id,
    required this.nimNidn,
    required this.namaLengkap,
    required this.email,
    required this.role,
    required this.programStudi,
    required this.isFaceRegistered,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        id              : json['id']                as String,
        nimNidn         : json['nim_nidn']           as String,
        namaLengkap     : json['nama_lengkap']       as String,
        email           : json['email']              as String,
        role            : json['role']               as String,
        programStudi    : json['program_studi']      as String,
        isFaceRegistered: json['is_face_registered'] as bool,
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
  UserProfileModel? _profil;
  bool    _isLoading    = true;
  bool    _isLoggingOut = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchProfil();
  }

  // ── Fetch data profil ─────────────────────────────────────

  Future<void> _fetchProfil() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });
    try {
      // ApiClient().get() returns http.Response — decode body manually
      final response = await ApiClient().get('/auth/me');
      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _profil    = UserProfileModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Logout dengan konfirmasi ──────────────────────────────

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
          backgroundColor: _kDanger,
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
        title: const Text(
          'Perbarui Data Wajah',
          style: TextStyle(color: _kNavy, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Pembaruan data wajah memerlukan persetujuan admin kampus. '
          'Apakah kamu ingin mengajukan permintaan?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child    : const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content        : Text('Permintaan terkirim ke admin kampus.'),
                  backgroundColor: _kAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
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
      backgroundColor: _kBgLight,
      body: _isLoading
          ? const _LoadingView()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _fetchProfil)
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

              _FaceStatusCard(
                isRegistered: p.isFaceRegistered,
                onTap       : _goToUpdateWajah,
              ),
              const SizedBox(height: 16),

              const _SectionLabel(label: 'Informasi Akun'),
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
                    value: p.programStudi,
                  ),
                  _InfoItem(
                    icon : Icons.verified_user_outlined,
                    label: 'Role',
                    value: p.labelRole,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const _SectionLabel(label: 'Pengaturan'),
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
                  'Aplikasi Presensi v1.0.0',
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
          colors: [_kNavy, _kNavyLight],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child : Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child  : Column(
            children: [
              Container(
                width      : 80,
                height     : 80,
                decoration : BoxDecoration(
                  shape : BoxShape.circle,
                  color : Colors.white.withOpacity(0.2),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    p.inisial,
                    style: const TextStyle(
                      color     : Colors.white,
                      fontSize  : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.namaLengkap,
                style: const TextStyle(
                  color     : Colors.white,
                  fontSize  : 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children         : [
                  Container(
                    padding    : const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration : BoxDecoration(
                      color       : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.labelRole,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p.programStudi,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTentangApp() {
    showAboutDialog(
      context            : context,
      applicationName    : 'Presensi Face Recognition',
      applicationVersion : 'v1.0.0',
      applicationLegalese: '© 2026 Kampus. All rights reserved.',
    );
  }
}

// ─── Sub-widget: Status kartu wajah ──────────────────────────

class _FaceStatusCard extends StatelessWidget {
  final bool         isRegistered;
  final VoidCallback onTap;

  const _FaceStatusCard({
    required this.isRegistered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color    = isRegistered ? _kAccent : _kWarning;
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
          border      : Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding    : const EdgeInsets.all(10),
              decoration : BoxDecoration(
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
                    style: TextStyle(
                      color     : color,
                      fontSize  : 14,
                      fontWeight: FontWeight.bold,
                    )),
                  const SizedBox(height: 3),
                  Text(desc,
                    style: TextStyle(
                        color: color.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(btnLabel,
                    style: TextStyle(
                      color     : color,
                      fontSize  : 12,
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

// ─── Sub-widget: Info card ────────────────────────────────────

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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow   : [
          BoxShadow(
            color     : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset    : const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap      : true,
        physics         : const NeverScrollableScrollPhysics(),
        itemCount       : items.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade100, indent: 52),
        itemBuilder: (_, i) => _InfoTile(item: items[i]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final _InfoItem item;

  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child  : Row(
      children: [
        Icon(item.icon, color: _kNavy.withOpacity(0.5), size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children          : [
              Text(item.label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(item.value,
                style: const TextStyle(
                  color     : _kNavy,
                  fontSize  : 14,
                  fontWeight: FontWeight.w500,
                )),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Sub-widget: Menu card ────────────────────────────────────

class _MenuItem {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Color?       color; // FIX: field ada, constructor juga harus ada

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,             // FIX: parameter opsional ditambahkan
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
      boxShadow   : [
        BoxShadow(
          color     : Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset    : const Offset(0, 3),
        ),
      ],
    ),
    child: ListView.separated(
      shrinkWrap      : true,
      physics         : const NeverScrollableScrollPhysics(),
      itemCount       : items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100, indent: 52),
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          onTap  : item.onTap,
          leading: Icon(
            item.icon,
            color: item.color ?? _kNavy.withOpacity(0.5),
            size : 22,
          ),
          title  : Text(
            item.label,
            style: TextStyle(
              color     : item.color ?? _kNavy,
              fontSize  : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade300,
            size : 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 2),
          dense: true,
        );
      },
    ),
  );
}

// ─── Sub-widget: Tombol logout ────────────────────────────────

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
              width : 18,
              height: 18,
              child : CircularProgressIndicator(
                  strokeWidth: 2, color: _kDanger),
            )
          : const Icon(Icons.logout_rounded, color: _kDanger),
      label: Text(
        isLoading ? 'Keluar...' : 'Keluar dari Akun',
        style: const TextStyle(
            color: _kDanger, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side : const BorderSide(color: _kDanger, width: 1.5),
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
    title: const Row(
      children: [
        Icon(Icons.logout_rounded, color: _kDanger),
        SizedBox(width: 10),
        Text(
          'Keluar dari Akun',
          style: TextStyle(
            color     : _kNavy,
            fontSize  : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
    content: const Text(
      'Kamu akan keluar dari aplikasi. Token sesi akan dihapus dan '
      'kamu perlu login ulang.',
      style: TextStyle(fontSize: 14),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child    : const Text('Batal',
            style: TextStyle(color: Colors.grey)),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style    : ElevatedButton.styleFrom(
          backgroundColor: _kDanger,
          foregroundColor: Colors.white,
          shape          : RoundedRectangleBorder(
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
    style: const TextStyle(
      color        : _kNavy,
      fontSize     : 13,
      fontWeight   : FontWeight.bold,
      letterSpacing: 0.3,
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
      child  : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children         : [
          Icon(Icons.error_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Gagal memuat profil',
            style: TextStyle(
              color     : _kNavy,
              fontSize  : 16,
              fontWeight: FontWeight.bold,
            )),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style    : const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon     : const Icon(Icons.refresh),
            label    : const Text('Coba Lagi'),
            style    : ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}