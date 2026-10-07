import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 80, height: 80, decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]), shape: BoxShape.circle), child: const Center(child: Text('N', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)))),
            const SizedBox(height: 16),
            const Text('Numan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Achievements, dark mode, backup coming next', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}