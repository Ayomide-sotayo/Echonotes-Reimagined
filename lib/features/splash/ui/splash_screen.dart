import 'dart:async';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _entryController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _badgeFade;
  late final Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();

    // Concentric acoustic ripples pulsing
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Entry reveal controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _logoFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );

    _bottomFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _entryController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Snappy and performant (~1.1s total delay)
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final targetRoute =
          currentUser != null ? AppRoutes.home : AppRoutes.onBoarding;

      await Navigator.pushReplacementNamed(context, targetRoute);

      if (currentUser != null) {
        final pending = ShareReceiverService().currentPending;
        if (pending != null && !ShareReceiverService().isImportScreenActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!ShareReceiverService().isImportScreenActive) {
              AppRoutes.navigatorKey.currentState?.pushNamed(
                AppRoutes.shareImport,
                arguments: pending,
              );
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onBoarding);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Soft ambient radial aura
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.12),
                  radius: 0.9,
                  colors: [
                    const Color(0xFF6366F1).withOpacity(isDark ? 0.15 : 0.08),
                    bgColor.withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Center: Acoustic Echo Ripples & Large Logo Mark
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Echo Wave Container
                SizedBox(
                  width: 220,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric acoustic ripples
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(220, 180),
                            painter: _EchoAcousticRipplePainter(
                              progress: _pulseController.value,
                              isDark: isDark,
                            ),
                          );
                        },
                      ),

                      // Large prominent Logo Mark
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(0xFF131722)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(isDark ? 0.25 : 0.12),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Image.asset(
                              'assets/logo_mark.png',
                              color: const Color(0xFF6366F1),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 48,
                                  color: Color(0xFF6366F1),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Headline Typography Reveal
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'EchoNotes',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Studio Badge Capsule
                FadeTransition(
                  opacity: _badgeFade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withOpacity(0.12)
                                : const Color(0xFFC7D2FE),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accentEmerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Audio & Thought Studio',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF6366F1),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom SAYF TECH Attribution
          Positioned(
            bottom: 38,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'from',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subtextColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'SAYF TECH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Concentric acoustic ripples pulsing outward to represent echoing audio waves
class _EchoAcousticRipplePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _EchoAcousticRipplePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = const Color(0xFF6366F1);

    // 3 staggered concentric ripple waves
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 64.0 + (waveProgress * 42.0);
      final opacity = (1.0 - waveProgress) * (isDark ? 0.35 : 0.22);

      final paint =
          Paint()
            ..color = baseColor.withOpacity(opacity.clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 - (waveProgress * 0.8);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EchoAcousticRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
