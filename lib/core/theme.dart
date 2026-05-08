// lib/core/theme.dart
// Tema resmi Universitas Muhammadiyah Surakarta (UMS)
// Dominasi: Navy Blue + Gold + Muhammadiyah Green
// v2.1.0 — Fase 1

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════
// PALET WARNA — IDENTITAS RESMI UMS
// ══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Warna Utama (Core) ────────────────────────────────────
  /// Navy Blue — warna paling dominan UMS (~80% desain)
  static const Color kPrimary    = Color(0xFF003366);
  static const Color kNavy       = Color(0xFF003366);

  /// Navy Dark — untuk heading dan teks judul
  static const Color kNavyDark   = Color(0xFF002147);

  /// Navy Light — gradient pair untuk AppBar
  static const Color kNavyLight  = Color(0xFF1A4A80);

  /// Gold UMS — aksen CTA dan badge aktif (~10% desain)
  static const Color kGold       = Color(0xFFFDB813);
  static const Color kAccent     = Color(0xFFFDB813);

  /// Muhammadiyah Green — identitas hijau, status hadir
  static const Color kGreen      = Color(0xFF2D6A4F);

  // ── Background & Surface ─────────────────────────────────
  static const Color kBgLight    = Color(0xFFF8F9FA);
  static const Color kSurface    = Color(0xFFFFFFFF);
  static const Color kSoftGray   = Color(0xFFE9ECEF);

  // ── Teks ─────────────────────────────────────────────────
  static const Color kTextPrimary   = Color(0xFF212529);
  static const Color kTextSecondary = Color(0xFF6C757D);

  // ── Warna Status Kehadiran ────────────────────────────────
  static const Color kStatusHadir     = Color(0xFF2D6A4F); // Muhammadiyah Green
  static const Color kStatusTerlambat = Color(0xFFFDB813); // UMS Gold
  static const Color kStatusAbsen     = Color(0xFFC0392B); // Merah
  static const Color kStatusIzin      = Color(0xFF1A5276); // Navy turunan
  static const Color kStatusSakit     = Color(0xFF7D3C98); // Ungu

  // ── Warna Feedback ────────────────────────────────────────
  static const Color kWarning    = Color(0xFFE67E22);
  static const Color kDanger     = Color(0xFFC0392B);
  static const Color kSuccess    = Color(0xFF2D6A4F);
  static const Color kInfo       = Color(0xFF1A5276);

  // ── Warna Mode ────────────────────────────────────────────
  static const Color kModeOnline  = Color(0xFF1A5276); // Navy turunan
  static const Color kModeOffline = Color(0xFF2D6A4F); // Muhammadiyah Green

  // ── Warna Kelas (A, B, C) ─────────────────────────────────
  static const Color kKelasA = Color(0xFF003366); // Navy
  static const Color kKelasB = Color(0xFF2D6A4F); // Green
  static const Color kKelasC = Color(0xFF7D3C98); // Purple
  static const Color kKelasD = Color(0xFFE67E22); // Orange
  static const Color kKelasE = Color(0xFF1A5276); // Navy turunan

  // ── Gradient Utama ────────────────────────────────────────
  static const LinearGradient kNavyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end  : Alignment.bottomRight,
    colors: [kNavy, kNavyLight],
  );

  static const LinearGradient kGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end  : Alignment.bottomRight,
    colors: [Color(0xFFFDB813), Color(0xFFFFD700)],
  );

  // ── Helper: warna berdasarkan status kehadiran ────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir'    : return kStatusHadir;
      case 'terlambat': return kStatusTerlambat;
      case 'absen'    : return kStatusAbsen;
      case 'izin'     : return kStatusIzin;
      case 'sakit'    : return kStatusSakit;
      default         : return kTextSecondary;
    }
  }

  // ── Helper: warna berdasarkan persentase kehadiran ────────
  static Color persentaseColor(double persen) {
    if (persen >= 75) return kStatusHadir;
    if (persen >= 50) return kWarning;
    return kStatusAbsen;
  }

  // ── Helper: warna kelas berdasarkan kode ─────────────────
  static Color kelasColor(String kodeKelas) {
    switch (kodeKelas.toUpperCase()) {
      case 'A' : return kKelasA;
      case 'B' : return kKelasB;
      case 'C' : return kKelasC;
      case 'D' : return kKelasD;
      case 'E' : return kKelasE;
      default  : return kNavy;
    }
  }

  // ── Helper: warna mode kelas ──────────────────────────────
  static Color modeColor(String mode) {
    return mode.toLowerCase() == 'online' ? kModeOnline : kModeOffline;
  }
}

// ══════════════════════════════════════════════════════════════
// TIPOGRAFI — GOOGLE FONTS
// ══════════════════════════════════════════════════════════════

class AppTypography {
  AppTypography._();

  // ── Heading: Montserrat — kesan modern & tegas UMS ────────
  static TextStyle heading1 = GoogleFonts.montserrat(
    fontSize  : 28,
    fontWeight: FontWeight.w700,
    color     : AppColors.kNavyDark,
    height    : 1.2,
  );

  static TextStyle heading2 = GoogleFonts.montserrat(
    fontSize  : 22,
    fontWeight: FontWeight.w700,
    color     : AppColors.kNavyDark,
    height    : 1.3,
  );

  static TextStyle heading3 = GoogleFonts.montserrat(
    fontSize  : 18,
    fontWeight: FontWeight.w600,
    color     : AppColors.kNavyDark,
    height    : 1.3,
  );

  static TextStyle sectionTitle = GoogleFonts.montserrat(
    fontSize  : 15,
    fontWeight: FontWeight.w700,
    color     : AppColors.kNavy,
    letterSpacing: 0.3,
  );

  // ── Body: Inter — keterbacaan optimal ─────────────────────
  static TextStyle body1 = GoogleFonts.inter(
    fontSize  : 14,
    fontWeight: FontWeight.w400,
    color     : AppColors.kTextPrimary,
    height    : 1.5,
  );

  static TextStyle body2 = GoogleFonts.inter(
    fontSize  : 13,
    fontWeight: FontWeight.w400,
    color     : AppColors.kTextSecondary,
    height    : 1.5,
  );

  static TextStyle bodyBold = GoogleFonts.inter(
    fontSize  : 14,
    fontWeight: FontWeight.w600,
    color     : AppColors.kTextPrimary,
  );

  static TextStyle label = GoogleFonts.inter(
    fontSize  : 12,
    fontWeight: FontWeight.w500,
    color     : AppColors.kTextSecondary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize  : 11,
    fontWeight: FontWeight.w400,
    color     : AppColors.kTextSecondary,
  );

  // ── Badge & Pill ──────────────────────────────────────────
  static TextStyle badge = GoogleFonts.inter(
    fontSize  : 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle badgeSmall = GoogleFonts.inter(
    fontSize  : 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // ── Kode Sesi: JetBrains Mono ─────────────────────────────
  static TextStyle kodeSesi = GoogleFonts.jetBrainsMono(
    fontSize  : 52,
    fontWeight: FontWeight.w700,
    color     : Colors.white,
    letterSpacing: 8,
  );

  static TextStyle kodeSmall = GoogleFonts.jetBrainsMono(
    fontSize  : 18,
    fontWeight: FontWeight.w700,
    color     : AppColors.kNavy,
    letterSpacing: 3,
  );

  // ── Sapaan / Hero ─────────────────────────────────────────
  static TextStyle hero = GoogleFonts.montserrat(
    fontSize  : 24,
    fontWeight: FontWeight.w700,
    color     : Colors.white,
    height    : 1.2,
  );

  static TextStyle heroSubtitle = GoogleFonts.inter(
    fontSize  : 13,
    fontWeight: FontWeight.w400,
    color     : Colors.white70,
  );

  // ── Button ────────────────────────────────────────────────
  static TextStyle button = GoogleFonts.inter(
    fontSize  : 15,
    fontWeight: FontWeight.w700,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize  : 13,
    fontWeight: FontWeight.w600,
  );
}

// ══════════════════════════════════════════════════════════════
// DECORATION & SHAPE CONSTANTS
// ══════════════════════════════════════════════════════════════

class AppDecorations {
  AppDecorations._();

  // ── Border Radius ─────────────────────────────────────────
  static const double kRadiusCard   = 14.0;
  static const double kRadiusButton = 12.0;
  static const double kRadiusBadge  = 20.0;
  static const double kRadiusInput  = 10.0;
  static const double kRadiusSheet  = 20.0;

  // ── Elevation / Shadow ────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color     : Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset    : const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color     : AppColors.kNavy.withOpacity(0.25),
      blurRadius: 12,
      offset    : const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> goldShadow = [
    BoxShadow(
      color     : AppColors.kGold.withOpacity(0.35),
      blurRadius: 16,
      offset    : const Offset(0, 4),
    ),
  ];

  // ── Card Decoration ───────────────────────────────────────
  static BoxDecoration card = BoxDecoration(
    color        : AppColors.kSurface,
    borderRadius : BorderRadius.circular(kRadiusCard),
    boxShadow    : cardShadow,
  );

  static BoxDecoration cardActive = BoxDecoration(
    color        : AppColors.kSurface,
    borderRadius : BorderRadius.circular(kRadiusCard),
    border       : Border.all(color: AppColors.kNavy.withOpacity(0.3), width: 1.5),
    boxShadow    : cardShadow,
  );

  /// Card dengan border bawah Gold — untuk card featured/aktif
  static BoxDecoration cardFeatured = BoxDecoration(
    color        : AppColors.kSurface,
    borderRadius : BorderRadius.circular(kRadiusCard),
    border       : Border(
      bottom: BorderSide(color: AppColors.kGold, width: 3),
    ),
    boxShadow    : cardShadow,
  );

  // ── AppBar Gradient ───────────────────────────────────────
  static BoxDecoration appBarGradient = const BoxDecoration(
    gradient: AppColors.kNavyGradient,
  );

  // ── Input Field ───────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText  : labelText,
      hintText   : hintText,
      prefixIcon : prefixIcon,
      suffixIcon : suffixIcon,
      filled     : true,
      fillColor  : AppColors.kBgLight,
      border     : OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide  : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide  : BorderSide(color: AppColors.kSoftGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide  : const BorderSide(color: AppColors.kNavy, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        color   : AppColors.kTextSecondary,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        color   : AppColors.kTextSecondary.withOpacity(0.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TEMA LENGKAP — MaterialApp.theme
// ══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor : AppColors.kNavy,
        primary   : AppColors.kNavy,
        secondary : AppColors.kGold,
        tertiary  : AppColors.kGreen,
        error     : AppColors.kDanger,
        surface   : AppColors.kSurface,
        background: AppColors.kBgLight,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.kBgLight,

      // ── AppBar ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.kNavy,
        foregroundColor: Colors.white,
        elevation      : 0,
        centerTitle    : false,
        titleTextStyle : GoogleFonts.montserrat(
          fontSize  : 18,
          fontWeight: FontWeight.w700,
          color     : Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Card ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 1,
        color    : AppColors.kSurface,
        shape    : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusCard),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── ElevatedButton — CTA utama: GOLD ──────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kGold,
          foregroundColor: AppColors.kNavyDark,
          elevation      : 0,
          minimumSize    : const Size(double.infinity, 52),
          shape          : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.kRadiusButton),
          ),
          textStyle: AppTypography.button.copyWith(color: AppColors.kNavyDark),
        ),
      ),

      // ── OutlinedButton — Sekunder ─────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.kNavy,
          side: const BorderSide(color: AppColors.kNavy, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.kRadiusButton),
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ── TextButton ────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.kNavy,
          textStyle: AppTypography.buttonSmall,
        ),
      ),

      // ── Input ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled    : true,
        fillColor : AppColors.kBgLight,
        border    : OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusInput),
          borderSide  : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusInput),
          borderSide  : BorderSide(color: AppColors.kSoftGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusInput),
          borderSide  : const BorderSide(color: AppColors.kNavy, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color   : AppColors.kTextSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color   : AppColors.kTextSecondary.withOpacity(0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      ),

      // ── Bottom Navigation ─────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor     : AppColors.kSurface,
        selectedItemColor   : AppColors.kNavy,
        unselectedItemColor : AppColors.kTextSecondary.withOpacity(0.6),
        selectedLabelStyle  : GoogleFonts.inter(
          fontSize  : 10,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        elevation           : 8,
        type                : BottomNavigationBarType.fixed,
      ),

      // ── Tab Bar ───────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor        : Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor    : Colors.white,
        indicatorSize     : TabBarIndicatorSize.tab,
        labelStyle        : GoogleFonts.inter(
          fontSize  : 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
      ),

      // ── Chip ──────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor : AppColors.kSoftGray,
        selectedColor   : AppColors.kNavy,
        labelStyle      : GoogleFonts.inter(fontSize: 12),
        padding         : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape           : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.kSurface,
        shape           : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.kRadiusSheet),
        ),
        titleTextStyle : GoogleFonts.montserrat(
          fontSize  : 17,
          fontWeight: FontWeight.w700,
          color     : AppColors.kNavyDark,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color   : AppColors.kTextPrimary,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior       : SnackBarBehavior.floating,
        shape           : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentTextStyle: GoogleFonts.inter(fontSize: 13),
      ),

      // ── Divider ───────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color    : AppColors.kSoftGray,
        thickness: 1,
        space    : 1,
      ),

      // ── Progress Indicator ────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color           : AppColors.kNavy,
        linearTrackColor: AppColors.kSoftGray,
      ),

      // ── Text Theme menggunakan Inter ──────────────────────
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge : AppTypography.heading1,
        displayMedium: AppTypography.heading2,
        displaySmall : AppTypography.heading3,
        headlineMedium: AppTypography.sectionTitle,
        bodyLarge    : AppTypography.body1,
        bodyMedium   : AppTypography.body2,
        bodySmall    : AppTypography.caption,
        labelLarge   : AppTypography.button,
        labelMedium  : AppTypography.label,
        labelSmall   : AppTypography.badge,
      ),
    );
  }
}