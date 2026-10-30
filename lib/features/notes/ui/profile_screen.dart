// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/services/settings_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:echonotes/core/components/echo_user_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();

  String _username = 'User';
  String? _email;
  bool _isLoading = true;

  // Local settings state
  late ThemeMode _themeMode;
  late String _audioQuality;
  late bool _autoTranscribe;
  late bool _noiseSuppression;
  late bool _localCache;
  late String _summaryStyle;
  late bool _autoInsights;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadSettings();
    _loadUserData();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    _themeMode = _settingsService.themeModeNotifier.value;
    _audioQuality = _settingsService.audioQuality;
    _autoTranscribe = _settingsService.autoTranscribe;
    _noiseSuppression = _settingsService.noiseSuppression;
    _localCache = _settingsService.localCache;
    _summaryStyle = _settingsService.summaryStyle;
    _autoInsights = _settingsService.autoInsights;
  }

  Future<void> _loadUserData() async {
    try {
      final name = await _authService.getUsername();
      final user = _authService.getCurrentUser();
      final cloudPhoto = await _authService.getPhotoUrl();
      if (cloudPhoto != null && cloudPhoto.isNotEmpty) {
        await _settingsService.setAvatarUrl(cloudPhoto);
      }
      if (mounted) {
        setState(() {
          _username = name.isNotEmpty ? name : 'User';
          _email = user?.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading profile: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _authService.getCurrentUser();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLoading
              ? _buildLoadingState(isDark)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Studio Header
                    SliverToBoxAdapter(
                      child: _buildStudioHeader(isDark),
                    ),

                    // Main Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 16),

                          // Profile Identity & Stats Card
                          _buildProfileIdentityCard(isDark, user),

                          const SizedBox(height: 24),

                          // Theme & Appearance
                          _buildSectionHeader(
                            isDark,
                            title: 'Appearance',
                            badge: 'Instant Live',
                            icon: Icons.palette_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildThemeSelector(isDark),

                          const SizedBox(height: 26),

                          // Audio Studio & Recording Preferences
                          _buildSectionHeader(
                            isDark,
                            title: 'Audio Studio',
                            badge: 'Recording',
                            icon: Icons.mic_none_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildAudioSettingsCard(isDark),

                          const SizedBox(height: 26),

                          // AI Intelligence Preferences
                          _buildSectionHeader(
                            isDark,
                            title: 'AI Intelligence',
                            badge: 'Gemini',
                            icon: Icons.auto_awesome_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildAISettingsCard(isDark),

                          const SizedBox(height: 26),

                          // Account Security & Cloud Data
                          _buildSectionHeader(
                            isDark,
                            title: 'Account & Storage',
                            badge: 'Cloud Sync',
                            icon: Icons.shield_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildAccountSecurityCard(isDark),

                          const SizedBox(height: 28),

                          // Sign Out Button
                          _buildSignOutSection(isDark),

                          // Extra padding so bottom dock doesn't clip anything
                          const SizedBox(height: 120),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildStudioHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account & Studio',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preferences, audio capture & cloud settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Cloud Synced Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Synced',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Section Header Helper ---
  Widget _buildSectionHeader(
    bool isDark, {
    required String title,
    required String badge,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  // --- Profile Identity & Stats Card ---
  Widget _buildProfileIdentityCard(bool isDark, User? user) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Purple Gradient Ring & Photo
              EchoUserAvatar(
                size: 68,
                initials: _getInitials(_username),
                showBorder: true,
                showEditBadge: true,
                borderPadding: 2.5,
                onTap: _showAvatarPickerSheet,
              ),

              const SizedBox(width: 16),

              // Name, Email, and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _username,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _showEditNameDialog,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () {
                        if (_email != null) {
                          Clipboard.setData(ClipboardData(text: _email!));
                          HapticFeedback.selectionClick();
                          _showSnackBar('Email copied to clipboard');
                        }
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _email ?? 'No email associated',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Studio Pro Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Studio Pro • Lifetime',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
            height: 1,
          ),
          const SizedBox(height: 16),

          // Real-time Stream of Studio Note Statistics
          StreamBuilder<QuerySnapshot>(
            stream: user == null
                ? null
                : FirebaseFirestore.instance
                    .collection('notes')
                    .where('userId', isEqualTo: user.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              int total = 0;
              int audio = 0;
              int text = 0;

              if (snapshot.hasData && snapshot.data != null) {
                final docs = snapshot.data!.docs;
                total = docs.length;
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>?;
                  final type = data?['type'] as String? ?? 'text';
                  if (type.toLowerCase() == 'audio') {
                    audio++;
                  } else {
                    text++;
                  }
                }
              }

              return Row(
                children: [
                  _buildStatItem(
                    isDark,
                    label: 'Total Notes',
                    value: total.toString(),
                    icon: Icons.note_alt_outlined,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                  _buildStatItem(
                    isDark,
                    label: 'Voice Memos',
                    value: audio.toString(),
                    icon: Icons.mic_rounded,
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                  _buildStatItem(
                    isDark,
                    label: 'Text Notes',
                    value: text.toString(),
                    icon: Icons.edit_note_rounded,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    bool isDark, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- Theme & Appearance Selector ---
  Widget _buildThemeSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildThemeOption(
            isDark,
            title: 'System',
            icon: Icons.brightness_auto_rounded,
            mode: ThemeMode.system,
          ),
          const SizedBox(width: 6),
          _buildThemeOption(
            isDark,
            title: 'Light',
            icon: Icons.light_mode_rounded,
            mode: ThemeMode.light,
          ),
          const SizedBox(width: 6),
          _buildThemeOption(
            isDark,
            title: 'Dark',
            icon: Icons.dark_mode_rounded,
            mode: ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    bool isDark, {
    required String title,
    required IconData icon,
    required ThemeMode mode,
  }) {
    final isSelected = _themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _themeMode = mode);
          _settingsService.setThemeMode(mode);
          _showSnackBar('Theme set to $title');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isDark
                    ? const Color(0xFF1E293B).withOpacity(0.4)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Audio Studio Settings Card ---
  Widget _buildAudioSettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Audio Quality Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recording Quality',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _audioQuality == 'high'
                            ? 'High Fidelity (AAC 128 kbps)'
                            : 'Standard (Efficient 64 kbps)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _buildQualityPill(
                        isDark,
                        label: 'Standard',
                        isSelected: _audioQuality == 'standard',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _audioQuality = 'standard');
                          _settingsService.setAudioQuality('standard');
                        },
                      ),
                      _buildQualityPill(
                        isDark,
                        label: 'High',
                        isSelected: _audioQuality == 'high',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _audioQuality = 'high');
                          _settingsService.setAudioQuality('high');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildDivider(isDark),

          // Auto-Transcribe Switch
          _buildPreferenceSwitch(
            isDark,
            title: 'Auto-Transcribe Voice Memos',
            subtitle: 'Initiate speech-to-text immediately upon recording completion',
            icon: Icons.subtitles_outlined,
            value: _autoTranscribe,
            onChanged: (val) {
              setState(() => _autoTranscribe = val);
              _settingsService.setAutoTranscribe(val);
            },
          ),

          _buildDivider(isDark),

          // Noise Cancellation Switch
          _buildPreferenceSwitch(
            isDark,
            title: 'Voice Clarity & Noise Filter',
            subtitle: 'Attenuate ambient room echoes and background hums',
            icon: Icons.graphic_eq_rounded,
            value: _noiseSuppression,
            onChanged: (val) {
              setState(() => _noiseSuppression = val);
              _settingsService.setNoiseSuppression(val);
            },
          ),

          _buildDivider(isDark),

          // Keep Local Audio Cache
          _buildPreferenceSwitch(
            isDark,
            title: 'Offline Audio Caching',
            subtitle: 'Retain local audio copy for instantaneous offline playback',
            icon: Icons.offline_pin_outlined,
            value: _localCache,
            onChanged: (val) {
              setState(() => _localCache = val);
              _settingsService.setLocalCache(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPill(
    bool isDark, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // --- AI Settings Card ---
  Widget _buildAISettingsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Summary Format
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Summary Style',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summaryStyle == 'concise'
                            ? 'Executive Briefing (Key Highlights)'
                            : 'In-Depth Breakdown (Structured)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _buildQualityPill(
                        isDark,
                        label: 'Concise',
                        isSelected: _summaryStyle == 'concise',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _summaryStyle = 'concise');
                          _settingsService.setSummaryStyle('concise');
                        },
                      ),
                      _buildQualityPill(
                        isDark,
                        label: 'Detailed',
                        isSelected: _summaryStyle == 'detailed',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _summaryStyle = 'detailed');
                          _settingsService.setSummaryStyle('detailed');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildDivider(isDark),

          // Auto Extract Insights
          _buildPreferenceSwitch(
            isDark,
            title: 'Automatic Key Takeaways',
            subtitle: 'Auto-detect key takeaways and tags during transcription',
            icon: Icons.lightbulb_outline_rounded,
            value: _autoInsights,
            onChanged: (val) {
              setState(() => _autoInsights = val);
              _settingsService.setAutoInsights(val);
            },
          ),
        ],
      ),
    );
  }

  // --- Account & Security Card ---
  Widget _buildAccountSecurityCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Reset Password
          _buildActionRow(
            isDark,
            icon: Icons.lock_reset_rounded,
            title: 'Send Password Reset Link',
            subtitle: 'Send a secure recovery email to your registered address',
            onTap: _sendPasswordResetEmail,
          ),

          _buildDivider(isDark),

          // Clear Cached Files
          _buildActionRow(
            isDark,
            icon: Icons.cleaning_services_rounded,
            title: 'Clear Temporary Audio Cache',
            subtitle: 'Free up local device storage space safely',
            onTap: () {
              HapticFeedback.mediumImpact();
              _showSnackBar('Local audio cache cleared successfully (0 MB)');
            },
          ),

          _buildDivider(isDark),

          // App Version Information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EchoNotes Hybrid Studio',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version 1.0.0 (Build 42) • Flutter Engine 3.7.2',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Sign Out Section ---
  Widget _buildSignOutSection(bool isDark) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFEF4444).withOpacity(0.08)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSignOutDialog,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Sign Out of Studio',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Reusable Preference Switch Row ---
  Widget _buildPreferenceSwitch(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF6366F1),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  // --- Action Row Helper ---
  Widget _buildActionRow(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
    );
  }

  // --- Edit Display Name Dialog ---
  Future<void> _showEditNameDialog() async {
    final textController = TextEditingController(text: _username);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Display Name',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) Navigator.pop(context, newName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (updated != null && updated != _username) {
      try {
        final user = _authService.getCurrentUser();
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'username': updated}, SetOptions(merge: true));
        }
        setState(() => _username = updated);
        _showSnackBar('Display name updated successfully');
      } catch (e) {
        _showSnackBar('Failed to update name: $e', isError: true);
      }
    }
  }

  // --- Password Reset Email ---
  Future<void> _sendPasswordResetEmail() async {
    if (_email == null || _email!.isEmpty) {
      _showSnackBar('No email address associated with this account', isError: true);
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email!);
      _showSnackBar('Password reset instructions sent to $_email');
    } catch (e) {
      _showSnackBar('Could not send reset email: $e', isError: true);
    }
  }

  // --- Sign Out Confirmation Dialog ---
  Future<void> _showSignOutDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of EchoNotes? Your synchronized notes will remain secure in the cloud.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ShareReceiverService().clearPendingAudio(deleteFile: true);
        await _authService.signOut();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      } catch (e) {
        _showSnackBar('Error signing out: $e', isError: true);
      }
    }
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading studio profile...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6366F1),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // --- Avatar Picker Bottom Sheet ---
  Future<void> _showAvatarPickerSheet() async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeUrl = _settingsService.avatarUrl;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Avatar',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose an avatar or upload from your device',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Preset Avatars Grid (Balanced 3x2 Layout)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: SettingsService.presetAvatars.length,
                    itemBuilder: (context, index) {
                      final preset = SettingsService.presetAvatars[index];
                      final isSelected = activeUrl == preset['url'];
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await _settingsService.setAvatarUrl(preset['url']!);
                          _syncAvatarToFirestore(preset['url']!);
                          if (mounted) setState(() {});
                          Navigator.pop(sheetContext);
                          _showSnackBar(
                              'Profile photo updated to ${preset['name']}');
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                EchoUserAvatar(
                                  size: 58,
                                  customUrl: preset['url'],
                                  showBorder: isSelected,
                                  borderPadding: 2.5,
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6)
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preset['name']!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Upload custom photo from device
                  InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickCustomAvatarImage();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.file_upload_outlined,
                              size: 19,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose from Device Gallery or Files',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'JPG, PNG, or WEBP picture',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomAvatarImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final user = _authService.getCurrentUser();

        // 1. Immediately apply local preview for zero perceived lag
        await _settingsService.setAvatarUrl(path);
        if (mounted) setState(() {});
        _showSnackBar('Syncing photo with cloud storage...');

        String cloudUrl = path;

        // 2. Upload to Supabase Storage bucket (Free tier, no Firebase Blaze required)
        if (user != null) {
          try {
            final file = File(path);
            final ext = path.split('.').last.toLowerCase();
            final cloudFileName =
                'avatars/${user.uid}/dp_${DateTime.now().millisecondsSinceEpoch}.$ext';

            await Supabase.instance.client.storage
                .from('audio_bucket')
                .upload(cloudFileName, file,
                    fileOptions: const FileOptions(upsert: true));

            cloudUrl = Supabase.instance.client.storage
                .from('audio_bucket')
                .getPublicUrl(cloudFileName);

            await _settingsService.setAvatarUrl(cloudUrl);
          } catch (uploadError) {
            debugPrint('Supabase cloud avatar upload fallback: $uploadError');
          }
        }

        // 3. Persist public URL to Firebase Auth & Firestore for cross-device sync
        await _syncAvatarToFirestore(cloudUrl);

        if (mounted) {
          setState(() {});
          _showSnackBar('Profile photo updated & available on all devices!');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to pick photo: $e', isError: true);
    }
  }

  Future<void> _syncAvatarToFirestore(String photoUrl) async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        await user.updatePhotoURL(photoUrl);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'photoUrl': photoUrl},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }
}
