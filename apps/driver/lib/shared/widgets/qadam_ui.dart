import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared visual building blocks for the Qadam apps.
///
/// Keeping the brand shapes in one place means the passenger and driver
/// builds stay visually identical where they should be.

// ── Ornament ────────────────────────────────────────────────────────────────

/// A restrained Kyrgyz-inspired ornament: a sun with rays and a band of
/// interlocking ram horns. Drawn at low opacity so it reads as texture.
class QadamOrnament extends StatelessWidget {
  const QadamOrnament({
    super.key,
    this.opacity = 0.12,
    this.color = Colors.white,
    this.showSun = true,
    this.showBand = true,
  });

  final double opacity;
  final Color color;
  final bool showSun;
  final bool showBand;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OrnamentPainter(
          opacity: opacity,
          color: color,
          showSun: showSun,
          showBand: showBand,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter({
    required this.opacity,
    required this.color,
    required this.showSun,
    required this.showBand,
  });

  final double opacity;
  final Color color;
  final bool showSun;
  final bool showBand;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (showSun) {
      final center = Offset(size.width * 0.84, size.height * 0.2);
      final radius = math.min(size.width, size.height) * 0.13;
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(
        center,
        radius * 0.62,
        Paint()..color = color.withOpacity(opacity * 0.7),
      );
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        final from = center +
            Offset(math.cos(angle), math.sin(angle)) * (radius * 1.22);
        final to = center +
            Offset(math.cos(angle), math.sin(angle)) * (radius * 1.55);
        canvas.drawLine(from, to, paint);
      }
    }

    if (showBand) {
      final baseY = size.height * 0.88;
      const step = 54.0;
      final radius = step / 2 - 4;
      for (double x = -step; x < size.width + step; x += step) {
        final cx = x + step / 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, baseY - 8), radius: radius),
          math.pi,
          math.pi,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, baseY + 8), radius: radius),
          0,
          math.pi,
          false,
          paint,
        );
        canvas.drawCircle(
          Offset(cx, baseY),
          2.4,
          Paint()..color = color.withOpacity(opacity * 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrnamentPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color ||
      oldDelegate.showSun != showSun ||
      oldDelegate.showBand != showBand;
}

// ── Wordmark ────────────────────────────────────────────────────────────────

class QadamWordmark extends StatelessWidget {
  const QadamWordmark({
    super.key,
    this.onDark = false,
    this.size = 24,
    this.subtitle,
  });

  final bool onDark;
  final double size;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppTheme.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.35,
          height: size * 1.35,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.45),
            boxShadow: AppTheme.softShadow,
          ),
          child: Center(
            child: Icon(
              Icons.near_me_rounded,
              color: Colors.white,
              size: size * 0.75,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QADAM',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: size,
                height: 1,
                letterSpacing: 2.2,
                color: textColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.42,
                  letterSpacing: 1.2,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// Gradient header used on auth and onboarding screens.
class QadamBrandHeader extends StatelessWidget {
  const QadamBrandHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.trailing,
    this.height,
    this.bottomRadius = 32,
    this.child,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;
  final double? height;
  final double bottomRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        boxShadow: AppTheme.floatShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: QadamOrnament()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          _CircleIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        if (showBack) const SizedBox(width: 12),
                        if (!showBack) const QadamWordmark(onDark: true),
                        const Spacer(),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    if (title != null || subtitle != null)
                      const SizedBox(height: 28),
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 20),
                      child!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

class QadamCard extends StatelessWidget {
  const QadamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppTheme.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppTheme.divider),
      boxShadow: AppTheme.softShadow,
    );

    if (onTap == null) {
      return Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }

    return Container(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Gradient card — used for wallet balance and hero stats.
class QadamGradientCard extends StatelessWidget {
  const QadamGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.gradient,
    this.radius = 28,
    this.ornament = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double radius;
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppTheme.floatShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (ornament)
              const Positioned.fill(
                child: QadamOrnament(opacity: 0.16, showBand: false),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────────

enum QadamButtonStyle { primary, soft, ghost, light, danger, link }

class QadamActionButton extends StatelessWidget {
  const QadamActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.style = QadamButtonStyle.primary,
    this.height = 56,
    this.expand = true,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final QadamButtonStyle style;
  final double height;
  final bool expand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;

    late final Color foreground;
    late final Color background;
    Gradient? gradient;
    List<BoxShadow> shadow = const [];
    Border? border;

    switch (style) {
      case QadamButtonStyle.primary:
        foreground = Colors.white;
        background = Colors.transparent;
        gradient = AppTheme.brandGradient;
        shadow = const [
          BoxShadow(
            color: Color(0x4D2F5BFF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ];
        break;
      case QadamButtonStyle.soft:
        foreground = AppTheme.primary;
        background = AppTheme.lavender;
        break;
      case QadamButtonStyle.ghost:
        foreground = AppTheme.textSecondary;
        background = Colors.transparent;
        border = Border.all(color: AppTheme.divider, width: 1.5);
        break;
      case QadamButtonStyle.light:
        foreground = AppTheme.primary;
        background = Colors.white;
        shadow = AppTheme.softShadow;
        break;
      case QadamButtonStyle.danger:
        foreground = AppTheme.error;
        background = const Color(0xFFFEF3F2);
        break;
      case QadamButtonStyle.link:
        foreground = AppTheme.primary;
        background = Colors.transparent;
        break;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        decoration: BoxDecoration(
          color: gradient == null ? background : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(height / 2),
          border: border,
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expand ? 20 : 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      ),
                    )
                  else if (icon != null) ...[
                    Icon(icon, color: foreground, size: 20),
                    const SizedBox(width: 10),
                  ],
                  if (!loading)
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

class QadamSectionLabel extends StatelessWidget {
  const QadamSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class QadamTag extends StatelessWidget {
  const QadamTag({
    super.key,
    required this.label,
    this.color = AppTheme.primary,
    this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class QadamIconBadge extends StatelessWidget {
  const QadamIconBadge({
    super.key,
    required this.icon,
    this.color = AppTheme.primary,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class QadamStat extends StatelessWidget {
  const QadamStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppTheme.textPrimary,
    this.align = CrossAxisAlignment.start,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color.withOpacity(0.55)),
          const SizedBox(height: 8),
        ],
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class QadamAvatar extends StatelessWidget {
  const QadamAvatar({super.key, this.name, this.size = 52, this.icon});

  final String? name;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final initial = trimmed.isEmpty ? null : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Icon(icon ?? Icons.person_rounded,
                color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

/// Bottom sheet shell with a grabber and rounded top corners.
class QadamSheet extends StatelessWidget {
  const QadamSheet({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x260B1226),
            blurRadius: 40,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

/// Label + value row used in detail lists.
class QadamInfoRow extends StatelessWidget {
  const QadamInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple two-step progress indicator used on the active ride screen.
class QadamStepBar extends StatelessWidget {
  const QadamStepBar({
    super.key,
    required this.step,
    this.total = 3,
    this.bright = false,
  });

  final int step;
  final int total;

  /// Use on top of a brand gradient: active segments turn white.
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index < step;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              gradient:
                  active && !bright ? AppTheme.brandGradient : null,
              color: bright
                  ? (active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28))
                  : (active ? null : AppTheme.divider),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        );
      }),
    );
  }
}
