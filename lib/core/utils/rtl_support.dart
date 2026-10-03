import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

/// RTL and Arabic localization utilities for Gym ElDeeb
class RtlSupport {
  RtlSupport._();

  /// Default application locale (Arabic)
  static const Locale arabicLocale = Locale('ar');

  /// Supported application locales
  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  /// Format currency with Egyptian Pound (EGP)
  static String formatEgp(num amount) {
    final formatter = NumberFormat('#,##0.##', 'ar');
    return '${formatter.format(amount)} ج.م';
  }

  /// Format date in Arabic locale
  static String formatDate(DateTime date) {
    final formatter = DateFormat('yyyy/MM/dd', 'ar');
    return formatter.format(date);
  }

  /// Directionality helper widget wrapper ensuring RTL layout
  static Widget forceRtl({required Widget child}) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: child,
    );
  }
}
