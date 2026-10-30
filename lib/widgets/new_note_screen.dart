import 'dart:async';
import 'dart:io';
import 'package:echonotes/services/assembly_ai_services.dart';
import 'package:echonotes/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/services/permission_services.dart';
import 'package:echonotes/services/settings_service.dart';
import 'package:google_fonts/google_fonts.dart';

class NewNoteScreen extends StatefulWidget {
  final String? initialAudioPath;
  const NewNoteScreen({super.key, this.initialAudioPath});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen>
    with TickerProviderStateMixin {
  final AuthService authService = AuthService();
  final PermissionService permissionService = PermissionService();
  final AssemblyAIService assemblyAIService = AssemblyAIService();
  final GeminiService geminiService = GeminiService();
  final TextEditingController _contentController = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // Phase 7 Collection destination
  String? _selectedCollectionId;
  String? _selectedCollectionName;

  // State
  bool isRecording = false;
  bool showTextMode = false;
  bool isProcessing = false;
  bool isSaving = false;
  String? _audioPath;
  String _processingStep = '';
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initAnimations();
    if (widget.initialAudioPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _audioPath = widget.initialAudioPath;
        final user = authService.getCurrentUser();
        if (user != null) {
          _processAndSaveAudio(user);
        }
      });
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _recorder.closeRecorder();
    _pulseController.dispose();
    _fadeController.dispose();
    _waveController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await permissionService.requestMicrophonePermission();
    if (!hasPermission) {
      _snack('Microphone permission denied', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
    final bitRate = SettingsService().audioQuality == 'high' ? 128000 : 64000;
    await _recorder.startRecorder(
      toFile: _audioPath,
      codec: Codec.aacADTS,
      bitRate: bitRate,
    );
    setState(() {
      isRecording = true;
      _recordingSeconds = 0;
    });
    _pulseController.repeat(reverse: true);
    _waveController.repeat(reverse: true);
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    HapticFeedback.heavyImpact();
    _recordingTimer?.cancel();
    _pulseController.stop();
    _waveController.stop();
    await _recorder.stopRecorder();
    setState(() => isRecording = false);

    final user = authService.getCurrentUser();
    if (user == null || _audioPath == null) {
      _snack('Error: session expired', isError: true);
      return;
    }

    await _processAndSaveAudio(user);
  }

  Future<void> _pickAndProcessAudio() async {
    final user = authService.getCurrentUser();
    if (user == null) {
      _snack('Error: session expired', isError: true);
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      );

      if (result != null && result.files.single.path != null) {
        _audioPath = result.files.single.path!;
        await _processAndSaveAudio(user);
      }
    } catch (e) {
      _snack('Error selecting audio file: $e', isError: true);
    }
  }

  Future<void> _processAndSaveAudio(user) async {
    setState(() {
      isProcessing = true;
      _processingStep = 'Uploading audio…';
    });

    try {
      // 1. Upload to Supabase
      final file = File(_audioPath!);
      final fileName =
          '${user.uid}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await Supabase.instance.client.storage
          .from('audio_bucket')
          .upload(fileName, file);
      final audioUrl = Supabase.instance.client.storage
          .from('audio_bucket')
          .getPublicUrl(fileName);

      // 2. Transcribe
      setState(() => _processingStep = 'Transcribing your voice…');
      final audioBytes = await file.readAsBytes();
      final transcription = await assemblyAIService.transcribeAudio(
        audioUrl,
        audioBytes: audioBytes,
      );

      if (transcription == null) {
        _snack(
          'Transcription failed — note saved without transcript',
          isError: true,
        );
        // Save anyway with placeholder
        await _saveNote(
          userId: user.uid,
          title: 'Voice Note',
          audioUrl: audioUrl,
          transcription: null,
        );
        return;
      }

      // 3. Auto-generate smart title using Gemini
      setState(() => _processingStep = 'Creating smart title…');
      final hasSpeech =
          transcription.trim().isNotEmpty &&
          transcription != '[No speech detected]';
      final title =
          hasSpeech
              ? await geminiService.generateTitle(transcription)
              : 'Voice Note';

      // 4. Save to Firestore
      setState(() => _processingStep = 'Saving your note…');
      await _saveNote(
        userId: user.uid,
        title: title,
        audioUrl: audioUrl,
        transcription: transcription,
      );

      setState(() => _processingStep = 'Done! 🎉');
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
      _snack('Note saved! AI features are ready in the detail view.');
    } catch (e) {
      print('[NewNote] Error: $e');
      _snack('Error saving note: $e', isError: true);
    } finally {
      setState(() {
        isProcessing = false;
        _processingStep = '';
      });
      if (_audioPath != null) {
        try {
          await File(_audioPath!).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _saveNote({
    required String userId,
    required String title,
    String? audioUrl,
    String? transcription,
    String? content,
    String type = 'audio',
  }) async {
    await FirebaseFirestore.instance
        .collection('notes')
        .add(
          Note(
            id: '',
            userId: userId,
            title: title,
            createdAt: DateTime.now(),
            audioUrl: audioUrl,
            transcription: transcription,
            summary: content,
            type: type,
            collectionId: _selectedCollectionId,
            collectionName: _selectedCollectionName,
          ).toFirestore(),
        );
  }

  Future<void> _saveTextNote() async {
    final user = authService.getCurrentUser();
    if (user == null) {
      _snack('No user logged in', isError: true);
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _snack('Please write something first', isError: true);
      return;
    }

    setState(() => isSaving = true);
    try {
      // Auto-generate smart title from content
      final title = await geminiService.generateTitle(content);

      await _saveNote(
        userId: user.uid,
        title: title,
        content: content,
        type: 'text',
      );
      if (mounted) Navigator.pop(context);
      _snack('Note saved!');
    } catch (e) {
      _snack('Error saving note: $e', isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(isDark),
                _buildCollectionSelector(isDark),
                Expanded(
                  child:
                      showTextMode
                          ? _buildTextMode(isDark)
                          : _buildVoiceMode(isDark),
                ),
              ],
            ),
          ),
          if (isProcessing) _buildProcessingOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildCollectionSelector(bool isDark) {
    final userId = authService.getCurrentUser()?.uid ?? '';
    return StreamBuilder<List<EchoCollection>>(
      stream: CollectionsService().getCollectionsStream(userId),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              PopupMenuButton<String?>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side:
                      isDark
                          ? const BorderSide(color: AppColors.darkBorder)
                          : BorderSide.none,
                ),
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
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
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                          ),
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
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _selectedCollectionId != null
                            ? const Color(
                              0xFF6366F1,
                            ).withOpacity(isDark ? 0.22 : 0.10)
                            : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _selectedCollectionId != null
                              ? const Color(
                                0xFF6366F1,
                              ).withOpacity(isDark ? 0.45 : 0.3)
                              : (isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedCollectionId != null
                            ? Icons.folder_rounded
                            : Icons.inbox_outlined,
                        size: 13.5,
                        color:
                            _selectedCollectionId != null
                                ? (isDark
                                    ? AppColors.primaryLight
                                    : const Color(0xFF6366F1))
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedCollectionName ?? 'Unfiled',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _selectedCollectionId != null
                                  ? (isDark
                                      ? AppColors.primaryLight
                                      : const Color(0xFF6366F1))
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
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
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient:
            isDark
                ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF131722), // studio dark surface
                    Color(0xFF0D1017), // mid dark transition
                    Color(0xFF090B10), // dark scaffold base
                  ],
                  stops: [0.0, 0.45, 1.0],
                )
                : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF), // Pure white top
                    Color(0xFFF5F3FF), // Soft lavender transition
                    Color(0xFFEDE9FE), // Matching the purple tone
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _iconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: isProcessing ? null : () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              showTextMode ? 'Write a Note' : 'Voice Note',
              style: GoogleFonts.plusJakartaSans(
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Mode switcher
          GestureDetector(
            onTap:
                isRecording
                    ? null
                    : () => setState(() => showTextMode = !showTextMode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.2,
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
                children: [
                  Icon(
                    showTextMode ? Icons.mic_rounded : Icons.edit_rounded,
                    color:
                        isDark
                            ? AppColors.primaryLight
                            : const Color(0xFF6366F1),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showTextMode ? 'Voice' : 'Text',
                    style: GoogleFonts.plusJakartaSans(
                      color:
                          isDark
                              ? AppColors.primaryLight
                              : const Color(0xFF6366F1),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  Widget _iconBtn({
    required IconData icon,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.035),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          size: 17,
        ),
      ),
    );
  }

  // ── Voice Mode ─────────────────────────────────────────────────────────────

  Widget _buildVoiceMode(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _buildWaveVisualizer(isDark),
          const SizedBox(height: 40),
          _buildMicButton(isDark),
          const SizedBox(height: 28),
          _buildRecordingLabel(isDark),
          const Spacer(),
          _buildUploadButton(isDark),
          const SizedBox(height: 14),
          _buildVoiceHint(isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUploadButton(bool isDark) {
    if (isRecording || isProcessing) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _pickAndProcessAudio,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file_outlined,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Upload Audio File (.mp3, .wav, .m4a)',
              style: GoogleFonts.plusJakartaSans(
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveVisualizer(bool isDark) {
    return SizedBox(
      height: 60,
      child:
          isRecording
              ? AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(9, (i) {
                      final offset = (i * 0.4) % 1.0;
                      final t = (_waveAnimation.value + offset) % 1.0;
                      final h = 8.0 + 44.0 * (0.5 + 0.5 * _easeInOut(t));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        width: 4.5,
                        height: h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  );
                },
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(9, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: 4.5,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
    );
  }

  double _easeInOut(double t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  }

  Widget _buildMicButton(bool isDark) {
    return GestureDetector(
      onTap: isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: isRecording ? _pulseAnimation.value : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ambient ring
                Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isRecording
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1))
                        .withOpacity(isDark ? 0.22 : 0.12),
                  ),
                ),
                // Inner record button with studio purple gradient
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          isRecording
                              ? [
                                const Color(0xFFEF4444),
                                const Color(0xFFDC2626),
                              ]
                              : [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6),
                              ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6366F1))
                            .withOpacity(isDark ? 0.5 : 0.38),
                        blurRadius: 36,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingLabel(bool isDark) {
    return Column(
      children: [
        if (isRecording) ...[
          Text(
            _formatTime(_recordingSeconds),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFE11D48),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE11D48),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Recording… tap to stop',
                style: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ] else ...[
          Text(
            'Tap to record',
            style: GoogleFonts.plusJakartaSans(
              color:
                  isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Title & transcript generated automatically',
            style: GoogleFonts.inter(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceHint(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color:
            (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: isDark ? AppColors.primaryLight : const Color(0xFF6366F1),
            size: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI will auto-title your note from the transcript',
              style: GoogleFonts.inter(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text Mode ─────────────────────────────────────────────────────────────

  Widget _buildTextMode(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s on your mind?',
            style: GoogleFonts.plusJakartaSans(
              color:
                  isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF0F172A),
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI will generate a title automatically',
            style: GoogleFonts.inter(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                cursorColor:
                    isDark ? AppColors.primaryLight : AppColors.primary,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                  fontSize: 16,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Start writing your note here…\n\nYou can jot down ideas, meeting notes, reminders, anything.',
                  hintStyle: GoogleFonts.inter(
                    color:
                        isDark
                            ? AppColors.darkTextMuted
                            : const Color(0xFF94A3B8),
                    fontSize: 16,
                    height: 1.6,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isSaving ? null : _saveTextNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                disabledBackgroundColor: const Color(
                  0xFF6366F1,
                ).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.28),
              ),
              child:
                  isSaving
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Save Note',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Processing Overlay ─────────────────────────────────────────────────────

  Widget _buildProcessingOverlay(bool isDark) {
    return Container(
      color: Colors.black.withOpacity(isDark ? 0.65 : 0.4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Processing…',
                style: GoogleFonts.plusJakartaSans(
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _processingStep,
                style: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(
                  backgroundColor:
                      isDark ? AppColors.darkSurface : const Color(0xFFEEF2FF),
                  color: const Color(0xFF6366F1),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
