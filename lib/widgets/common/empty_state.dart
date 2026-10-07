import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../liquid/liquid.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
        child: StaggerIn(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Floating(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 14))],
                  ),
                  child: ClipOval(
                    child: LiquidBackground(
                      child: Center(child: Icon(icon, size: 48, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: textTheme.titleLarge?.copyWith(fontSize: 20), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(description, style: textTheme.bodyMedium?.copyWith(height: 1.4), textAlign: TextAlign.center),
              if (buttonText != null && onButtonPressed != null) ...[
                const SizedBox(height: 24),
                GlowButton(label: buttonText!, icon: Icons.add_rounded, expand: false, height: 50, onPressed: onButtonPressed),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
