import 'package:flutter/material.dart';

class QadamButton extends StatelessWidget {
  const QadamButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = QadamButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final QadamButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    return switch (variant) {
      QadamButtonVariant.primary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      QadamButtonVariant.outline => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      QadamButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
    };
  }
}

enum QadamButtonVariant { primary, outline, text }
