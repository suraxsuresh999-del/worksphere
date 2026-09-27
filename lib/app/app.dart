import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'di/providers.dart';
import '../core/localization/generated/app_localizations.dart';
import '../presentation/common/screens/offline_screen.dart';

/// WorkSphere Application Root Widget
class WorkSphereApp extends ConsumerWidget {
  const WorkSphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final flutterThemeMode = switch (themeMode) {
      ThemeModeState.light => ThemeMode.light,
      ThemeModeState.dark => ThemeMode.dark,
      ThemeModeState.system => ThemeMode.system,
    };
    final connectivity = ref.watch(connectivityStatusProvider);
    final isOnline =
        connectivity.valueOrNull?.isNotEmpty != false &&
        !(connectivity.valueOrNull?.contains(ConnectivityResult.none) ?? false);

    if (!isOnline) {
      return MaterialApp(
        title: 'WorkSphere',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: flutterThemeMode,
        home: const OfflineScreen(),
      );
    }

    return MaterialApp.router(
      title: 'WorkSphere',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: flutterThemeMode,

      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('ta')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: router,
    );
  }
}
