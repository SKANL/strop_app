import 'package:flutter/material.dart'
    show
        InputDecoration,
        StatefulBuilder,
        TextField,
        TextEditingController,
        showDialog;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showDialog, TextField;

/// Unified confirmation dialog helper for Strop.
/// Replaces all inline `showDialog(AlertDialog(...))` calls throughout the app.
///
/// Usage:
/// ```dart
/// final confirmed = await StropDialog.confirm(
///   context: context,
///   title: '¿Cerrar Sesión?',
///   body: 'Se perderán los datos sin sincronizar.',
///   confirmLabel: 'Cerrar Sesión',
///   isDestructive: true,
/// );
/// ```
abstract final class StropDialog {
  /// Shows a confirmation dialog.
  /// Returns `true` if the user confirmed, `false` / `null` if cancelled.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String body,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          Button(
            style: const ButtonStyle.ghost(),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          Button(
            style: isDestructive
                ? const ButtonStyle.destructive()
                : const ButtonStyle.primary(),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with a text input field.
  /// Returns the entered text if the user confirmed, or `null` if cancelled.
  static Future<String?> inputConfirm({
    required BuildContext context,
    required String title,
    String? hintText,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            Button(
              style: const ButtonStyle.ghost(),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            Button(
              style: isDestructive
                  ? const ButtonStyle.destructive()
                  : const ButtonStyle.primary(),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    final result = confirmed == true ? controller.text.trim() : null;
    controller.dispose();
    return result;
  }
}
