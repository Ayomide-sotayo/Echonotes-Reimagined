import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/core/components/echo_recent_note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:echonotes/core/components/echo_user_avatar.dart';
import 'package:echonotes/services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onViewAll;
  final VoidCallback? onSearch;
  final VoidCallback? onProfile;
  const HomeScreen({
    super.key,
    this.onViewAll,
    this.onSearch,
    this.onProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService authService = AuthService();
  String username = 'User';
  bool isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _loadUsername();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    try {
      final name = await authService.getUsername();
      final cloudPhoto = await authService.getPhotoUrl();
      if (cloudPhoto != null && cloudPhoto.isNotEmpty) {
        await SettingsService().setAvatarUrl(cloudPhoto);
      }
      if (mounted) {
        setState(() {
          username = name.isNotEmpty ? name : 'User';
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _handleDirectUpload() async {
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      );

      if (result != null && result.files.single.path != null && mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.newNote,
          arguments: result.files.single.path!,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting audio file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();
    await _loadUsername();
    // Allow a subtle pause for smooth visual feedback on refresh
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authService.getCurrentUser();
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body:
          isLoading
              ? _buildLoadingScreen(isDark)
              : SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity:
                      disableMotion
                          ? const AlwaysStoppedAnimation(1.0)
                          : _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: const Color(0xFF6366F1),
                    backgroundColor:
                        isDark ? AppColors.darkSurface : Colors.white,
                    edgeOffset: 10,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          _buildHeader(isDark),
                          const SizedBox(height: 20),
                          _buildAsymmetricBentoStats(user, isDark),
                          const SizedBox(height: 20),
                          _buildQuickAudioCaptureCard(isDark),
                          const SizedBox(height: 26),
                          _buildRecentNotesSection(user, isDark),
                          const SizedBox(
                            height: 100,
                          ), // Safe scroll margin for bottom dock
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Opening Studio...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getGreeting(),
                  style: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('✨', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              username,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        // User Profile Avatar at Top Right (Navigates to Profile Tab)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.onProfile != null) {
              widget.onProfile!();
            } else if (widget.onViewAll != null) {
              widget.onViewAll!();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1)
                      .withOpacity(isDark ? 0.35 : 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: EchoUserAvatar(
              size: 44,
              initials: _getInitials(username),
              showBorder: true,
              borderPadding: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAsymmetricBentoStats(user, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          user == null
              ? null
              : FirebaseFirestore.instance
                  .collection('notes')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
      builder: (context, snapshot) {
        int totalNotes = 0;
        int audioNotes = 0;
        int todayNotes = 0;

        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          totalNotes = docs.length;
          final today = DateTime.now();

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final type = data['type'] as String? ?? 'text';
            if (type.toLowerCase() == 'audio') {
              audioNotes++;
            }

            final createdAtTimestamp = data['createdAt'] as Timestamp?;
            if (createdAtTimestamp != null) {
              final date = createdAtTimestamp.toDate();
              if (date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day) {
                todayNotes++;
              }
            }
          }
        }

        return Row(
          children: [
            // Left: Prominent Total Notes Card with luxury gradient and soundwave pattern
            Expanded(
              flex: 6,
              child: Container(
                height: 158,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A), // Deep Slate
                      Color(0xFF1E293B), // Slate 800
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Artistic Soundwave Pattern Watermark
                      Positioned.fill(
                        child: CustomPaint(
                          painter: const _TotalNotesPatternPainter(),
                        ),
                      ),
                      // Ambient Violet / Cyan Highlight Glow
                      Positioned(
                        top: -24,
                        right: -24,
                        child: Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF6366F1).withOpacity(0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Foreground Card Content
                      Padding(
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.16),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.graphic_eq_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'STUDIO',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF38BDF8),
                                  size: 14,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  totalNotes.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.05,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Total Notes',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Indexed & synced',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right: Two stacked clean supporting cards with comfortable vertical space
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 158,
                child: Column(
                  children: [
                    // Audio Notes Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.2 : 0.025,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.mic_none_rounded,
                                color: AppColors.accentCyan,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    audioNotes.toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark
                                              ? AppColors.darkTextPrimary
                                              : const Color(0xFF0F172A),
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Audio Notes',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Created Today Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.2 : 0.025,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: AppColors.accentCoral.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.accentCoral,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    todayNotes.toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isDark
                                              ? AppColors.darkTextPrimary
                                              : const Color(0xFF0F172A),
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Created Today',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
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
          ],
        );
      },
    );
  }

  Widget _buildQuickAudioCaptureCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Section Label + AI Ready Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentCoral.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.accentCoral,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Quick Audio Capture',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Ready',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Action Buttons: Record Voice & Upload
          Row(
            children: [
              // Primary Action: Record Voice with Purple Studio Gradient
              Expanded(
                flex: 3,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pushNamed(context, AppRoutes.newNote);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Record Voice',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Secondary Action: Upload Audio File
              Expanded(
                flex: 2,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurface
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _handleDirectUpload,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_outlined,
                            size: 19,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Upload',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotesSection(user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Recent Notes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onViewAll?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream:
              user == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('notes')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
          builder: (context, snapshot) {
            if (user == null) {
              return _buildEmptyState(
                'Please sign in to view your notes',
                Icons.lock_outline_rounded,
                isDark,
              );
            }

            if (snapshot.hasError) {
              return _buildEmptyState(
                'Unable to load notes right now',
                Icons.error_outline_rounded,
                isDark,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return _buildEmptyState(
                'No notes captured yet',
                Icons.mic_none_rounded,
                isDark,
                ctaText: 'Record your first note',
                onCta: () => Navigator.pushNamed(context, AppRoutes.newNote),
              );
            }

            final notes = docs.map((doc) => Note.fromFirestore(doc)).toList();

            return Column(
              children:
                  notes.map((note) {
                    return EchoRecentNoteCard(
                      note: note,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(
                          context,
                          AppRoutes.noteDetail,
                          arguments: note,
                        );
                      },
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    String message,
    IconData icon,
    bool isDark, {
    String? ctaText,
    VoidCallback? onCta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaText != null && onCta != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onCta,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  ctaText,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCoral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalNotesPatternPainter extends CustomPainter {
  const _TotalNotesPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle concentric studio ripple rings from the top-right corner
    final ringPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.95, size.height * 0.15);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 26.0, ringPaint);
    }

    // 2. Translucent audio equalizer bars in the bottom-right corner
    final barPaint =
        Paint()
          ..color = const Color(0xFF38BDF8).withOpacity(0.14)
          ..style = PaintingStyle.fill;

    final barHeights = [14.0, 26.0, 42.0, 62.0, 46.0, 28.0, 16.0];
    final startX = size.width - 70;
    final baseY = size.height - 18;

    for (int i = 0; i < barHeights.length; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          startX + (i * 9.0),
          baseY - barHeights[i],
          4.5,
          barHeights[i],
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
