import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../main.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final xpNeeded = _level * 100;
    final xpProgress = _xp / xpNeeded;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _userName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text('Productivity Enthusiast', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),

            // Gamified Profile stats Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Level $_level Hero 🛡️',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                        Text(
                          '$_xp / $xpNeeded XP',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.ac_unit_rounded, color: Colors.blueAccent, size: 28),
                            const SizedBox(height: 4),
                            Text('$_freezers Freezers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Text('Streak Shields', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.autorenew_rounded, color: Colors.teal, size: 28),
                            const SizedBox(height: 4),
                            Text('$_restoreTokens Tokens', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Text('Streak Restores', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode Theme'),
                    secondary: const Icon(Icons.dark_mode_rounded, color: AppColors.primary),
                    value: isDark,
                    onChanged: _toggleDarkMode,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_rounded, color: AppColors.secondary),
                    title: const Text('Local Hive Backup'),
                    subtitle: const Text('Data is synced 100% offline'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.accent),
                    title: const Text('About Aura'),
                    subtitle: const Text('Version 1.0.0 • Vortex Tech Week 4'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final box = Hive.box(HiveService.settingsBox);
                  await box.put('isLoggedIn', false);
                  await box.put('currentUser', '');
                  await box.put('userName', 'User');
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
