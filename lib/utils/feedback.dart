import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Builds the app's floating toast: a liquid gradient pill with an icon.
SnackBar _toast(String message, {IconData icon = Icons.auto_awesome_rounded, String? actionLabel, VoidCallback? onAction, Duration duration = const Duration(seconds: 4)}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    duration: duration,
    content: Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [AppColors.navy, AppColors.royal, AppColors.violet], begin: Alignment.centerLeft, end: Alignment.centerRight),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.35)),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onAction?.call();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.pink, textStyle: const TextStyle(fontWeight: FontWeight.w900)),
                child: Text(actionLabel),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

/// Shows a short confirmation with an "Undo" action, so deleting
/// never needs an "are you sure?" dialog.
void showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_toast(message, icon: Icons.delete_outline_rounded, actionLabel: 'Undo', onAction: onUndo));
}

void showInfoSnackBar(BuildContext context, String message, {IconData icon = Icons.auto_awesome_rounded}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_toast(message, icon: icon));
}
