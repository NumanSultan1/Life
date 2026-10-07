import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _page = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Unleash Your Potential',
      'description': 'Propel your daily performance! Seamlessly combine Tasks, Habits, and Reflection into your personal power hub.',
      'icon': Icons.bolt_rounded,
    },
    {
      'title': 'Maintain Daily Habits',
      'description': 'Achieve star consistency with interactive streak trackers, shields, and custom notifications.',
      'icon': Icons.local_fire_department_rounded,
    },
    {
      'title': '100% Offline & Protected',
      'description': 'Your stats and personal journey stay completely secure and private local on your device.',
      'icon': Icons.shield_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() => setState(() => _page = _pageController.page ?? 0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onFinish() async {
    final box = Hive.box('settingsBox');
    await box.put('hasSeenOnboarding', true);
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final textTheme = Theme.of(context).textTheme;
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: AmbientBackground(
        child: Column(
          children: [
            // Liquid hero with a floating glass icon that drifts with the swipe.
            SizedBox(
              height: height * 0.5,
              child: AnimatedWaveClip(
                edge: WaveEdge.bottom,
                depth: 30,
                ripple: 4,
                child: LiquidBackground(
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextButton(
                              onPressed: _onFinish,
                              child: const Text('Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        for (var i = 0; i < _pages.length; i++)
                          Center(
                            child: Opacity(
                              opacity: (1 - (_page - i).abs()).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset((i - _page) * 160, 0),
                                child: Transform.scale(
                                  scale: 1 - ((_page - i).abs() * 0.3).clamp(0.0, 0.3),
                                  child: Floating(
                                    child: Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.18),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                                        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20))],
                                      ),
                                      child: Icon(_pages[i]['icon'] as IconData, size: 72, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: Column(
                      children: [
                        Text(page['title'] as String, style: textTheme.titleLarge?.copyWith(fontSize: 26), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        Text(page['description'] as String, style: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.55), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: _currentPage == index ? AppColors.primaryGradient : null,
                    color: _currentPage == index ? null : AppColors.lavender.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
                child: GlowButton(
                  label: isLast ? 'Get Started' : 'Continue',
                  onPressed: () {
                    if (!isLast) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _onFinish();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
