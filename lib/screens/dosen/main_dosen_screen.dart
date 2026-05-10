// lib/screens/dosen/main_dosen_screen.dart
// v2.1.0 Fase 6 UPDATE — PageView 5 tab:
// Tab 0: Beranda  | Tab 1: Jadwal (BARU) | Tab 2: Monitor
// Tab 3: Rekap    | Tab 4: Profil
//
// Perubahan dari v2.0.0 (4 tab):
// - Tambah JadwalDosenScreen sebagai tab index 1
// - Monitor geser dari index 1 → 2
// - Rekap geser dari index 2 → 3
// - Profil geser dari index 3 → 4
// - BottomNavDosen kini pakai DosenTabIndex.monitor (= 2) untuk badge

import 'package:flutter/material.dart';

import 'package:presensi_app/screens/dosen/beranda_dosen_screen.dart';
import 'package:presensi_app/screens/dosen/jadwal_dosen_screen.dart';
import 'package:presensi_app/screens/dosen/dashboard_dosen.dart';
import 'package:presensi_app/screens/dosen/rekap_screen.dart';
import 'package:presensi_app/screens/profil_screen.dart';
import 'package:presensi_app/widgets/bottom_nav_dosen.dart';

class MainDosenScreen extends StatefulWidget {
  /// Index tab awal
  /// 0=Beranda, 1=Jadwal, 2=Monitor, 3=Rekap, 4=Profil
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
  late int            _currentIndex;
  late PageController _pageController;

  // Key untuk DashboardDosen agar bisa update sesiId dari luar
  final _dashboardKey = GlobalKey<DashboardDosenState>();

  // Apakah ada sesi aktif — untuk badge di tab Monitor (index 2)
  bool _adaSesiAktif = false;

  @override
  void initState() {
    super.initState();
    _currentIndex   = widget.initialIndex;
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

  /// Dipanggil dari BerandaDosenScreen atau JadwalDosenScreen
  /// saat tap "Monitor Live" → pindah ke tab Monitor dengan sesiId
  void goToMonitor(String? sesiId) {
    if (sesiId != null) {
      _dashboardKey.currentState?.loadSesi(sesiId);
    }
    _onTabTapped(DosenTabIndex.monitor);
  }

  /// Dipanggil dari DashboardDosen atau BerandaDosenScreen
  /// untuk update badge sesi aktif di tab Monitor
  void setAdaSesiAktif(bool value) {
    if (_adaSesiAktif != value) {
      setState(() => _adaSesiAktif = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pages dibangun di sini agar callback antar tab bisa diteruskan
    final pages = <Widget>[
      // Tab 0: Beranda
      BerandaDosenScreen(
        onGoToMonitor     : goToMonitor,
        onSesiAktifChanged: setAdaSesiAktif,
      ),

      // Tab 1: Jadwal (BARU Fase 6.2)
      JadwalDosenScreen(
        onGoToMonitor: goToMonitor,
      ),

      // Tab 2: Monitor
      DashboardDosen(
        key               : _dashboardKey,
        initialSesiId     : widget.monitorSesiId,
        onSesiAktifChanged: setAdaSesiAktif,
        onGoToBeranda     : () => _onTabTapped(DosenTabIndex.beranda),
      ),

      // Tab 3: Rekap
      const RekapListScreen(),

      // Tab 4: Profil
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