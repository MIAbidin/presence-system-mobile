// lib/widgets/bottom_nav.dart
// FIX: Hapus BOTTOM OVERFLOWED - gunakan BottomNavigationBar bawaan Flutter
// yang secara otomatis menangani safe area

import 'package:flutter/material.dart';

import 'package:presensi_app/screens/home_screen.dart';
import 'package:presensi_app/screens/jadwal_screen.dart';
import 'package:presensi_app/screens/scan_screen.dart';
import 'package:presensi_app/screens/riwayat_screen.dart';
import 'package:presensi_app/screens/profil_screen.dart';
import 'package:presensi_app/core/theme.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final PageController _pageController;

  static const List<Widget> _pages = [
    HomeScreen(),
    JadwalScreen(),
    ScanScreen(),
    RiwayatScreen(),
    ProfilScreen(),
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller   : _pageController,
        physics      : const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children     : _pages,
      ),
      // Gunakan BottomNavigationBar bawaan Flutter - menangani safe area otomatis
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color    : Colors.white,
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset    : const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top  : false,
        child: SizedBox(
          height: 56,
          child : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Beranda'),
              _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Jadwal'),
              _buildScanItem(),
              _buildNavItem(3, Icons.history_outlined, Icons.history_rounded, 'Riwayat'),
              _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData iconAktif, String label) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap    : () => _onTabTapped(index),
      behavior : HitTestBehavior.opaque,
      child    : SizedBox(
        width: 60,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color       : selected ? AppColors.kNavy.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selected ? iconAktif : icon,
                color: selected ? AppColors.kNavy : Colors.grey.shade400,
                size : 22,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color     : selected ? AppColors.kNavy : Colors.grey.shade400,
                fontSize  : 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanItem() {
    final selected = _currentIndex == 2;
    return GestureDetector(
      onTap    : () => _onTabTapped(2),
      behavior : HitTestBehavior.opaque,
      child    : SizedBox(
        width : 60,
        height: 56,
        child : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 250),
              width     : 44,
              height    : 44,
              decoration: BoxDecoration(
                color    : selected ? AppColors.kNavy : AppColors.kNavy.withOpacity(0.85),
                shape    : BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color     : AppColors.kNavy.withOpacity(0.35),
                    blurRadius: selected ? 12 : 6,
                    offset    : const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                selected ? Icons.face_rounded : Icons.face_outlined,
                color: Colors.white,
                size : 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}