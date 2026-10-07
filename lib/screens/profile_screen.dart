import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../widgets/liquid/liquid.dart';
import 'statistics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'User';
  int _level = 1;
  int _xp = 0;
  int _freezers = 2;
  int _restoreTokens = 2;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    setState(() {
      _userName = user;
      _level = box.get('${user}_level', defaultValue: 1) as int;
      _xp = box.get('${user}_xp', defaultValue: 0) as int;
      _freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
      _restoreTokens = box.get('${user}_streakRestoreTokens', defaultValue: 2) as int;
    });
  }

  void _toggleDarkMode(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final box = Hive.box(HiveService.settingsBox);
    await box.put('isDark', isDark);
    setState(() {});
  }

  Future<void> _logOut() async {
    final box = Hive.box(HiveService.settingsBox);
    await box.put('isLoggedIn', false);
    await box.put('currentUser', '');
    await box.put('userName', 'User');
    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final xpNeeded = _level * 100;
    final xpProgress = _xp / xpNeeded;

    return Scaffold(
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedWaveClip(
                edge: WaveEdge.bottom,
                depth: 28,
                ripple: 3,
                child: LiquidBackground(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 56),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                          ),
                          Floating(
                            distance: 6,
                            child: Container(
                              width: 96,
                              height: 96,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.ringCenterGradient,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
                              ),
                              child: Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 40, color: AppColors.navy, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _userName,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Productivity Enthusiast',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Gamified Profile stats Card
                    StaggerIn(
                      child: GlassCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Level $_level Hero 🛡️',
                                    style: textTheme.titleMedium?.copyWith(fontSize: 16, color: isDark ? AppColors.sky : AppColors.royal),
                                  ),
                                ),
                                Text('$_xp / $xpNeeded XP', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, c) => Stack(
                                children: [
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3E6F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: xpProgress.clamp(0.0, 1.0)),
                                    duration: const Duration(milliseconds: 1000),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, v, _) => Container(
                                      height: 10,
                                      width: c.maxWidth * v,
                                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatTile(icon: Icons.ac_unit_rounded, color: AppColors.sky, value: _freezers, label: 'Streak Shields'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatTile(icon: Icons.autorenew_rounded, color: AppColors.accent, value: _restoreTokens, label: 'Streak Restores'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StaggerIn(
                      index: 1,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingRow(
                              icon: Icons.dark_mode_rounded,
                              color: AppColors.violet,
                              title: 'Dark Mode Theme',
                              trailing: Switch(value: isDark, onChanged: _toggleDarkMode),
                              onTap: () => _toggleDarkMode(!isDark),
                            ),
                            _SettingRow(
                              icon: Icons.bar_chart_rounded,
                              color: AppColors.royal,
                              title: 'Your Progress',
                              subtitle: 'Stats for tasks, habits, journal and goals',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())),
                            ),
                            _SettingRow(
                              icon: Icons.cloud_done_rounded,
                              color: AppColors.sky,
                              title: 'Local Hive Backup',
                              subtitle: 'Data is synced 100% offline',
                              onTap: () {},
                            ),
                            _SettingRow(
                              icon: Icons.info_outline_rounded,
                              color: AppColors.accent,
                              title: 'About Life',
                              subtitle: 'Version 1.0.0 • Vortex Tech Week 4',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggerIn(
                      index: 2,
                      child: Pressable(
                        onTap: _logOut,
                        child: Container(
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.logout_rounded, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;

  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          CountUpText(
            value: value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingRow({required this.icon, required this.color, required this.title, this.subtitle, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                  if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodyMedium?.color),
          ],
        ),
      ),
    );
  }
}
