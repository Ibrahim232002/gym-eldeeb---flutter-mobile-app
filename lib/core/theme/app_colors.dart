import 'package:flutter/material.dart';

/// Semantic Design System Tokens for Gym ElDeeb (جيم الديب)
///
/// Dark-first luxury athletic aesthetic:
/// - Deep charcoal / near-black base
/// - Controlled rich gold branding accent (#D4AF37)
/// - Semantic status tones (emerald success, amber warning, ruby error)
/// - High-contrast readable typography for Arabic & Latin
class AppColors {
  AppColors._();

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

