import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/hive_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/liquid/liquid.dart';
import '../../providers/task_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  void _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    await HiveService.setCurrentUser(name);
    final box = Hive.box(HiveService.settingsBox);
    await box.put('userName', name);
    await box.put('isLoggedIn', true);

    if (mounted) {
      // Reload providers for the newly logged-in user
      Provider.of<TaskProvider>(context, listen: false).loadTasks();
      Provider.of<HabitProvider>(context, listen: false).loadHabits();
      Provider.of<JournalProvider>(context, listen: false).loadEntries();

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
                          Floating(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                              ),
                              child: const Icon(Icons.bolt_rounded, size: 52, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: child),
                            ),
                            child: Text(
                              _isSignUp ? 'Create Local Account' : 'Welcome Back',
                              key: ValueKey(_isSignUp),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Access your personalized Life Dashboard',
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
                        Text('PIN / Passcode (Optional)', style: textTheme.titleMedium?.copyWith(fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: '••••', prefixIcon: Icon(Icons.lock_rounded)),
                        ),
                        const SizedBox(height: 26),
                        GlowButton(label: _isSignUp ? 'Sign Up' : 'Log In', onPressed: _submit),
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
