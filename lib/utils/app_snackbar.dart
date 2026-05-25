import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return null;
  }

  messenger.hideCurrentSnackBar();

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  controller = messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: Row(
        children: [
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                onAction();
                controller?.close();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    ),
  );

  return controller;
}
