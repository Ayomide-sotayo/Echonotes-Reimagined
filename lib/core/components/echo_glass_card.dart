import 'package:flutter/material.dart';
import 'package:echonotes/core/theme.dart';

class EchoGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool enableGlow;
  final Color? glowColor;

  const EchoGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.enableGlow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBg =
        backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    final effectiveBorder =
        border ??
        Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        );

    final effectiveShadow =
        boxShadow ??
        (enableGlow
            ? [
              BoxShadow(
                color: (glowColor ?? AppColors.primary).withOpacity(
                  isDark ? 0.22 : 0.08,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ]
            : [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]);

    Widget content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.primary.withOpacity(0.08),
          highlightColor: AppColors.primary.withOpacity(0.04),
          child: content,
        ),
      );
    }

    return content;
  }
}
