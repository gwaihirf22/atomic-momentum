import 'package:flutter/material.dart';
import 'adaptive.dart';

/// Asks whether to throw away unsaved edits. Returns true to discard.
Future<bool> confirmDiscardChanges(BuildContext context) {
  return confirmAdaptive(
    context,
    title: 'Discard changes?',
    message: 'Your unsaved changes will be lost.',
    confirmLabel: 'Discard',
    cancelLabel: 'Keep Editing',
    destructive: true,
    confirmKey: const Key('discardChanges'),
    cancelKey: const Key('keepEditing'),
  );
}

/// While [hasChanges], leaving the route (back button, back gesture, tapping
/// outside a sheet) first asks whether to discard them. Saving should leave
/// with Navigator.pop, which isn't intercepted.
class UnsavedChangesGuard extends StatelessWidget {
  final bool hasChanges;
  final Widget child;

  const UnsavedChangesGuard({Key? key, required this.hasChanges, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}
