import 'package:flutter/material.dart';

/// Shows a short confirmation with an "Undo" action, so deleting
/// never needs an "are you sure?" dialog.
void showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'Undo', textColor: const Color(0xFFEFA3D7), onPressed: onUndo),
    ),
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
