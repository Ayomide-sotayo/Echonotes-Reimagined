import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:echonotes/core/theme.dart';

class EchoPillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final Color? color;
  final bool isFilled;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const EchoPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.color,
    this.isFilled = false,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  factory EchoPillBadge.audio({bool isDark = false}) {
    return EchoPillBadge(
      label: 'Audio',
      icon: Icons.mic_rounded,
      color: AppColors.primary,
    );
  }

  factory EchoPillBadge.text({bool isDark = false}) {
    return const EchoPillBadge(
      label: 'Text',
      icon: Icons.edit_note_rounded,
      color: AppColors.accentCyan,
    );
  }

  factory EchoPillBadge.sentiment(String? sentiment) {
    if (sentiment == null || sentiment.isEmpty) {
      return const EchoPillBadge(
        label: 'Neutral',
        emoji: '😐',
        color: AppColors.accentAmber,
      );
    }
    final s = sentiment.toLowerCase();
    if (s.contains('pos')) {
      return const EchoPillBadge(
        label: 'Positive',
        emoji: '😊',
        color: AppColors.accentEmerald,
      );
    } else if (s.contains('neg')) {
      return const EchoPillBadge(
        label: 'Negative',
        emoji: '😔',
        color: AppColors.accentCoral,
      );
    }
    return const EchoPillBadge(
      label: 'Neutral',
      emoji: '😐',
      color: AppColors.accentAmber,
    );
  }

  factory EchoPillBadge.aiSummary() {
    return const EchoPillBadge(
      label: 'AI Summary',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            isFilled
                ? effectiveColor.withOpacity(isDark ? 0.25 : 0.12)
                : effectiveColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveColor.withOpacity(isDark ? 0.35 : 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: TextStyle(fontSize: fontSize + 1)),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isDark ? effectiveColor.withOpacity(0.95) : effectiveColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
