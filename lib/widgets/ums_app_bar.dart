// lib/widgets/ums_app_bar.dart
// v2.1.0 — SliverAppBar UMS dengan gradient navy + logo UMS
// Tema visual resmi Universitas Muhammadiyah Surakarta

import 'package:flutter/material.dart';
import 'package:presensi_app/core/theme.dart';

// ══════════════════════════════════════════════════════════════
// UMS SLIVER APP BAR
// ══════════════════════════════════════════════════════════════

/// SliverAppBar bertema UMS dengan gradient navy dan logo
/// Dipakai di HomeScreen, JadwalScreen, dll. sebagai header
class UMSSliverAppBar extends StatelessWidget {
  /// Judul utama (nama mahasiswa / nama halaman)
  final String title;

  /// Subjudul (NIM / nama program studi)
  final String? subtitle;

  /// Widget di pojok kanan (notif bell, dsb.)
  final Widget? action;

  /// Tinggi saat expanded (default 160)
  final double expandedHeight;

  /// Widget tambahan di bawah judul (statistik ringkasan, dsb.)
  final Widget? bottomContent;

  const UMSSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.expandedHeight = 160,
    this.bottomContent,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned        : true,
      floating      : false,
      snap          : false,
      backgroundColor: AppColors.kNavy,
      elevation     : 0,
      leading       : _buildLogo(),
      title         : _buildCollapsedTitle(),
      actions       : action != null ? [action!, const SizedBox(width: 8)] : null,
      flexibleSpace : FlexibleSpaceBar(
        collapseMode : CollapseMode.pin,
        background   : _buildExpandedBackground(context),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child  : _UMSLogoIcon(),
    );
  }

  Widget _buildCollapsedTitle() {
    return Text(
      title,
      maxLines : 1,
      overflow : TextOverflow.ellipsis,
      style    : AppTypography.hero.copyWith(fontSize: 16),
    );
  }

  Widget _buildExpandedBackground(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.kNavyGradient),
      child     : Stack(
        children: [
          // Dekorasi geometrik UMS
          Positioned(
            right : -30,
            top   : -20,
            child : _GeometricDecor(size: 140, opacity: 0.06),
          ),
          Positioned(
            right : 40,
            bottom: 10,
            child : _GeometricDecor(size: 60, opacity: 0.04),
          ),
          // Garis bawah gold tipis
          Positioned(
            bottom: 0,
            left  : 0,
            right : 0,
            child : Container(height: 2, color: AppColors.kGold.withOpacity(0.5)),
          ),
          // Konten utama
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children          : [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _UMSLogoIcon(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style   : AppTypography.hero.copyWith(fontSize: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style   : AppTypography.heroSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                  if (bottomContent != null) ...[
                    const SizedBox(height: 16),
                    bottomContent!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// UMS REGULAR APP BAR (non-sliver)
// ══════════════════════════════════════════════════════════════

/// AppBar biasa bertema UMS — untuk halaman standalone
class UMSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String  title;
  final bool    showLogo;
  final List<Widget>? actions;
  final bool    showBack;
  final Color?  backgroundColor;

  const UMSAppBar({
    super.key,
    required this.title,
    this.showLogo      = false,
    this.actions,
    this.showBack      = true,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.kNavy,
      foregroundColor: Colors.white,
      elevation      : 0,
      leading        : showBack
          ? IconButton(
              icon    : const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            )
          : showLogo
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child  : _UMSLogoIcon(),
                )
              : null,
      title          : Row(
        children: [
          if (!showBack && !showLogo) _UMSLogoIcon(),
          if (!showBack && !showLogo) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style   : AppTypography.hero.copyWith(fontSize: 17),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
      bottom : PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          color : AppColors.kGold.withOpacity(0.4),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KOMPONEN INTERNAL
// ══════════════════════════════════════════════════════════════

/// Logo UMS berbentuk icon placeholder (ganti dengan asset logo asli)
/// Asset: assets/images/logo_ums.png (tambahkan ke pubspec.yaml)
class _UMSLogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Logo_UMS.png',
      height: 32,
      width : 32,
    );
  }
}

/// Dekorasi geometrik abstract di background AppBar
class _GeometricDecor extends StatelessWidget {
  final double size;
  final double opacity;

  const _GeometricDecor({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width     : size,
        height    : size,
        decoration: BoxDecoration(
          border      : Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Center(
          child: Container(
            width     : size * 0.6,
            height    : size * 0.6,
            decoration: BoxDecoration(
              border      : Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(size * 0.12),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHIMMER LOADING PLACEHOLDER
// ══════════════════════════════════════════════════════════════

/// Shimmer placeholder untuk card loading state
/// Dipakai sebelum data dari API selesai dimuat
class ShimmerCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerCard({
    super.key,
    this.height      = 80,
    this.width,
    this.borderRadius,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync   : this,
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width     : widget.width ?? double.infinity,
          height    : widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin : Alignment(_animation.value - 1, 0),
              end   : Alignment(_animation.value + 1, 0),
              colors: [
                AppColors.kSoftGray,
                AppColors.kSoftGray.withOpacity(0.5),
                AppColors.kSoftGray,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// List shimmer cards
class ShimmerList extends StatelessWidget {
  final int   count;
  final double cardHeight;
  final double spacing;

  const ShimmerList({
    super.key,
    this.count      = 3,
    this.cardHeight = 88,
    this.spacing    = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) => Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child  : ShimmerCard(height: cardHeight),
      )),
    );
  }
}