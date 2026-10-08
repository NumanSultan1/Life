import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'providers/task_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/arc_provider.dart';
import 'providers/activity_provider.dart';
import 'services/app_lock.dart';
import 'providers/vitals_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<double> textScaleNotifier = ValueNotifier(1.0);

void main() async {
  // No debug output in release builds (errors can include personal data).
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship in assets/google_fonts so the app never needs the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  await HiveService.init();
  await NotificationService.init();

  final settingsBox = Hive.box(HiveService.settingsBox);
  final isDark = settingsBox.get('isDark', defaultValue: false);
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  textScaleNotifier.value = (settingsBox.get('textScale', defaultValue: 1.0) as num).toDouble();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => ArcProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => VitalsProvider()),
      ],
      child: const LifeDashboardApp(),
    ),
  );
}

class LifeDashboardApp extends StatelessWidget {
  const LifeDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Life',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          // "Larger text" in Profile multiplies the phone's own text size.
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: textScaleNotifier,
            builder: (context, scale, _) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaler: TextScaler.linear((media.textScaler.scale(1) * scale).clamp(0.8, 2.0))),
                child: AppLockGate(child: child!),
              );
            },
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainNavigationScreen(),
          },
        );
      },
    );
  }
}