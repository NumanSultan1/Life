import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/life_logo.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      // Check if user has already seen onboarding and is logged in
      final box = Hive.box('settingsBox');
      final hasSeenOnboarding = box.get('hasSeenOnboarding', defaultValue: false) as bool;
      final isLoggedIn = box.get('isLoggedIn', defaultValue: false) as bool;
      if (isLoggedIn) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (hasSeenOnboarding) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagline = CurvedAnimation(parent: _controller, curve: const Interval(0.75, 1, curve: Curves.easeOut));

    return Scaffold(
      // Same white tile as the app icon, so launch feels continuous.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, Color(0xFFF1EFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(label: 'Life', child: LifeLogo(fontSize: 76, animation: _controller)),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: tagline,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(tagline),
                  child: Text(
                    'Tasks · Habits · Goals · Journal',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
