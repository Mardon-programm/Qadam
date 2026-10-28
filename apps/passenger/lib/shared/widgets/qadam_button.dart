import 'package:flutter/material.dart';

import 'qadam_ui.dart';

/// Backwards-compatible wrapper around [QadamActionButton].
///
/// Kept so existing screens can keep using the short `QadamButton` API while
/// the whole app shares one branded button.
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
    final style = switch (variant) {
      QadamButtonVariant.primary => QadamButtonStyle.primary,
      QadamButtonVariant.outline => QadamButtonStyle.ghost,
      QadamButtonVariant.text => QadamButtonStyle.link,
    };
    return QadamActionButton(
      label: label,
      onTap: onPressed,
      loading: isLoading,
      icon: icon,
      style: style,
      height: variant == QadamButtonVariant.text ? 44 : 56,
    );
  }
}

enum QadamButtonVariant { primary, outline, text }
