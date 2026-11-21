import 'package:flutter/material.dart';

/// Compact floating notification card with optional action and tap-to-dismiss.
class FreshKeepToastCard extends StatelessWidget {
  const FreshKeepToastCard({
    super.key,
    required this.message,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E3329),
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDismiss,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            actionLabel != null ? 6 : 12,
            actionLabel != null ? 8 : 16,
            actionLabel != null ? 6 : 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: () {
                    onDismiss();
                    onAction?.call();
                  },
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: Color(0xFFA7E3C0),
                      fontWeight: FontWeight.w600,
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
