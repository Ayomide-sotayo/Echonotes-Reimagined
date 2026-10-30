import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToSignUp() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AppRoutes.signup);
  }

  void _navigateToSignIn() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar: Branding & Studio Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? const Color(0xFF131722)
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? AppColors.darkBorder
                                                  : const Color(0xFFE2E8F0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF6366F1,
                                            ).withOpacity(isDark ? 0.2 : 0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(7),
                                      child: Image.asset(
                                        'assets/logo_mark.png',
                                        color: const Color(0xFF6366F1),
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.graphic_eq,
                                                  color: Color(0xFF6366F1),
                                                  size: 20,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'EchoNotes',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isDark
                                                ? AppColors.darkTextPrimary
                                                : const Color(0xFF0F172A),
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(
                                              0xFF6366F1,
                                            ).withOpacity(0.18)
                                            : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? const Color(
                                                0xFF6366F1,
                                              ).withOpacity(0.3)
                                              : const Color(0xFFC7D2FE),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '✨',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hybrid Studio',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            ValueListenableBuilder<SharedAudioPayload?>(
                              valueListenable:
                                  ShareReceiverService().pendingAudioNotifier,
                              builder: (context, pending, _) {
                                if (pending == null) {
                                  return const SizedBox(height: 20);
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withOpacity(0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.graphic_eq_rounded,
                                          color: Color(0xFF6366F1),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Incoming audio waiting: "${pending.name}". Sign in to import.',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Hero Visual: Photo of someone speaking voice notes into the app
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                constraints: const BoxConstraints(
                                  minHeight: 260,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDark ? 0.4 : 0.08,
                                      ),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(27),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        'assets/onboarding_hero.jpg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: const Color(0xFFEEF2FF),
                                            child: const Center(
                                              child: Icon(
                                                Icons.mic_rounded,
                                                size: 64,
                                                color: Color(0xFF6366F1),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      // Subtle gradient scrim at the bottom
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        height: 70,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Floating bottom pill tag on hero
                                      Positioned(
                                        bottom: 14,
                                        left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.55,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.graphic_eq_rounded,
                                                size: 13,
                                                color: Color(0xFFA5B4FC),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Real-time Audio & AI Summary',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Value Proposition Typography
                            Text(
                              'Capture thoughts.\nLet AI do the heavy lifting.',
                              style: GoogleFonts.outfit(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color:
                                    isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Record, write, transcribe and summarize your notes in seconds with intelligent clarity.',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                height: 1.4,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Feature highlights pill chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFeatureChip(
                                  label: 'Voice Recording',
                                  icon: '🎙️',
                                  isDark: isDark,
                                ),
                                _buildFeatureChip(
                                  label: 'Instant Transcripts',
                                  icon: '⚡',
                                  isDark: isDark,
                                ),
                                _buildFeatureChip(
                                  label: 'Cloud Synced',
                                  icon: '🔒',
                                  isDark: isDark,
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            // Primary CTA: Create Free Account
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withOpacity(0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _navigateToSignUp,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Create Free Account',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Secondary CTA: Sign In
                            Center(
                              child: TextButton(
                                onPressed: _navigateToSignIn,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Already have an account? ',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color:
                                          isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF64748B),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sign In',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip({
    required String label,
    required String icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
