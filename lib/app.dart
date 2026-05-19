import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_strings.dart';
import 'providers/settings_providers.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';

class SermonApp extends ConsumerWidget {
  const SermonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSizePref = ref.watch(fontSizeProvider);
    final fontScale = AppTheme.fontScales[fontSizePref.name] ?? 1.0;

    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(fontScale: fontScale),
      darkTheme: AppTheme.darkTheme(fontScale: fontScale),
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.gradientFor(Theme.of(context).brightness),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: const DashboardScreen(),
    );
  }
}
