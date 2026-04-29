// lib/screens/dosen/main_dosen_screen.dart
// Shell utama dosen — PageView 4 tab:
// Tab 0: Beranda | Tab 1: Monitor | Tab 2: Rekap | Tab 3: Profil

import 'package:flutter/material.dart';

import 'package:presensi_app/screens/dosen/beranda_dosen_screen.dart';
import 'package:presensi_app/screens/dosen/dashboard_dosen.dart';
import 'package:presensi_app/screens/dosen/rekap_screen.dart';
import 'package:presensi_app/screens/profil_screen.dart';
import 'package:presensi_app/widgets/bottom_nav_dosen.dart';

class MainDosenScreen extends StatefulWidget {
  /// Index tab awal (0=Beranda, 1=Monitor, 2=Rekap, 3=Profil)
  final int     initialIndex;

  /// Jika tidak null, tab Monitor langsung load sesi ini
  final String? monitorSesiId;

  const MainDosenScreen({
    super.key,
    this.initialIndex   = 0,
    this.monitorSesiId,
  });

  @override
  State<MainDosenScreen> createState() => _MainDosenScreenState();
}

class _MainDosenScreenState extends State<MainDosenScreen> {
  late int           _currentIndex;
  late PageController _pageController;

  // Key untuk DashboardDosen agar bisa update sesiId dari luar
  final _dashboardKey = GlobalKey<DashboardDosenState>();

  // Apakah ada sesi aktif — untuk badge di tab Monitor
  bool _adaSesiAktif = false;

  @override
  void initState() {
    super.initState();
    _currentIndex  = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve   : Curves.easeInOut,
    );
  }

  /// Dipanggil dari BerandaDosenScreen saat tap "Monitor Live"
  /// → pindah ke tab Monitor dengan sesiId tertentu
  void goToMonitor(String? sesiId) {
    // Update sesiId di DashboardDosen
    if (sesiId != null) {
      _dashboardKey.currentState?.loadSesi(sesiId);
    }
    _onTabTapped(1);
  }

  /// Dipanggil dari DashboardDosen atau BerandaDosenScreen
  /// untuk update badge sesi aktif
  void setAdaSesiAktif(bool value) {
    if (_adaSesiAktif != value) {
      setState(() => _adaSesiAktif = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Buat pages di sini agar bisa pass callback antar tab
    final pages = <Widget>[
      // Tab 0: Beranda
      BerandaDosenScreen(
        onGoToMonitor: goToMonitor,
        onSesiAktifChanged: setAdaSesiAktif,
      ),

      // Tab 1: Monitor
      DashboardDosen(
        key          : _dashboardKey,
        // Kalau masuk dari /dosen/monitor?sesi_id=xxx
        initialSesiId: widget.monitorSesiId,
        onSesiAktifChanged: setAdaSesiAktif,
        // Callback ke beranda jika ingin buka sesi
        onGoToBeranda: () => _onTabTapped(0),
      ),

      // Tab 2: Rekap
      const RekapListScreen(),

      // Tab 3: Profil
      const ProfilScreen(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller   : _pageController,
        // Nonaktifkan swipe manual — navigasi hanya via bottom nav
        physics      : const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children     : pages,
      ),
      bottomNavigationBar: BottomNavDosen(
        currentIndex: _currentIndex,
        onTap       : _onTabTapped,
        adaSesiAktif: _adaSesiAktif,
      ),
    );
  }
}