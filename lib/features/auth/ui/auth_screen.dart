import 'dart:math' as math;

import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late bool _isSignUp;

  // Form Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _resetEmailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // State flags
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  double _passwordStrength = 0.0;

  // --- Animation Controllers ---
  late AnimationController _entranceController;
  late AnimationController _switchController;
  late AnimationController _ambientController;

  // Entrance animations
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _initAnimations();
    _loadRememberedPreferences();
  }

  Future<void> _loadRememberedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('auth_remember_me') ?? true;
      final savedEmail = prefs.getString('auth_saved_email') ?? '';
      if (mounted) {
        setState(() {
          _rememberMe = remember;
          if (remember && savedEmail.isNotEmpty) {
            _emailController.text = savedEmail;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading remembered preferences: $e');
    }
  }

  Future<void> _persistRememberMe(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_remember_me', _rememberMe);
      if (_rememberMe && email.isNotEmpty) {
        await prefs.setString('auth_saved_email', email);
      } else {
        await prefs.remove('auth_saved_email');
      }
    } catch (e) {
      debugPrint('Error saving remember me: $e');
    }
  }

  void _openLegalTerms({int initialTab = 0}) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      AppRoutes.legalTermsPrivacy,
      arguments: initialTab,
    );
  }

  void _initAnimations() {
    // 1. Entrance Stagger Controller
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
      ),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.95, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Switch Controller for toggling Sign In / Sign Up smoothly
    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // 3. Subtle ambient glow controller in the purple header
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _resetEmailController.dispose();
    _entranceController.dispose();
    _switchController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _toggleAuthMode(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    HapticFeedback.selectionClick();

    _switchController.forward().then((_) {
      setState(() {
        _isSignUp = isSignUp;
        _formKey.currentState?.reset();
        _passwordStrength = 0.0;
      });
      _switchController.reverse();
    });
  }

  // --- Password Strength Calculation ---
  void _calculatePasswordStrength(String password) {
    double strength = 0.0;
    if (password.length >= 8) strength += 0.34;
    if (password.contains(RegExp(r'[A-Z]')) ||
        password.contains(RegExp(r'[0-9]'))) {
      strength += 0.33;
    }
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      strength += 0.33;
    }

    setState(() {
      _passwordStrength = strength;
    });
  }

  Color _getPasswordStrengthColor() {
    if (_passwordStrength == 0.0) return const Color(0xFFD1D5DB);
    if (_passwordStrength <= 0.34) return const Color(0xFFEF4444);
    if (_passwordStrength <= 0.67) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _getPasswordStrengthLabel() {
    if (_passwordStrength == 0.0) return '';
    if (_passwordStrength <= 0.34) return 'Weak';
    if (_passwordStrength <= 0.67) return 'Fair';
    return 'Strong';
  }

  // --- Form Validation ---
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isSignUp) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name is too short';
    }
    return null;
  }

  // --- Authentication Actions ---
  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

        await _persistRememberMe(_emailController.text.trim());

        if (mounted) {
          _showFeedbackSnackBar('Account created successfully! Welcome.');
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        }
      } else {
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );

        await _persistRememberMe(_emailController.text.trim());

        if (mounted) {
          _showFeedbackSnackBar('Welcome back!');
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _isGoogleLoading = true);

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        final email = userCredential.user?.email ?? '';
        await _persistRememberMe(email);
        if (mounted) {
          _showFeedbackSnackBar(
            'Signed in as ${userCredential.user?.displayName ?? "User"}',
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(
          'Google Sign-In failed: ${e.toString().replaceAll("Exception: ", "")}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _showForgotPasswordSheet() {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSending = false;

    if (_emailController.text.trim().isNotEmpty) {
      _resetEmailController.text = _emailController.text.trim();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your registered email to receive a password reset link.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStackedField(
                  controller: _resetEmailController,
                  label: 'Email Address',
                  hint: 'name@example.com',
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                _BouncingButton(
                  onPressed:
                      isSending
                          ? null
                          : () async {
                            final email = _resetEmailController.text.trim();
                            if (email.isEmpty) {
                              _showFeedbackSnackBar(
                                'Please enter your email',
                                isError: true,
                              );
                              return;
                            }
                            setSheetState(() => isSending = true);
                            try {
                              await _authService.resetPassword(email);
                              if (context.mounted) {
                                Navigator.pop(context);
                                _showFeedbackSnackBar(
                                  'Password reset link sent to $email',
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSending = false);
                              _showFeedbackSnackBar(
                                'Error sending reset email: $e',
                                isError: true,
                              );
                            }
                          },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child:
                        isSending
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              'Send Reset Link',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF7C3AED),
      body: Stack(
        children: [
          // Ambient Gradient Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 480,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9333EA),
                    Color(0xFF7C3AED),
                    Color(0xFF6D28D9),
                  ],
                ),
              ),
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _HeaderOrbsPainter(
                      progress: _ambientController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. Expanded Top Header with animated bubbles & breathing space
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Row: Back chevron & Capsule Switcher with translucent background
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Back button
                              _BouncingButton(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.onBoarding,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.22),
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              // Right: Capsule switcher with translucent white shade background
                              Container(
                                padding: const EdgeInsets.only(
                                  left: 14,
                                  right: 4,
                                  top: 4,
                                  bottom: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.22),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSignUp
                                          ? 'Already have an account?'
                                          : "Don't have an account?",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _BouncingButton(
                                      onTap: () => _toggleAuthMode(!_isSignUp),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.12),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _isSignUp ? 'Sign In' : 'Sign Up',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                        ),
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
                                return const SizedBox(height: 72);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 20,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.graphic_eq_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Import ready: "${pending.name}"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Centered App Identity (Jobsly position)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/logo_mark.png',
                                color: Colors.white,
                                height: 34,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Icon(
                                          Icons.graphic_eq_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'EchoNotes',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 38),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Large White Card Container filling the rest of the screen
                Expanded(
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          child: FadeTransition(
                            opacity: _contentFade,
                            child: SlideTransition(
                              position: _contentSlide,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 24.0,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Centered Titles matching reference
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        child: Column(
                                          key: ValueKey<bool>(_isSignUp),
                                          children: [
                                            Text(
                                              _isSignUp
                                                  ? 'Get started free.'
                                                  : 'Welcome back.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    isDark
                                                        ? AppColors
                                                            .darkTextPrimary
                                                        : const Color(
                                                          0xFF0F172A,
                                                        ),
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _isSignUp
                                                  ? 'Free forever. No credit card needed.'
                                                  : 'Sign in to access your notes & transcripts.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                color:
                                                    isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : const Color(
                                                          0xFF64748B,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 22),

                                      // 1. Email Address (2-tier stacked field)
                                      _buildStackedField(
                                        controller: _emailController,
                                        label: 'Email Address',
                                        hint: 'nicholas@ergemla.com',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        isDark: isDark,
                                        validator: _validateEmail,
                                      ),

                                      // 2. Name Field (Sign Up only, smoothly animated)
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 250),
                                        crossFadeState:
                                            _isSignUp
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Padding(
                                          padding: const EdgeInsets.only(top: 14),
                                          child: _buildStackedField(
                                            controller: _nameController,
                                            label: 'Your name',
                                            hint: 'Nicholas Ergemla',
                                            isDark: isDark,
                                            validator: _validateName,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // 3. Password Field with Dash Strength & Eye Toggle
                                      _buildPasswordField(isDark: isDark),

                                      // Sign In extras: Remember Me + Forgot Password
                                      if (!_isSignUp) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: Checkbox(
                                                    value: _rememberMe,
                                                    onChanged: (val) {
                                                      setState(
                                                        () =>
                                                            _rememberMe =
                                                                val ?? false,
                                                      );
                                                    },
                                                    activeColor: const Color(
                                                      0xFF7C3AED,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.selectionClick();
                                                    setState(() => _rememberMe = !_rememberMe);
                                                  },
                                                  child: Text(
                                                    'Remember me',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color:
                                                          isDark
                                                              ? AppColors
                                                                  .darkTextSecondary
                                                              : const Color(
                                                                0xFF64748B,
                                                              ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            GestureDetector(
                                              onTap: _showForgotPasswordSheet,
                                              child: Text(
                                                'Forgot Password?',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                        0xFF7C3AED,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      const SizedBox(height: 22),

                                      // 4. Primary CTA Button with interactive bounce
                                      _BouncingButton(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : _submitEmailAuth,
                                        child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF7C3AED,
                                                ).withOpacity(0.28),
                                                blurRadius: 14,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child:
                                              _isLoading
                                                  ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                  : Text(
                                                    _isSignUp
                                                        ? 'Sign up'
                                                        : 'Sign in',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // 5. Divider "Or sign up with" / "Or sign in with"
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                              color:
                                                  isDark
                                                      ? AppColors.darkBorder
                                                      : const Color(0xFFE2E8F0),
                                              thickness: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14.0,
                                                ),
                                            child: Text(
                                              _isSignUp
                                                  ? 'Or sign up with'
                                                  : 'Or sign in with',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color:
                                                    isDark
                                                        ? const Color(0xFF64748B)
                                                        : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Divider(
                                              color:
                                                  isDark
                                                      ? AppColors.darkBorder
                                                      : const Color(0xFFE2E8F0),
                                              thickness: 1,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // 6. Google Sign-In Button ONLY (Full Width with authentic Google G logo)
                                      _BouncingButton(
                                        onPressed:
                                            _isGoogleLoading
                                                ? null
                                                : _handleGoogleSignIn,
                                        child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(0xFF131722)
                                                    : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                                                  0.03,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child:
                                              _isGoogleLoading
                                                  ? const Center(
                                                    child: SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            color: Color(
                                                              0xFF7C3AED,
                                                            ),
                                                          ),
                                                    ),
                                                  )
                                                  : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Image.asset(
                                                        'assets/google_logo.png',
                                                        width: 22,
                                                        height: 22,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => const Icon(
                                                              Icons.g_mobiledata,
                                                              size: 26,
                                                              color: Color(
                                                                0xFF4285F4,
                                                              ),
                                                            ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        _isSignUp
                                                            ? 'Sign up with Google'
                                                            : 'Sign in with Google',
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  isDark
                                                                      ? Colors
                                                                          .white
                                                                      : const Color(
                                                                        0xFF1E293B,
                                                                      ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // 7. Footer / Interactive Terms & Privacy
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              _isSignUp
                                                  ? 'By creating an account, you agree to our '
                                                  : 'By signing in, you agree to our ',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? const Color(0xFF64748B)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _openLegalTerms(initialTab: 0),
                                              behavior: HitTestBehavior.opaque,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                                child: Text(
                                                  'Terms',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF7C3AED),
                                                    decoration: TextDecoration.underline,
                                                    decorationColor:
                                                        const Color(0xFF7C3AED).withOpacity(0.4),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              ' & ',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: isDark
                                                    ? const Color(0xFF64748B)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _openLegalTerms(initialTab: 1),
                                              behavior: HitTestBehavior.opaque,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                                child: Text(
                                                  'Privacy Policy',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF7C3AED),
                                                    decoration: TextDecoration.underline,
                                                    decorationColor:
                                                        const Color(0xFF7C3AED).withOpacity(0.4),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Stacked 2-tier Field Builder (matching Jobly reference) ---
  Widget _buildStackedField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 18, right: 18, top: 11, bottom: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Password Field with Dash Strength Indicator on the Top Right ---
  Widget _buildPasswordField({required bool isDark}) {
    final strengthColor = _getPasswordStrengthColor();
    final strengthLabel = _getPasswordStrengthLabel();

    return Container(
      padding: const EdgeInsets.only(left: 18, right: 14, top: 11, bottom: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131722) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 0.1,
                ),
              ),

              // Dash Strength Indicator (matching Jobly: "--- Strong")
              if (_isSignUp) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStrengthDash(
                      isActive: _passwordStrength >= 0.25,
                      color: strengthColor,
                    ),
                    const SizedBox(width: 3),
                    _buildStrengthDash(
                      isActive: _passwordStrength >= 0.50,
                      color: strengthColor,
                    ),
                    const SizedBox(width: 3),
                    _buildStrengthDash(
                      isActive: _passwordStrength >= 0.75,
                      color: strengthColor,
                    ),
                    if (strengthLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        strengthLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: strengthColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  onChanged: _isSignUp ? _calculatePasswordStrength : null,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF9CA3AF),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    errorStyle: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color:
                        isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthDash({required bool isActive, required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 14,
      height: 3.5,
      decoration: BoxDecoration(
        color: isActive ? color : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// --- Interactive Bouncing Button for tactile micro-interactions ---
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;

  const _BouncingButton({
    required this.child,
    this.onTap,
    this.onPressed,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null || widget.onPressed != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onPressed != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callback = widget.onTap ?? widget.onPressed;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: callback,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// --- Floating Ambient Header Orbs Painter ---
class _HeaderOrbsPainter extends CustomPainter {
  final double progress;

  _HeaderOrbsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 =
        Paint()
          ..color = Colors.white.withOpacity(0.06 + 0.03 * math.sin(progress * math.pi * 2))
          ..style = PaintingStyle.fill;

    final paint2 =
        Paint()
          ..color = const Color(0xFFC084FC).withOpacity(0.13 + 0.04 * math.cos(progress * math.pi * 2))
          ..style = PaintingStyle.fill;

    final paint3 =
        Paint()
          ..color = Colors.white.withOpacity(0.04 + 0.02 * math.sin((progress + 0.5) * math.pi * 2))
          ..style = PaintingStyle.fill;

    // Orb 1: large glow top right
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      85 + 10 * math.sin(progress * math.pi),
      paint1,
    );

    // Orb 2: medium purple orb mid-bottom left
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.65),
      65 + 8 * math.cos(progress * math.pi),
      paint2,
    );

    // Orb 3: small accent bubble floating bottom right
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.75),
      44 + 6 * math.sin(progress * math.pi),
      paint3,
    );

    // Orb 4: soft accent bubble floating upper mid-left
    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.26),
      34 + 5 * math.cos(progress * math.pi),
      paint1,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderOrbsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
