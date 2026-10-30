import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:echonotes/services/settings_service.dart';

/// Reusable Studio avatar component with purple gradient ring,
/// network/local file support, offline fallback, and optional edit badge.
class EchoUserAvatar extends StatelessWidget {
  final double size;
  final String? customUrl;
  final String initials;
  final bool showBorder;
  final bool showEditBadge;
  final VoidCallback? onTap;
  final double borderPadding;

  const EchoUserAvatar({
    super.key,
    this.size = 42,
    this.customUrl,
    this.initials = 'U',
    this.showBorder = true,
    this.showEditBadge = false,
    this.onTap,
    this.borderPadding = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService().avatarUrlNotifier,
      builder: (context, activeAvatarUrl, _) {
        final effectiveUrl = customUrl ?? activeAvatarUrl;

        Widget avatarContent = _buildImage(effectiveUrl);

        if (showBorder) {
          avatarContent = Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(borderPadding),
            child: ClipOval(child: avatarContent),
          );
        } else {
          avatarContent = Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: ClipOval(child: avatarContent),
          );
        }

        Widget fullWidget = avatarContent;

        if (showEditBadge) {
          final badgeSize = (size * 0.32).clamp(20.0, 26.0);
          fullWidget = Stack(
            clipBehavior: Clip.none,
            children: [
              avatarContent,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: badgeSize * 0.52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: fullWidget,
          );
        }

        return fullWidget;
      },
    );
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return _buildFallbackInitials();
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackInitials();
        },
      );
    }

    // Local file path
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackInitials();
        },
      );
    }

    return _buildFallbackInitials();
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.48,
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  Widget _buildFallbackInitials() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
