import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/features/notes/services/audio_note_processing_service.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ShareImportScreen extends StatefulWidget {
  final SharedAudioPayload payload;

  const ShareImportScreen({super.key, required this.payload});

  @override
  State<ShareImportScreen> createState() => _ShareImportScreenState();
}

class _ShareImportScreenState extends State<ShareImportScreen>
    with TickerProviderStateMixin {
  final AudioNoteProcessingService _processingService =
      AudioNoteProcessingService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Audio player state
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Processing state
  bool _isProcessing = false;
  bool _isCancelled = false;
  AudioProcessingProgress? _currentProgress;
  String? _errorMessage;
  Note? _createdNote;

  // Collection selection
  String? _selectedCollectionId;
  String? _selectedCollectionName;

  // Animation controllers
  late final AnimationController _pulseController;
  late final AnimationController _entryController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    ShareReceiverService().isImportScreenActive = true;
    _initAnimations();
    _initAudioPlayer();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _entryController.forward();
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    // Preload audio duration
    try {
      _audioPlayer.setSource(DeviceFileSource(widget.payload.path)).catchError((_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    ShareReceiverService().isImportScreenActive = false;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _toggleAudioPlay() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.payload.path));
    }
  }

  Future<void> _startImportAndTranscribe() async {
    HapticFeedback.mediumImpact();
    // Stop playback if playing
    if (_isPlaying) {
      await _audioPlayer.stop();
    }

    setState(() {
      _isProcessing = true;
      _isCancelled = false;
      _errorMessage = null;
      _currentProgress = const AudioProcessingProgress(
        phase: AudioProcessingPhase.validating,
        message: 'Starting import pipeline…',
        progress: 0.05,
      );
    });

    try {
      final file = File(widget.payload.path);
      final note = await _processingService.processAndSaveAudio(
        audioFile: file,
        originalName: widget.payload.name,
        fileExtension: widget.payload.cleanExtension,
        collectionId: _selectedCollectionId,
        collectionName: _selectedCollectionName,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _currentProgress = progress);
          }
        },
        isCancelled: () => _isCancelled,
      );

      if (_isCancelled) return;

      if (note != null && mounted) {
        setState(() {
          _isProcessing = false;
          _createdNote = note;
        });

        // Clear the pending shared audio cache since it has now been processed
        await ShareReceiverService().clearPendingAudio(deleteFile: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _cancelProcessing() {
    HapticFeedback.lightImpact();
    _isCancelled = true;
    setState(() {
      _isProcessing = false;
      _errorMessage = 'Import cancelled by user.';
    });
  }

  Future<void> _handleDismiss() async {
    HapticFeedback.lightImpact();
    if (_isPlaying) await _audioPlayer.stop();
    await ShareReceiverService().clearPendingAudio(deleteFile: true);
    if (mounted) Navigator.of(context).pop();
  }

  void _navigateToCreatedNote() {
    HapticFeedback.mediumImpact();
    if (_createdNote != null) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.noteDetail,
        arguments: _createdNote,
      );
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isProcessing) {
          _handleDismiss();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _createdNote != null
                ? _buildSuccessView(isDark)
                : _isProcessing
                    ? _buildProcessingView(isDark)
                    : _buildConfirmationView(isDark),
          ),
        ),
      ),
    );
  }

  // ── Confirmation & Preview View ─────────────────────────────────────────────

  Widget _buildConfirmationView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Navigation / Dismiss Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF6366F1).withOpacity(0.18)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF6366F1).withOpacity(0.3)
                        : const Color(0xFFC7D2FE),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎙️', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      'External Audio Share',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _handleDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
                tooltip: 'Dismiss',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title & Subtitle
          Text(
            'Import & Transcribe',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Incoming audio received from external application. Preview and confirm before processing with AI.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 24),

          // Audio Card Preview
          _buildAudioCard(isDark),

          const SizedBox(height: 16),

          // Error Banner if previous attempt failed
          if (_errorMessage != null) _buildErrorBanner(isDark),

          // Privacy & Confirmation Requirement Card
          _buildPrivacyCard(isDark),

          const SizedBox(height: 16),

          // Phase 7 Collection Hook: Organization Anchor
          _buildPhase7CollectionAnchor(isDark),

          const SizedBox(height: 28),

          // Action Buttons: Cancel vs Import & Transcribe
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _handleDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _startImportAndTranscribe,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Import & Transcribe',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Audio Preview Card ──────────────────────────────────────────────────────

  Widget _buildAudioCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges & File details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: _isPlaying ? _pulseScale : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF6366F1),
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.payload.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.payload.formatBadge,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.payload.formattedSize,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Player bar: Play/Pause button + Scrubber Slider + Timers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1420) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleAudioPlay,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 3.5,
                          activeTrackColor: const Color(0xFF6366F1),
                          inactiveTrackColor: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          thumbColor: const Color(0xFF6366F1),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _duration.inMilliseconds > 0
                              ? (_position.inMilliseconds / _duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: (val) {
                            if (_duration.inMilliseconds > 0) {
                              final seekMs = (val * _duration.inMilliseconds).toInt();
                              _audioPlayer.seek(Duration(milliseconds: seekMs));
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              _duration == Duration.zero ? '--:--' : _formatDuration(_duration),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy & Permission Disclosure ─────────────────────────────────────────

  Widget _buildPrivacyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1B4B).withOpacity(0.35)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explicit Confirmation Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To protect your privacy, EchoNotes never processes shared recordings automatically. Tapping "Import & Transcribe" securely uploads the file to your private storage and runs acoustic AI transcription.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 7 Future Compatibility Hook ──────────────────────────────────────

  Widget _buildPhase7CollectionAnchor(bool isDark) {
    final userId = AuthService().getCurrentUser()?.uid ?? '';

    return StreamBuilder<List<EchoCollection>>(
      stream: CollectionsService().getCollectionsStream(userId),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _selectedCollectionId != null
                          ? Icons.folder_rounded
                          : Icons.inbox_rounded,
                      size: 20,
                      color:
                          _selectedCollectionId != null
                              ? const Color(0xFF6366F1)
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destination Collection',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _selectedCollectionName ?? 'Unfiled Notes (Default)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String?>(
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: isDark ? AppColors.darkSurface : Colors.white,
                onSelected: (colId) {
                  setState(() {
                    if (colId == null) {
                      _selectedCollectionId = null;
                      _selectedCollectionName = null;
                    } else {
                      _selectedCollectionId = colId;
                      _selectedCollectionName =
                          collections.firstWhere((c) => c.id == colId).name;
                    }
                  });
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Unfiled Notes (Default)',
                          style: GoogleFonts.inter(fontSize: 13.5),
                        ),
                      ),
                      ...collections.map(
                        (col) => PopupMenuItem<String?>(
                          value: col.id,
                          child: Row(
                            children: [
                              Icon(col.iconData, size: 16, color: col.color),
                              const SizedBox(width: 8),
                              Text(
                                col.name,
                                style: GoogleFonts.inter(fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.shade700.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.shade400.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Processing State View ──────────────────────────────────────────────

  Widget _buildProcessingView(bool isDark) {
    final progress = _currentProgress?.progress ?? 0.10;
    final message = _currentProgress?.message ?? 'Processing audio…';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Concentric ambient acoustic waves
            ScaleTransition(
              scale: _pulseScale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Importing Recording',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
              ),
            ),

            const SizedBox(height: 28),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            ),

            const SizedBox(height: 32),

            // Pipeline Stage Checklist
            _buildPipelineStep(
              title: 'Validate Audio Integrity',
              done: progress >= 0.20,
              active: progress < 0.20,
              isDark: isDark,
            ),
            _buildPipelineStep(
              title: 'Upload to Private Storage',
              done: progress >= 0.50,
              active: progress >= 0.20 && progress < 0.50,
              isDark: isDark,
            ),
            _buildPipelineStep(
              title: 'AssemblyAI Speech Transcription',
              done: progress >= 0.75,
              active: progress >= 0.50 && progress < 0.75,
              isDark: isDark,
            ),
            _buildPipelineStep(
              title: 'Gemini Smart Titling & Insights',
              done: progress >= 0.95,
              active: progress >= 0.75 && progress < 0.95,
              isDark: isDark,
            ),
            _buildPipelineStep(
              title: 'Save Note to Library',
              done: progress >= 1.0,
              active: progress >= 0.95 && progress < 1.0,
              isDark: isDark,
            ),

            const SizedBox(height: 32),

            // Cancel Button
            TextButton(
              onPressed: _cancelProcessing,
              child: Text(
                'Cancel Import',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStep({
    required String title,
    required bool done,
    required bool active,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? const Color(0xFF10B981)
                  : active
                      ? const Color(0xFF6366F1)
                      : isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : active
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: active || done ? FontWeight.w600 : FontWeight.w400,
              color: done
                  ? (isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A))
                  : active
                      ? const Color(0xFF6366F1)
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success View ────────────────────────────────────────────────────────────

  Widget _buildSuccessView(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withOpacity(0.15),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Imported Successfully!',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Your audio has been transcribed and converted into an intelligent note.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 24),

            // Card showing note title & transcript snippet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Smart Title Generated',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _createdNote?.title ?? 'Voice Note',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_createdNote?.transcription != null &&
                      _createdNote!.transcription!.isNotEmpty &&
                      _createdNote!.transcription != '[No speech detected]') ...[
                    const SizedBox(height: 8),
                    Text(
                      _createdNote!.transcription!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Primary Button: Open Note
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToCreatedNote,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Open Note',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary Button: Back to Home
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (route) => false,
                );
              },
              child: Text(
                'Back to Library',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
