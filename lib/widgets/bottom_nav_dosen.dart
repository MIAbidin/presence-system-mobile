// lib/widgets/bottom_nav_dosen.dart
// FIX: Hapus BOTTOM OVERFLOWED - gunakan SafeArea dengan top:false

import 'package:flutter/material.dart';

const _kNavy = Color(0xFF003366);

class DosenTabIndex {
  DosenTabIndex._();
  static const int beranda = 0;
  static const int jadwal  = 1;
  static const int monitor = 2;
  static const int rekap   = 3;
  static const int profil  = 4;
  static const int total   = 5;
}

class _TabData {
  final String   label;
  final IconData icon;
  final IconData iconAktif;
  const _TabData(this.label, this.icon, this.iconAktif);
}

const List<_TabData> _tabs = [
  _TabData('Beranda', Icons.home_outlined, Icons.home_rounded),
  _TabData('Jadwal', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  _TabData('Monitor', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  _TabData('Rekap', Icons.summarize_outlined, Icons.summarize_rounded),
  _TabData('Profil', Icons.person_outline_rounded, Icons.person_rounded),
];

class BottomNavDosen extends StatelessWidget {
  final int  currentIndex;
  final void Function(int) onTap;
  final bool adaSesiAktif;

  const BottomNavDosen({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.adaSesiAktif = false,
  });

  @override
  Widget build(BuildContext context) {
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
            children: List.generate(_tabs.length, (i) {
              final tab      = _tabs[i];
              final selected = i == currentIndex;

              if (i == DosenTabIndex.monitor) {
                return _NavItemWithBadge(
                  label    : tab.label,
                  icon     : selected ? tab.iconAktif : tab.icon,
                  selected : selected,
                  showBadge: adaSesiAktif,
                  onTap    : () => onTap(i),
                );
              }

              return _NavItem(
                label   : tab.label,
                icon    : selected ? tab.iconAktif : tab.icon,
                selected: selected,
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
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap    : onTap,
      behavior : HitTestBehavior.opaque,
      child    : SizedBox(
        width : 60,
        height: 56,
        child : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color       : selected ? _kNavy.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? _kNavy : Colors.grey.shade400,
                size : 22,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color     : selected ? _kNavy : Colors.grey.shade400,
                fontSize  : 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemWithBadge extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final bool     showBadge;
  final VoidCallback onTap;

  const _NavItemWithBadge({
    required this.label,
    required this.icon,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap    : onTap,
      behavior : HitTestBehavior.opaque,
      child    : SizedBox(
        width : 60,
        height: 56,
        child : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color       : selected ? _kNavy.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: selected ? _kNavy : Colors.grey.shade400, size: 22),
                  if (showBadge)
                    Positioned(
                      top  : -2,
                      right: -2,
                      child: Container(
                        width : 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF5350),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color     : selected ? _kNavy : Colors.grey.shade400,
                fontSize  : 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}