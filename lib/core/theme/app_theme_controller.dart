import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

const _themePreferenceKey = 'gym_eldeeb_theme';

final appThemeProvider =
    StateNotifierProvider<AppThemeController, AppThemeVariant>(
  (ref) => AppThemeController(),
);

class AppThemeController extends StateNotifier<AppThemeVariant> {
  int _changeVersion = 0;

  AppThemeController() : super(AppThemeVariant.darkGold) {
    unawaited(_restoreSavedTheme());
  }

  Future<void> _restoreSavedTheme() async {
    final changeVersion = _changeVersion;
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedName = preferences.getString(_themePreferenceKey);
      if (storedName == null) return;
      final restoredTheme = AppThemeVariant.values.byName(storedName);
      if (changeVersion == _changeVersion) state = restoredTheme;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'gym theme preferences',
          context: ErrorDescription('while restoring the saved app theme'),
        ),
      );
    }
  }

  Future<void> setTheme(AppThemeVariant variant) async {
    final changeVersion = ++_changeVersion;
    final preferences = await SharedPreferences.getInstance();
    final saved =
        await preferences.setString(_themePreferenceKey, variant.name);
    if (!saved) {
      throw StateError('تعذر حفظ اختيار المظهر على هذا الجهاز.');
    }
    if (changeVersion == _changeVersion) state = variant;
  }
}
