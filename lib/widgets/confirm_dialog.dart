import 'package:flutter/material.dart';

/// A yes/no question. True = confirmed, false/null = cancelled.
Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancel = 'Batal',
  bool destructive = false,
}) => showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: Text(cancel),
      ),
      FilledButton(
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              )
            : null,
        onPressed: () => Navigator.pop(ctx, true),
        child: Text(action),
      ),
    ],
  ),
);
