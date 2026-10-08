import '../services/app_lock.dart';
import '../widgets/life_buddy.dart';
import '../assistant/assistant_screen.dart';
import '../assistant/memory_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../widgets/liquid/liquid.dart';
import 'statistics_screen.dart';
import 'app_limits_screen.dart';
import 'achievements_screen.dart';
import 'focus_screen.dart';
import 'activity_screen.dart';
import 'breathe_screen.dart';
import 'medical_id_screen.dart';
import 'medicines_screen.dart';
import 'money_screen.dart';
import 'insights_screen.dart';
import 'weekly_review_screen.dart';
import 'package:provider/provider.dart';
import '../providers/arc_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/task_provider.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/reminder_settings.dart';
import '../utils/feedback.dart';
import '../widgets/life_logo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String _subtitle = '';
  int _level = 1;
  int _xp = 0;
  int _xpBank = 0;
  int _freezers = 2;
  int _restoreTokens = 1;

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
      _restoreTokens = box.get('${user}_streakRestoreTokens', defaultValue: 1) as int;
      _xpBank = HiveService.getXpBank();
      final joined = DateTime.tryParse(box.get('${user}_joined', defaultValue: '') as String);
      _subtitle = joined != null ? 'Member since ${DateFormat('MMMM yyyy').format(joined)}' : 'Level $_level';
    });
  }

  Future<void> _setDailyReminder(bool on) async {
    if (!on) {
      await ReminderSettings.setDailyCheckIn(null);
      return setState(() {});
    }
    if (!await NotificationService.requestPermission()) {
      if (mounted) showInfoSnackBar(context, 'Notifications are blocked. You can allow them in your phone settings.');
      return;
    }
    if (!mounted) return;
    final time = await showLiquidTimePicker(context, initialTime: ReminderSettings.dailyCheckIn ?? const TimeOfDay(hour: 20, minute: 0), title: 'Daily check-in time');
    if (time == null) return;
    await ReminderSettings.setDailyCheckIn(time);
    if (mounted) setState(() {});
  }

  Future<void> _setWaterReminders(bool on) async {
    if (on && !await NotificationService.requestPermission()) {
      if (mounted) showInfoSnackBar(context, 'Notifications are blocked. You can allow them in your phone settings.');
      return;
    }
    await ReminderSettings.setWaterReminders(on);
    if (mounted) setState(() {});
  }

  Future<void> _setBedtime(bool on) async {
    if (!on) {
      await ReminderSettings.setBedtime(null);
      return setState(() {});
    }
    if (!await NotificationService.requestPermission()) {
      if (mounted) showInfoSnackBar(context, 'Notifications are blocked. You can allow them in your phone settings.');
      return;
    }
    if (!mounted) return;
    final time = await showLiquidTimePicker(context, initialTime: ReminderSettings.bedtime ?? const TimeOfDay(hour: 22, minute: 30), title: 'Bedtime');
    if (time == null) return;
    await ReminderSettings.setBedtime(time);
    if (mounted) setState(() {});
  }

  Future<void> _setWeeklyReview(bool on) async {
    await ReminderSettings.setWeeklyReview(on);
    if (mounted) setState(() {});
  }

  Future<void> _setAppLock(bool on) async {
    final error = await AppLock.setEnabled(on);
    if (!mounted) return;
    setState(() {});
    showInfoSnackBar(context, error ?? (on ? 'App lock is on 🔒' : 'App lock is off'), icon: Icons.lock_rounded);
  }

  Future<void> _setLargerText(bool on) async {
    textScaleNotifier.value = on ? 1.2 : 1.0;
    await Hive.box(HiveService.settingsBox).put('textScale', textScaleNotifier.value);
    if (mounted) setState(() {});
  }

  /// Password for a new backup ('' = no password, null = cancelled).
  Future<String?> _askNewPassword() {
    final p1 = TextEditingController(), p2 = TextEditingController();
    String? error;
    return showLiquidDialog<String>(
      context: context,
      title: 'Protect your backup',
      icon: Icons.lock_rounded,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Backups include your journal, health and medical info. With a password, nobody can read the file without it.',
                style: Theme.of(c).textTheme.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 12),
            TextField(controller: p1, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'Password (at least 6 characters)')),
            const SizedBox(height: 8),
            TextField(controller: p2, obscureText: true, decoration: const InputDecoration(hintText: 'Repeat password')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
            const SizedBox(height: 6),
            Text('There\'s no way to recover a forgotten password.', style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 16),
            LiquidDialogActions(
              cancelLabel: 'No password',
              confirmLabel: 'Protect',
              onCancel: () => Navigator.pop(c, ''),
              onConfirm: () {
                if (p1.text.length < 6) return setD(() => error = 'Use at least 6 characters.');
                if (p1.text != p2.text) return setD(() => error = 'The passwords don\'t match.');
                Navigator.pop(c, p1.text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askBackupPassword() {
    final p = TextEditingController();
    return showLiquidDialog<String>(
      context: context,
      title: 'Backup password',
      icon: Icons.lock_open_rounded,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('This backup is password protected.'),
          const SizedBox(height: 12),
          TextField(controller: p, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'Password')),
          const SizedBox(height: 16),
          LiquidDialogActions(confirmLabel: 'Open', onCancel: () => Navigator.pop(c), onConfirm: () => Navigator.pop(c, p.text)),
        ],
      ),
    );
  }

  Future<void> _backup() async {
    final password = await _askNewPassword();
    if (password == null || !mounted) return;
    if (password.isEmpty) {
      final ok = await showLiquidConfirm(
        context,
        title: 'Save without a password?',
        message: 'Anyone who gets the file could read your journal, health and medical info.',
        confirmLabel: 'Save anyway',
        icon: Icons.warning_amber_rounded,
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      final saved = await BackupService.saveToFile(password: password);
      if (mounted && saved) showInfoSnackBar(context, 'Backup saved. Keep it somewhere safe (e.g. Google Drive).');
    } catch (e) {
      if (mounted) showInfoSnackBar(context, 'Could not save the backup: $e');
    }
  }

  Future<void> _restore() async {
    final ok = await showLiquidConfirm(
      context,
      title: 'Restore a backup?',
      icon: Icons.settings_backup_restore_rounded,
      message: 'This replaces your tasks, habits, goals, journal, challenges and settings with the ones in the backup file.',
      confirmLabel: 'Choose file',
    );
    if (!ok) return;
    try {
      final count = await BackupService.pickAndRestore(askPassword: _askBackupPassword);
      if (count == null || !mounted) return;
      Provider.of<TaskProvider>(context, listen: false).loadTasks();
      Provider.of<HabitProvider>(context, listen: false).loadHabits();
      Provider.of<JournalProvider>(context, listen: false).loadEntries();
      Provider.of<GoalProvider>(context, listen: false).loadGoals();
      Provider.of<ArcProvider>(context, listen: false).loadArcs();
      Provider.of<TaskProvider>(context, listen: false).resyncReminders();
      Provider.of<HabitProvider>(context, listen: false).resyncReminders();
      await ReminderSettings.applyAll();
      await MedicineStore.resync();
      _loadUserData();
      if (mounted) showInfoSnackBar(context, 'Restored $count items from your backup.');
    } on FormatException catch (e) {
      if (mounted) showInfoSnackBar(context, e.message);
    } catch (e) {
      if (mounted) showInfoSnackBar(context, 'Could not restore: $e');
    }
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => _loadUserData());

  Future<void> _sendTestNotification() async {
    if (!await NotificationService.requestPermission()) {
      if (mounted) showInfoSnackBar(context, 'Notifications are blocked. You can allow them in your phone settings.');
      return;
    }
    await NotificationService.showNow(id: 2, title: '👋 Hi $_userName!', body: 'Notifications from Life are working.');
    if (mounted) showInfoSnackBar(context, 'Test notification sent. Check your notification bar.');
  }

  void _showAbout() {
    showLiquidDialog<void>(
      context: context,
      title: 'About Life',
      icon: Icons.info_outline_rounded,
      builder: (c) => Column(
        children: [
          const SizedBox(height: 8),
          const LifeLogo(fontSize: 44),
          const SizedBox(height: 6),
          Text('Version 1.0.0', style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text(
            'Plan tasks, build daily habits, reach long-term goals, track your health and reflect in your journal. Everything stays on your phone.',
            textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          LiquidDialogActions(
            cancelLabel: 'Licences',
            confirmLabel: 'Close',
            onCancel: () {
              Navigator.pop(c);
              showLicensePage(context: context, applicationName: 'Life', applicationVersion: '1.0.0');
            },
            onConfirm: () => Navigator.pop(c),
          ),
        ],
      ),
    );
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
    // This person's reminders shouldn't fire for whoever logs in next.
    await NotificationService.cancelAll();
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
                            _subtitle,
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 16, color: AppColors.violet),
                                const SizedBox(width: 4),
                                Text('$_xpBank XP to spend in the Habits shop', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatTile(icon: Icons.ac_unit_rounded, color: AppColors.sky, value: _freezers, label: 'Streak Freezes'),
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
                              icon: Icons.mic_rounded,
                              color: AppColors.royal,
                              title: 'Life Assistant',
                              subtitle: 'Talk or type: reminders, tasks, notes and more',
                              onTap: () => _open(const AssistantScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.bubble_chart_rounded,
                              color: AppColors.sky,
                              title: 'Floating assistant',
                              subtitle: 'Show Buddy over the app (drag it anywhere)',
                              trailing: Switch(
                                value: BuddySettings.visible,
                                onChanged: (v) async {
                                  await BuddySettings.setVisible(v);
                                  setState(() {});
                                },
                              ),
                              onTap: () async {
                                await BuddySettings.setVisible(!BuddySettings.visible);
                                setState(() {});
                              },
                            ),
                            _SettingRow(
                              icon: Icons.psychology_rounded,
                              color: AppColors.violet,
                              title: 'Assistant memory',
                              subtitle: 'What it has learned about you',
                              onTap: () => _open(const MemoryScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.favorite_rounded,
                              color: AppColors.danger,
                              title: 'Health',
                              subtitle: 'Steps, heart, vitals, body and sleep',
                              onTap: () => _open(const ActivityScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.emergency_rounded,
                              color: AppColors.danger,
                              title: 'Medical ID',
                              subtitle: 'Blood group, allergies and emergency contacts',
                              onTap: () => _open(const MedicalIdScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.medication_rounded,
                              color: AppColors.royal,
                              title: 'Medicines',
                              subtitle: 'Reminders for every dose',
                              onTap: () => _open(const MedicinesScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.spa_rounded,
                              color: AppColors.success,
                              title: 'Breathe',
                              subtitle: 'Guided breathing to calm down',
                              onTap: () => _open(const BreatheScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppColors.warning,
                              title: 'Money',
                              subtitle: 'Spending and monthly budget',
                              onTap: () => _open(const MoneyScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.center_focus_strong_rounded,
                              color: AppColors.royal,
                              title: 'Focus timer',
                              subtitle: 'Work on one task and block distracting apps',
                              onTap: () => _open(const FocusScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.event_note_rounded,
                              color: AppColors.violet,
                              title: 'Weekly review',
                              subtitle: 'Look back at your week and plan the next',
                              onTap: () => _open(const WeeklyReviewScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.insights_rounded,
                              color: AppColors.success,
                              title: 'Insights',
                              subtitle: 'What lifts your mood',
                              onTap: () => _open(const InsightsScreen()),
                            ),
                            _SettingRow(
                              icon: Icons.military_tech_rounded,
                              color: AppColors.warning,
                              title: 'Achievements',
                              subtitle: 'Badges you\'ve earned',
                              onTap: () => _open(const AchievementsScreen()),
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
                            if (AppLock.supported)
                              _SettingRow(
                                icon: Icons.lock_rounded,
                                color: AppColors.navy,
                                title: 'App lock',
                                subtitle: 'Fingerprint, face or phone PIN to open Life. Also hides it in recent apps.',
                                trailing: Switch(value: AppLock.enabled, onChanged: _setAppLock),
                                onTap: () => _setAppLock(!AppLock.enabled),
                              ),
                            _SettingRow(
                              icon: Icons.text_increase_rounded,
                              color: AppColors.accent,
                              title: 'Larger text',
                              subtitle: 'Makes all text in Life 20% bigger',
                              trailing: Switch(value: textScaleNotifier.value > 1.0, onChanged: _setLargerText),
                              onTap: () => _setLargerText(textScaleNotifier.value <= 1.0),
                            ),
                            _SettingRow(
                              icon: Icons.bar_chart_rounded,
                              color: AppColors.royal,
                              title: 'Your Progress',
                              subtitle: 'Stats for tasks, habits, journal and goals',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())),
                            ),
                            _SettingRow(
                              icon: Icons.notifications_active_rounded,
                              color: AppColors.royal,
                              title: 'Daily check-in reminder',
                              subtitle: ReminderSettings.dailyCheckIn == null ? 'Off' : 'Every day at ${ReminderSettings.dailyCheckIn!.format(context)} · tap to change',
                              trailing: Switch(value: ReminderSettings.dailyCheckIn != null, onChanged: _setDailyReminder),
                              onTap: () => _setDailyReminder(true),
                            ),
                            _SettingRow(
                              icon: Icons.water_drop_rounded,
                              color: AppColors.sky,
                              title: 'Water reminders',
                              subtitle: 'Every 2 hours, 10 AM to 8 PM',
                              trailing: Switch(value: ReminderSettings.waterReminders, onChanged: _setWaterReminders),
                              onTap: () => _setWaterReminders(!ReminderSettings.waterReminders),
                            ),
                            _SettingRow(
                              icon: Icons.bedtime_rounded,
                              color: AppColors.navy,
                              title: 'Bedtime reminder',
                              subtitle: ReminderSettings.bedtime == null ? 'Off · helps you sleep 7+ hours' : 'Wind down at ${ReminderSettings.bedtime!.format(context)} · tap to change',
                              trailing: Switch(value: ReminderSettings.bedtime != null, onChanged: _setBedtime),
                              onTap: () => _setBedtime(true),
                            ),
                            _SettingRow(
                              icon: Icons.event_note_rounded,
                              color: AppColors.violet,
                              title: 'Sunday weekly review',
                              subtitle: ReminderSettings.dailyCheckIn == null ? 'Turn on the daily check-in to get this' : 'A reminder every Sunday at 7 PM',
                              trailing: Switch(value: ReminderSettings.weeklyReview, onChanged: _setWeeklyReview),
                              onTap: () => _setWeeklyReview(!ReminderSettings.weeklyReview),
                            ),
                            _SettingRow(
                              icon: Icons.hourglass_bottom_rounded,
                              color: AppColors.danger,
                              title: 'App time limits',
                              subtitle: 'Limit how long you use other apps each day',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppLimitsScreen())),
                            ),
                            _SettingRow(
                              icon: Icons.backup_rounded,
                              color: AppColors.success,
                              title: 'Back up your data',
                              subtitle: 'Save everything to a file',
                              onTap: _backup,
                            ),
                            _SettingRow(
                              icon: Icons.settings_backup_restore_rounded,
                              color: AppColors.warning,
                              title: 'Restore from backup',
                              subtitle: 'Bring your data back on a new phone',
                              onTap: _restore,
                            ),
                            _SettingRow(
                              icon: Icons.send_rounded,
                              color: AppColors.violet,
                              title: 'Send a test notification',
                              subtitle: 'Check that reminders reach your phone',
                              onTap: _sendTestNotification,
                            ),
                            _SettingRow(
                              icon: Icons.info_outline_rounded,
                              color: AppColors.accent,
                              title: 'About Life',
                              subtitle: 'Version 1.0.0',
                              onTap: _showAbout,
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
