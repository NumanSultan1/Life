import '../medicines_screen.dart';
import '../../utils/feedback.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/hive_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/liquid/liquid.dart';
import '../../widgets/life_logo.dart';
import '../../providers/task_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/arc_provider.dart';
import '../../services/reminder_settings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  // Start on "create profile" when nobody has signed up on this device yet.
  bool _isSignUp = !Hive.box(HiveService.settingsBox).keys.any((k) => k.toString().endsWith('_level'));

  void _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showInfoSnackBar(context, 'Please enter your name', icon: Icons.person_outline_rounded);
      return;
    }

    await HiveService.setCurrentUser(name);
    final box = Hive.box(HiveService.settingsBox);
    await box.put('isLoggedIn', true);

    if (mounted) {
      // Reload providers for the newly logged-in user
      Provider.of<TaskProvider>(context, listen: false).loadTasks();
      Provider.of<HabitProvider>(context, listen: false).loadHabits();
      Provider.of<JournalProvider>(context, listen: false).loadEntries();
      Provider.of<GoalProvider>(context, listen: false).loadGoals();
      Provider.of<ArcProvider>(context, listen: false).loadArcs();
      // Bring back this person's reminders.
      Provider.of<TaskProvider>(context, listen: false).resyncReminders();
      Provider.of<HabitProvider>(context, listen: false).resyncReminders();
      ReminderSettings.applyAll();
      MedicineStore.resync();

      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: AmbientBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedWaveClip(
                edge: WaveEdge.bottom,
                depth: 30,
                ripple: 4,
                child: LiquidBackground(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 70),
                      child: Column(
                        children: [
                          const Floating(distance: 6, child: LifeLogoBadge(fontSize: 40)),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: child),
                            ),
                            child: Text(
                              _isSignUp ? 'Create your profile' : 'Welcome Back',
                              key: ValueKey(_isSignUp),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isSignUp ? 'Just pick a name. No email or password needed.' : 'Enter the name you signed up with',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: StaggerIn(
                  child: GlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Name / Username', style: textTheme.titleMedium?.copyWith(fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: 'e.g. Alex', prefixIcon: Icon(Icons.person_rounded)),
                        ),
                        const SizedBox(height: 16),
                        Text('PIN (optional)', style: textTheme.titleMedium?.copyWith(fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: '••••', prefixIcon: Icon(Icons.lock_rounded)),
                        ),
                        const SizedBox(height: 26),
                        GlowButton(label: _isSignUp ? 'Create my profile' : 'Log In', onPressed: _submit),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 15, color: textTheme.bodyMedium?.color),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Your data stays on this phone. Nothing is uploaded.', style: textTheme.bodyMedium?.copyWith(fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() => _isSignUp = !_isSignUp);
                            },
                            child: Text(
                              _isSignUp ? 'Already have a local profile? Log In' : 'New user? Create your profile',
                              style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
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
