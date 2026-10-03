import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/rtl_support.dart';
import 'router/app_router.dart';

/// Entry point of the Gym ElDeeb Flutter Mobile Application
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize Supabase with publishable key and project URL.
  // Note: Service role keys or database credentials are NEVER exposed to client Flutter apps.
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
    debug: false,
  );

  runApp(
    const ProviderScope(
      child: GymElDeebApp(),
    ),
  );
}

/// Root Widget for Gym ElDeeb
class GymElDeebApp extends ConsumerWidget {
  const GymElDeebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Gym ElDeeb - جيم الديب',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      // Arabic-First Localization and full RTL direction support
      locale: RtlSupport.arabicLocale,
      supportedLocales: RtlSupport.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
