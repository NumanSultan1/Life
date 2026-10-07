import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';

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
      duration: const Duration(milliseconds: 1800),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
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

  /// Animates one logo piece flying in from [from] with a little spin.
  Widget _piece(double start, Offset from, double spin, Widget child) {
    final curve = CurvedAnimation(parent: _controller, curve: Interval(start, start + 0.5, curve: Curves.easeOutBack));
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: from * (1 - curve.value),
          child: Transform.rotate(angle: spin * (1 - curve.value), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CurvedAnimation(parent: _controller, curve: const Interval(0.55, 1, curve: Curves.easeOut));

    return Scaffold(
      body: LiquidBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo assembled from three soft shapes, echoing the reference.
              SizedBox(
                width: 120,
                height: 110,
                child: Stack(
                  children: [
                    Positioned(
                      left: 10,
                      top: 0,
                      child: _piece(
                        0.0,
                        const Offset(-80, -60),
                        -math.pi / 2,
                        Container(
                          width: 42,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.pink.withValues(alpha: 0.95),
                            borderRadius: const BorderRadius.only(topRight: Radius.circular(42), bottomLeft: Radius.circular(8), topLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 2,
                      child: _piece(
                        0.15,
                        const Offset(80, -60),
                        math.pi / 2,
                        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFF8CC4FA), shape: BoxShape.circle)),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 0,
                      child: _piece(
                        0.3,
                        const Offset(0, 80),
                        0,
                        Container(
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60), topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: text,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(text),
                  child: Column(
                    children: [
                      const Text(
                        'Life Dashboard',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Organize Tasks, Habits & Mindset',
                        style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
                      ),
                    ],
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
