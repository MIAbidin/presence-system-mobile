// lib/widgets/bottom_nav.dart
// FIX: tambah resizeToAvoidBottomInset: false di Scaffold MainScreen
// agar "BOTTOM OVERFLOWED BY 6.0 PIXELS" tidak muncul

import 'package:flutter/material.dart';

import 'package:presensi_app/screens/home_screen.dart';
import 'package:presensi_app/screens/jadwal_screen.dart';
import 'package:presensi_app/screens/scan_screen.dart';
import 'package:presensi_app/screens/riwayat_screen.dart';
import 'package:presensi_app/screens/profil_screen.dart';

class _TabItem {
  final String label;
  final IconData icon;
  final IconData iconAktif;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.iconAktif,
  });
}

const List<_TabItem> _tabs = [
  _TabItem(
    label    : 'Beranda',
    icon     : Icons.home_outlined,
    iconAktif: Icons.home_rounded,
  ),
  _TabItem(
    label    : 'Jadwal',
    icon     : Icons.calendar_month_outlined,
    iconAktif: Icons.calendar_month_rounded,
  ),
  _TabItem(
    label    : 'Scan',
    icon     : Icons.face_outlined,
    iconAktif: Icons.face_rounded,
  ),
  _TabItem(
    label    : 'Riwayat',
    icon     : Icons.history_outlined,
    iconAktif: Icons.history_rounded,
  ),
  _TabItem(
    label    : 'Profil',
    icon     : Icons.person_outline_rounded,
    iconAktif: Icons.person_rounded,
  ),
];

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX: mencegah overflow saat keyboard muncul
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller  : _pageController,
        physics     : const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children    : _pages,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap       : _onTabTapped,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF1E3A5F);

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
          height: 60,
          child : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab      = _tabs[i];
              final selected = i == currentIndex;

              if (i == 2) {
                return _ScanTabButton(
                  selected: selected,
                  onTap   : () => onTap(i),
                  color   : active,
                );
              }

              return _NavItem(
                label   : tab.label,
                icon    : selected ? tab.iconAktif : tab.icon,
                selected: selected,
                color   : active,
                onTap   : () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap    : onTap,
      behavior : HitTestBehavior.opaque,
      child    : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize     : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color       : selected ? color.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? color : Colors.grey.shade400,
                size : 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style   : TextStyle(
                color     : selected ? color : Colors.grey.shade400,
                fontSize  : 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanTabButton extends StatelessWidget {
  final bool   selected;
  final Color  color;
  final VoidCallback onTap;

  const _ScanTabButton({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap    : onTap,
      behavior : HitTestBehavior.opaque,
      child    : Column(
        mainAxisSize     : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration  : const Duration(milliseconds: 250),
            width     : 50,
            height    : 50,
            decoration: BoxDecoration(
              color      : selected ? color : color.withOpacity(0.85),
              shape      : BoxShape.circle,
              boxShadow  : [
                BoxShadow(
                  color     : color.withOpacity(0.35),
                  blurRadius: selected ? 16 : 8,
                  spreadRadius: selected ? 2 : 0,
                  offset    : const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              selected ? Icons.face_rounded : Icons.face_outlined,
              color: Colors.white,
              size : 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Scan',
            style: TextStyle(
              color     : selected ? color : Colors.grey.shade400,
              fontSize  : 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}