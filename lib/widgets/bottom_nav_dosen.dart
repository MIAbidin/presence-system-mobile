// lib/widgets/bottom_nav_dosen.dart
// Bottom navigation bar khusus dosen — 4 tab:
// Beranda / Monitor / Rekap / Profil

import 'package:flutter/material.dart';

// ─── Konstanta warna ──────────────────────────────────────────
const _kNavy = Color(0xFF1E3A5F);

// ─── Data tab ─────────────────────────────────────────────────
class _TabItem {
  final String   label;
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
    label    : 'Monitor',
    icon     : Icons.bar_chart_outlined,
    iconAktif: Icons.bar_chart_rounded,
  ),
  _TabItem(
    label    : 'Rekap',
    icon     : Icons.summarize_outlined,
    iconAktif: Icons.summarize_rounded,
  ),
  _TabItem(
    label    : 'Profil',
    icon     : Icons.person_outline_rounded,
    iconAktif: Icons.person_rounded,
  ),
];

// ─── BottomNavDosen ───────────────────────────────────────────

class BottomNavDosen extends StatelessWidget {
  final int  currentIndex;
  final void Function(int) onTap;

  /// Kalau ada sesi aktif, tab Monitor tampilkan badge merah kecil
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
          height: 60,
          child : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab      = _tabs[i];
              final selected = i == currentIndex;

              // Tab Monitor punya badge sesi aktif
              if (i == 1) {
                return _NavItemWithBadge(
                  label      : tab.label,
                  icon       : selected ? tab.iconAktif : tab.icon,
                  selected   : selected,
                  color      : _kNavy,
                  showBadge  : adaSesiAktif,
                  onTap      : () => onTap(i),
                );
              }

              return _NavItem(
                label   : tab.label,
                icon    : selected ? tab.iconAktif : tab.icon,
                selected: selected,
                color   : _kNavy,
                onTap   : () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Item nav biasa ───────────────────────────────────────────

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
        child  : Column(
          mainAxisSize     : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.1)
                    : Colors.transparent,
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
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item nav dengan badge (tab Monitor) ──────────────────────

class _NavItemWithBadge extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color    color;
  final bool     showBadge;
  final VoidCallback onTap;

  const _NavItemWithBadge({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap    : onTap,
      behavior : HitTestBehavior.opaque,
      child    : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child  : Column(
          mainAxisSize     : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration  : const Duration(milliseconds: 200),
              padding   : const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: selected ? color : Colors.grey.shade400,
                    size : 22,
                  ),
                  // Badge merah kalau ada sesi aktif
                  if (showBadge)
                    Positioned(
                      top  : -3,
                      right: -3,
                      child: Container(
                        width : 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF5350),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style   : TextStyle(
                color     : selected ? color : Colors.grey.shade400,
                fontSize  : 10,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}