import 'package:flutter/material.dart';

enum AppThemeVariant {
  darkGold,
  darkBlue,
  light,
  darkPurple,
  darkGreen,
  neutral
}

/// Semantic Design System Tokens for Gym ElDeeb (جيم الديب)
///
/// Dark-first luxury athletic aesthetic:
/// - Deep charcoal / near-black base
/// - Controlled rich gold branding accent (#D4AF37)
/// - Semantic status tones (emerald success, amber warning, ruby error)
/// - High-contrast readable typography for Arabic & Latin
class AppColors {
  AppColors._();

  static const AppPalette darkGoldPalette = AppPalette(
    primary: primary,
    primaryDark: primaryDark,
    primaryLight: primaryLight,
    primaryContainer: primaryContainer,
    primaryGlow: primaryGlow,
    background: background,
    surface: surface,
    surfaceElevated: surfaceElevated,
    surfaceCard: surfaceCard,
    border: border,
    surfaceBorder: surfaceBorder,
    borderSubtle: borderSubtle,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textMuted: textMuted,
    disabled: disabled,
    success: success,
    warning: warning,
    error: error,
    offlineBar: offlineBar,
    onPrimary: Color(0xFF0A0F1A),
  );

  static const AppPalette darkBluePalette = AppPalette(
    primary: Color(0xFF60A5FA),
    primaryDark: Color(0xFF2563EB),
    primaryLight: Color(0xFF93C5FD),
    primaryContainer: Color(0x263B82F6),
    primaryGlow: Color(0x333B82F6),
    background: Color(0xFF080C14),
    surface: Color(0xFF0F1626),
    surfaceElevated: Color(0xFF151F33),
    surfaceCard: Color(0xFF11192B),
    border: Color(0xFF1E2B45),
    surfaceBorder: Color(0xFF1E2B45),
    borderSubtle: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    disabled: Color(0xFF475569),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    offlineBar: Color(0xFFD97706),
    onPrimary: Colors.white,
  );

  static const AppPalette lightPalette = AppPalette(
    primary: Color(0xFF9A7410),
    primaryDark: Color(0xFF765800),
    primaryLight: Color(0xFFB58A12),
    primaryContainer: Color(0x26D4AF37),
    primaryGlow: Color(0x1AD4AF37),
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceCard: Colors.white,
    border: Color(0xFFE2E8F0),
    surfaceBorder: Color(0xFFE2E8F0),
    borderSubtle: Color(0x140F172A),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    disabled: Color(0xFF94A3B8),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    error: Color(0xFFB91C1C),
    offlineBar: Color(0xFFB45309),
    onPrimary: Colors.white,
  );

  static const AppPalette darkPurplePalette = AppPalette(
    primary: Color(0xFFC4B5FD),
    primaryDark: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFDDD6FE),
    primaryContainer: Color(0x333B2460),
    primaryGlow: Color(0x333B2460),
    background: Color(0xFF0C0914),
    surface: Color(0xFF151020),
    surfaceElevated: Color(0xFF211831),
    surfaceCard: Color(0xFF191326),
    border: Color(0xFF382A4A),
    surfaceBorder: Color(0xFF382A4A),
    borderSubtle: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF8F5FF),
    textSecondary: Color(0xFFC0B5D0),
    textMuted: Color(0xFF9184A2),
    disabled: Color(0xFF5C5269),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    offlineBar: Color(0xFFD97706),
    onPrimary: Color(0xFF211533),
  );

  static const AppPalette darkGreenPalette = AppPalette(
    primary: Color(0xFF6EE7B7),
    primaryDark: Color(0xFF10B981),
    primaryLight: Color(0xFFA7F3D0),
    primaryContainer: Color(0x2634D399),
    primaryGlow: Color(0x2634D399),
    background: Color(0xFF07110D),
    surface: Color(0xFF0D1A13),
    surfaceElevated: Color(0xFF14251B),
    surfaceCard: Color(0xFF102017),
    border: Color(0xFF244132),
    surfaceBorder: Color(0xFF244132),
    borderSubtle: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFFA7C7B2),
    textMuted: Color(0xFF789382),
    disabled: Color(0xFF4B6354),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    offlineBar: Color(0xFFD97706),
    onPrimary: Color(0xFF062B1E),
  );

  static const AppPalette neutralPalette = AppPalette(
    primary: Color(0xFF334155),
    primaryDark: Color(0xFF1E293B),
    primaryLight: Color(0xFF64748B),
    primaryContainer: Color(0xFFE2E8F0),
    primaryGlow: Color(0x1F334155),
    background: Color(0xFFF1F3F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF8FAFC),
    surfaceCard: Color(0xFFFFFFFF),
    border: Color(0xFFD7DDE4),
    surfaceBorder: Color(0xFFD7DDE4),
    borderSubtle: Color(0x140F172A),
    textPrimary: Color(0xFF17212F),
    textSecondary: Color(0xFF465365),
    textMuted: Color(0xFF64748B),
    disabled: Color(0xFF9AA5B1),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    error: Color(0xFFB91C1C),
    offlineBar: Color(0xFFB45309),
    onPrimary: Colors.white,
  );

  static AppPalette paletteFor(AppThemeVariant variant) => switch (variant) {
        AppThemeVariant.darkGold => darkGoldPalette,
        AppThemeVariant.darkBlue => darkBluePalette,
        AppThemeVariant.light => lightPalette,
        AppThemeVariant.darkPurple => darkPurplePalette,
        AppThemeVariant.darkGreen => darkGreenPalette,
        AppThemeVariant.neutral => neutralPalette,
      };

  // Brand Gold Accents (Gym ElDeeb Signature)
  static const Color primary = Color(0xFFD4AF37); // Rich Classic Gold
  static const Color primaryDark = Color(0xFFB89728);
  static const Color primaryLight = Color(0xFFE5C158);
  static const Color primaryContainer = Color(0x26D4AF37);
  static const Color primaryGlow = Color(0x33D4AF37);

  // Dark Palette (Default)
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF0F1626);
  static const Color surfaceElevated = Color(0xFF151F33);
  static const Color surfaceCard = Color(0xFF11192B);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFF1E2B45);
  static const Color surfaceBorder = Color(0xFF1E2B45);
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color offlineBar = Color(0xFFD97706);

  // Typography (Dark Mode)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color disabled = Color(0xFF475569);

  // Typography (Light Mode)
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Semantic Status
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0x2010B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0x20F59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0x20EF4444);
  static const Color info = Color(0xFF0EA5E9);

  // WhatsApp Signature Brand
  static const Color whatsApp = Color(0xFF25D366);
  static const Color whatsAppContainer = Color(0x2225D366);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryContainer;
  final Color primaryGlow;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceCard;
  final Color border;
  final Color surfaceBorder;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color disabled;
  final Color success;
  final Color warning;
  final Color error;
  final Color offlineBar;
  final Color onPrimary;

  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryContainer,
    required this.primaryGlow,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceCard,
    required this.border,
    required this.surfaceBorder,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.disabled,
    required this.success,
    required this.warning,
    required this.error,
    required this.offlineBar,
    required this.onPrimary,
  });

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? primaryContainer,
    Color? primaryGlow,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceCard,
    Color? border,
    Color? surfaceBorder,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? disabled,
    Color? success,
    Color? warning,
    Color? error,
    Color? offlineBar,
    Color? onPrimary,
  }) =>
      AppPalette(
        primary: primary ?? this.primary,
        primaryDark: primaryDark ?? this.primaryDark,
        primaryLight: primaryLight ?? this.primaryLight,
        primaryContainer: primaryContainer ?? this.primaryContainer,
        primaryGlow: primaryGlow ?? this.primaryGlow,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        border: border ?? this.border,
        surfaceBorder: surfaceBorder ?? this.surfaceBorder,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        disabled: disabled ?? this.disabled,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        offlineBar: offlineBar ?? this.offlineBar,
        onPrimary: onPrimary ?? this.onPrimary,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      offlineBar: Color.lerp(offlineBar, other.offlineBar, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appPalette => Theme.of(this).extension<AppPalette>()!;
}
