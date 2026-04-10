import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/bridge_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/providers_provider.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── تهيئة Storage (Hive) ──
  final storage = StorageService();
  await storage.init();

  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
      ],
      child: const CCPocketApp(),
    ),
  );
}

class CCPocketApp extends ConsumerWidget {
  const CCPocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔌 ابدأ الاتصال بـ Bridge + تحميل الإعدادات + تحميل المزودين
    ref.watch(bridgeServiceProvider);
    ref.watch(settingsProvider);
    ref.watch(liveProvidersProvider);

    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider).value ?? ThemeMode.dark;

    return MaterialApp.router(
      title: 'CCPocket Universal',
      theme:      CCTheme.light,
      darkTheme:  CCTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}



