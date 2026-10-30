// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, unused_field
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/components/echo_pill_badge.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/collections/ui/widgets/move_note_sheet.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/features/notes/ui/full_content_reader_screen.dart';
import 'package:echonotes/features/notes/utils/content_preview_helper.dart';
import 'package:echonotes/services/assembly_ai_services.dart';
import 'package:echonotes/services/gemini_service.dart';
import 'package:echonotes/services/pdf_convert.dart';
import 'package:echonotes/services/tts_service.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GeminiService geminiService = GeminiService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool isPlaying = false;
  bool isSummarizing = false;
  bool isExtracting = false;
  bool isAnalyzing = false;
  bool isTranslating = false;
  bool isAnswering = false;
  bool isGeneratingPDF = false;

  final TtsService _ttsService = TtsService();
  bool _isSpeakingSummary = false;
  bool _isSpeakingContent = false;
  bool _isRetryingTranscription = false;

  // Audio progress tracking variables
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _positionTimer;

  late Note _updatedNote;

  // Selected AI Workspace Tab: 0 = Summary, 1 = Key Points, 2 = Keywords, 3 = Sentiment, 4 = Translate, 5 = Ask AI
  int _selectedAITab = 0;
  String _selectedLanguage = 'French';

  // Local checklist state for action items (tracks checked status per item)
  final Set<String> _checkedActionItems = {};

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _updatedNote = widget.note;

    _ttsService.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          if (state == TtsState.stopped) {
            _isSpeakingSummary = false;
            _isSpeakingContent = false;
          }
        });
      }
    };

    _initAnimations();
    if (_updatedNote.type.toLowerCase() == 'audio') {
      _initAudioPlayer();
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _initAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          _currentPosition = Duration.zero;
        });
        _pulseController.stop();
        _pulseController.reset();
        _positionTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _audioPlayer.dispose();
    _positionTimer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Audio Handlers ---
  Future<bool> _isValidAudioUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking audio URL: $e');
      return false;
    }
  }

  Future<void> _playAudio() async {
    if (_updatedNote.audioUrl == null) {
      _showSnackBar('No audio URL available', isError: true);
      return;
    }
    try {
      final isValid = await _isValidAudioUrl(_updatedNote.audioUrl!);
      if (!isValid) {
        _showSnackBar('Invalid or inaccessible audio URL', isError: true);
        return;
      }
      await _audioPlayer.play(UrlSource(_updatedNote.audioUrl!));
      if (mounted) {
        setState(() => isPlaying = true);
        _pulseController.repeat(reverse: true);
      }
    } catch (e) {
      print('Error playing audio: $e');
      _showSnackBar('Error playing audio: $e', isError: true);
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          isPlaying = false;
          _currentPosition = Duration.zero;
        });
        _pulseController.stop();
        _pulseController.reset();
        _positionTimer?.cancel();
      }
    } catch (e) {
      print('Error stopping audio: $e');
      _showSnackBar('Error stopping audio: $e', isError: true);
    }
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- TTS Handlers ---
  Future<void> _toggleSpeakSummary() async {
    final summary = _updatedNote.aiSummary;
    if (summary == null || summary.trim().isEmpty) return;
    if (_isSpeakingSummary) {
      await _ttsService.stop();
      if (mounted) setState(() => _isSpeakingSummary = false);
    } else {
      if (_isSpeakingContent) {
        await _ttsService.stop();
        _isSpeakingContent = false;
      }
      if (mounted) setState(() => _isSpeakingSummary = true);
      await _ttsService.speak(summary);
    }
  }

  Future<void> _toggleSpeakContent() async {
    final content = _updatedNote.mainContent;
    if (content == null || content.trim().isEmpty) return;
    if (_isSpeakingContent) {
      await _ttsService.stop();
      if (mounted) setState(() => _isSpeakingContent = false);
    } else {
      if (_isSpeakingSummary) {
        await _ttsService.stop();
        _isSpeakingSummary = false;
      }
      if (mounted) setState(() => _isSpeakingContent = true);
      await _ttsService.speak(content);
    }
  }

  // --- AI Operations ---
  Future<void> _generateSummary() async {
    if (_updatedNote.mainContent == null) {
      _showSnackBar('No content available for summarization', isError: true);
      return;
    }

    setState(() => isSummarizing = true);
    try {
      final aiSummary = await geminiService.summarizeText(
        _updatedNote.mainContent!,
      );
      await _updateNoteInFirestore({'aiSummary': aiSummary});
      _showSnackBar('Summary generated successfully!');
    } catch (e) {
      print('Error generating summary: $e');
      _showSnackBar('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isSummarizing = false);
    }
  }

  Future<void> _extractKeywordsAndActions() async {
    if (_updatedNote.mainContent == null) {
      _showSnackBar('No content available for analysis', isError: true);
      return;
    }

    setState(() => isExtracting = true);
    try {
      final keywords = await geminiService.extractKeywords(
        _updatedNote.mainContent!,
      );
      final actionItems = await geminiService.extractActionItems(
        _updatedNote.mainContent!,
      );

      await _updateNoteInFirestore({
        'keywords': keywords,
        'actionItems': actionItems,
      });
      _showSnackBar('Keywords and action items extracted!');
    } catch (e) {
      print('Error extracting data: $e');
      _showSnackBar('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isExtracting = false);
    }
  }

  Future<void> _analyzeSentiment() async {
    if (_updatedNote.mainContent == null) {
      _showSnackBar(
        'No content available for sentiment analysis',
        isError: true,
      );
      return;
    }

    setState(() => isAnalyzing = true);
    try {
      final sentiment = await geminiService.analyzeSentiment(
        _updatedNote.mainContent!,
      );
      await _updateNoteInFirestore({'sentiment': sentiment});
      _showSnackBar(
        'Sentiment updated: $sentiment ${_updatedNote.sentimentEmoji}',
      );
    } catch (e) {
      print('Error analyzing sentiment: $e');
      _showSnackBar('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isAnalyzing = false);
    }
  }

  Future<void> _translateText(String language) async {
    if (_updatedNote.mainContent == null) {
      _showSnackBar('No content available for translation', isError: true);
      return;
    }

    setState(() => isTranslating = true);
    try {
      final translation = await geminiService.translateText(
        _updatedNote.mainContent!,
        language,
      );
      final currentTranslations =
          _updatedNote.translations ?? <String, String>{};
      currentTranslations[language] = translation;

      await _updateNoteInFirestore({'translations': currentTranslations});
      _showSnackBar('Translated to $language!');
    } catch (e) {
      print('Error translating: $e');
      _showSnackBar('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isTranslating = false);
    }
  }

  Future<void> _answerQuestion() async {
    final question = _questionController.text.trim();
    if (_updatedNote.mainContent == null || question.isEmpty) {
      _showSnackBar('Please enter a question to ask', isError: true);
      return;
    }

    setState(() => isAnswering = true);
    try {
      final answer = await geminiService.answerQuestion(
        _updatedNote.mainContent!,
        question,
      );

      final currentQA = _updatedNote.qaResults ?? <String, String>{};
      currentQA[question] = answer;

      await _updateNoteInFirestore({'qaResults': currentQA});
      _questionController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _showSnackBar('Question answered!');
    } catch (e) {
      print('Error answering question: $e');
      _showSnackBar('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isAnswering = false);
    }
  }

  // --- Export and Sharing ---
  Future<void> _exportPDF() async {
    setState(() => isGeneratingPDF = true);
    try {
      await PDFService.generateAndSharePDF(_updatedNote);
      _showSnackBar('PDF exported successfully!');
    } catch (e) {
      print('Error exporting PDF: $e');
      _showSnackBar('Error exporting PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => isGeneratingPDF = false);
    }
  }

  void _shareNoteText() {
    final title =
        _updatedNote.title.isNotEmpty ? _updatedNote.title : 'EchoNotes';
    final content = _updatedNote.mainContent ?? '';
    final text = '$title\n\n$content';
    Share.share(text, subject: title);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _showSnackBar('$label copied to clipboard');
  }

  Future<void> _updateNoteInFirestore(Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
        .collection('notes')
        .doc(_updatedNote.id)
        .update(updates);

    final doc =
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(_updatedNote.id)
            .get();
    if (mounted) {
      setState(() {
        _updatedNote = Note.fromFirestore(doc);
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    var displayMsg = message;
    if (displayMsg.startsWith('Failed: Exception: ')) {
      displayMsg = displayMsg.replaceFirst('Failed: Exception: ', '');
    } else if (displayMsg.startsWith('Failed: ')) {
      displayMsg = displayMsg.replaceFirst('Failed: ', '');
    } else if (displayMsg.startsWith('Exception: ')) {
      displayMsg = displayMsg.replaceFirst('Exception: ', '');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          displayMsg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13.5),
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Future<void> _retryTranscription() async {
    if (_isRetryingTranscription || _updatedNote.audioUrl == null) return;
    setState(() => _isRetryingTranscription = true);
    _showSnackBar('Retrying audio transcription…');
    try {
      final assemblyAIService = AssemblyAIService();
      final transcript = await assemblyAIService.transcribeAudio(
        _updatedNote.audioUrl!,
      );
      if (!mounted) return;

      if (transcript != null &&
          transcript.trim().isNotEmpty &&
          transcript != '[No speech detected]') {
        final Map<String, dynamic> updates = {
          'transcription': transcript,
        };

        // If title is default, generate smart title via Gemini
        if (_updatedNote.title == 'Voice Note' ||
            _updatedNote.title == 'Voice Recording' ||
            _updatedNote.title.trim().isEmpty) {
          try {
            final smartTitle = await geminiService.generateTitle(transcript);
            if (smartTitle.isNotEmpty) {
              updates['title'] = smartTitle;
            }
          } catch (_) {}
        }

        await _updateNoteInFirestore(updates);
        _showSnackBar('Transcription completed successfully! 🎉');

        // Automatically trigger summary if none exists
        if (_updatedNote.aiSummary == null || _updatedNote.aiSummary!.isEmpty) {
          _generateSummary();
        }
      } else if (transcript == '[No speech detected]') {
        await _updateNoteInFirestore({'transcription': '[No speech detected]'});
        _showSnackBar('Audio transcribed, but no speech was detected.');
      } else {
        _showSnackBar(
          'Transcription failed. Check AssemblyAI configuration or network.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error retrying transcription: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRetryingTranscription = false);
      }
    }
  }

  void _showEditTranscriptionDialog() {
    final TextEditingController editController = TextEditingController(
      text: _updatedNote.transcription ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final wordCount =
                ContentPreviewHelper.countWords(editController.text);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header with badge, title, subtitle, and close icon
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFF6366F1),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Transcription',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? AppColors.darkTextPrimary
                                            : const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Refine lecture text or audio transcript',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF94A3B8),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),

                  // Meta bar with live word counter & reading time
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6366F1,
                            ).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$wordCount WORDS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '~${ContentPreviewHelper.estimateReadingTime(wordCount)} min read',
                          style: GoogleFonts.inter(
                            fontSize: 12,
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

                  const SizedBox(height: 10),

                  // Spacious Editor Field
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkScaffold
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: editController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.65,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            hintText:
                                'Enter or paste the full transcript here...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 15,
                              color:
                                  isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF64748B),
                              side: BorderSide(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFFCBD5E1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final newText = editController.text.trim();
                              if (newText.isNotEmpty) {
                                await _updateNoteInFirestore({
                                  'transcription': newText,
                                });
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                _showSnackBar(
                                  'Transcription updated successfully!',
                                );
                              }
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              'Save Changes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference < 7) {
      return '${difference}d ago at ${_formatTime(date)}';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = _updatedNote.type.toLowerCase() == 'audio';

    // Word count & Reading estimate
    final content = _updatedNote.mainContent?.trim() ?? '';
    final words =
        content.isEmpty
            ? 0
            : content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final readingMin = (words / 200).ceil().clamp(1, 60);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top compact navigation & action header
              _buildTopNavHeader(isDark),

              // Scrollable Note Detail Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      // Title & Metadata Block
                      _buildTitleAndMetadata(
                        isDark,
                        words,
                        readingMin,
                        isAudio,
                      ),

                      const SizedBox(height: 18),

                      // Audio Studio Player (if Audio Note)
                      if (isAudio && _updatedNote.audioUrl != null) ...[
                        _buildAudioStudioPlayer(isDark),
                        const SizedBox(height: 18),
                      ],

                      // Note Content / Transcription Card
                      _buildContentCard(isDark, isAudio),

                      const SizedBox(height: 24),

                      // Unified AI Intelligence Workspace
                      _buildAIIntelligenceWorkspace(isDark),

                      // Safe bottom space
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top Navigation Header ---
  Widget _buildTopNavHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(13),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Center(
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),

          // Note Type Pill Badge
          _updatedNote.type.toLowerCase() == 'audio'
              ? EchoPillBadge.audio(isDark: isDark)
              : EchoPillBadge.text(isDark: isDark),

          // Overflow Actions Menu
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(13),
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
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? AppColors.darkSurface : Colors.white,
              onSelected: (value) {
                if (value == 'export_pdf') {
                  _exportPDF();
                } else if (value == 'share') {
                  _shareNoteText();
                } else if (value == 'copy') {
                  _copyToClipboard(_updatedNote.mainContent ?? '', 'Content');
                } else if (value == 'edit_transcript') {
                  _showEditTranscriptionDialog();
                } else if (value == 'retry_transcription') {
                  _retryTranscription();
                } else if (value == 'move_collection') {
                  _handleMoveToCollection();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'move_collection',
                      child: Row(
                        children: [
                          Icon(
                            Icons.drive_file_move_outlined,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Move to Collection',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_pdf',
                      child: Row(
                        children: [
                          isGeneratingPDF
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                                color: Color(0xFFE11D48),
                              ),
                          const SizedBox(width: 10),
                          Text(
                            isGeneratingPDF
                                ? 'Exporting PDF...'
                                : 'Export as PDF',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Share Note',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Copy Text',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_updatedNote.type.toLowerCase() == 'audio') ...[
                      if (_updatedNote.audioUrl != null &&
                          (_updatedNote.transcription == null ||
                              _updatedNote.transcription!.trim().isEmpty ||
                              _updatedNote.transcription ==
                                  '[No speech detected]'))
                        PopupMenuItem(
                          value: 'retry_transcription',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Retry Transcription',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'edit_transcript',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Edit Transcription',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
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
                  ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMoveToCollection() async {
    final moved = await MoveNoteSheet.show(context, note: _updatedNote);
    if (moved == true) {
      final doc = await FirebaseFirestore.instance
          .collection('notes')
          .doc(_updatedNote.id)
          .get();
      if (mounted && doc.exists) {
        setState(() => _updatedNote = Note.fromFirestore(doc));
      }
    }
  }

  // --- Title and Metadata Section ---
  Widget _buildTitleAndMetadata(
    bool isDark,
    int words,
    int readingMin,
    bool isAudio,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collection Pill
        InkWell(
          onTap: _handleMoveToCollection,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  _updatedNote.isUnfiled
                      ? (isDark
                          ? AppColors.darkBorder.withOpacity(0.5)
                          : const Color(0xFFF1F5F9))
                      : const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _updatedNote.isUnfiled
                        ? (isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0))
                        : const Color(0xFF6366F1).withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _updatedNote.isUnfiled
                      ? Icons.inbox_outlined
                      : Icons.folder_rounded,
                  size: 14,
                  color:
                      _updatedNote.isUnfiled
                          ? (isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B))
                          : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  _updatedNote.isUnfiled
                      ? 'Unfiled • Tap to organize'
                      : (_updatedNote.collectionName ?? 'Collection'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        _updatedNote.isUnfiled
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B))
                            : const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 13,
                  color:
                      _updatedNote.isUnfiled
                          ? (isDark
                              ? AppColors.darkTextMuted
                              : const Color(0xFF94A3B8))
                          : const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ),

        // Title
        SelectableText(
          _updatedNote.title.isNotEmpty ? _updatedNote.title : 'Untitled Note',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            letterSpacing: -0.5,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),

        // Metadata Strip: Date • Word Count • Sentiment Badge
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13.5,
                  color:
                      isDark
                          ? AppColors.darkTextMuted
                          : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(_updatedNote.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (words > 0) ...[
              Text(
                '•',
                style: TextStyle(
                  color:
                      isDark
                          ? AppColors.darkTextMuted
                          : const Color(0xFFCBD5E1),
                ),
              ),
              Text(
                '$words words ($readingMin min)',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                ),
              ),
            ],
            if (_updatedNote.hasSentiment) ...[
              Text(
                '•',
                style: TextStyle(
                  color:
                      isDark
                          ? AppColors.darkTextMuted
                          : const Color(0xFFCBD5E1),
                ),
              ),
              EchoPillBadge.sentiment(_updatedNote.sentiment),
            ],
          ],
        ),
      ],
    );
  }

  // --- Audio Studio Player (Accurate Scrubber, No Fake Waveform) ---
  Widget _buildAudioStudioPlayer(bool isDark) {
    final hasDuration = _totalDuration.inSeconds > 0;
    final progress =
        hasDuration
            ? (_currentPosition.inSeconds / _totalDuration.inSeconds).clamp(
              0.0,
              1.0,
            )
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play / Stop Coral Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  isPlaying ? _stopAudio() : _playAudio();
                },
                child: ScaleTransition(
                  scale:
                      isPlaying
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Audio Info & Scrubber
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPlaying
                              ? 'Playing Audio Recording'
                              : 'Voice Memo Track',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Accurate Scrubber Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF6366F1),
                        inactiveTrackColor:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                        thumbColor: const Color(0xFF8B5CF6),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        overlayColor: const Color(0xFF6366F1).withOpacity(0.15),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (val) {
                          if (hasDuration) {
                            final seekSec =
                                (val * _totalDuration.inSeconds).toInt();
                            _audioPlayer.seek(Duration(seconds: seekSec));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Content & Transcription Card ---
  Widget _buildContentCard(bool isDark, bool isAudio) {
    final title = isAudio ? 'Transcription' : 'Note Content';
    final contentText = _updatedNote.mainContent ?? 'No content available';
    final preview = ContentPreviewHelper.getPreview(contentText, wordLimit: 120);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row with Responsive Utility Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            isAudio
                                ? Icons.transcribe_rounded
                                : Icons.article_outlined,
                            size: 16,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
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
                    if (preview.totalWords > 0 &&
                        (!isAudio ||
                            (_updatedNote.transcription != null &&
                                _updatedNote.transcription!.trim().isNotEmpty)))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${preview.totalWords} words',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Action icons: Listen (TTS), Copy, Edit (if audio)
              if (!isAudio ||
                  (_updatedNote.transcription != null &&
                      _updatedNote.transcription!.trim().isNotEmpty)) ...[
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text-to-speech button
                    IconButton(
                      icon: Icon(
                        _isSpeakingContent
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        color:
                            _isSpeakingContent
                                ? const Color(0xFFEF4444)
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B)),
                        size: 20,
                      ),
                      tooltip:
                          _isSpeakingContent
                              ? 'Stop listening'
                              : 'Listen via TTS',
                      onPressed: _toggleSpeakContent,
                      visualDensity: VisualDensity.compact,
                    ),

                    // Copy button (copies entire full text)
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                        size: 18,
                      ),
                      tooltip: 'Copy text',
                      onPressed: () => _copyToClipboard(contentText, title),
                      visualDensity: VisualDensity.compact,
                    ),

                    // Edit transcription (for audio notes)
                    if (isAudio)
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                          size: 18,
                        ),
                        tooltip: 'Edit transcription',
                        onPressed: _showEditTranscriptionDialog,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Missing / Failed Audio Transcription Pending Banner with Safe Retry
          if (isAudio &&
              (_updatedNote.transcription == null ||
                  _updatedNote.transcription!.trim().isEmpty)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFF6366F1).withOpacity(0.08)
                        : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF6366F1).withOpacity(0.3)
                          : const Color(0xFFC7D2FE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_none_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recording Saved — Transcript Pending',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your audio is safely preserved. Tap below to transcribe or retry processing.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isRetryingTranscription
                              ? null
                              : _retryTranscription,
                      icon:
                          _isRetryingTranscription
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        _isRetryingTranscription
                            ? 'Transcribing audio…'
                            : 'Retry Transcription',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Selectable Body Text (Preview)
            SelectableText(
              preview.previewText,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF1E293B),
              ),
            ),

            // Progressive "Read full transcript/note" Action Button when content exceeds threshold
            if (preview.isTruncated) ...[
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.fullContentReader,
                      arguments: FullContentReaderArgs(
                        noteTitle: _updatedNote.title,
                        contentType:
                            isAudio
                                ? ReaderContentType.transcript
                                : ReaderContentType.textNote,
                        fullText: contentText,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B).withOpacity(0.5)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isAudio
                                  ? Icons.transcribe_rounded
                                  : Icons.article_outlined,
                              size: 16,
                              color: const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isAudio
                                  ? 'Read full transcript'
                                  : 'Read full note',
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
                        Row(
                          children: [
                            Text(
                              '${preview.totalWords} words',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // --- Unified AI Intelligence Workspace ---
  Widget _buildAIIntelligenceWorkspace(bool isDark) {
    if (_updatedNote.mainContent == null) {
      return const SizedBox.shrink();
    }

    final tabs = [
      {'label': 'Summary', 'icon': Icons.auto_awesome_rounded},
      {'label': 'Key Points', 'icon': Icons.checklist_rounded},
      {'label': 'Keywords', 'icon': Icons.tag_rounded},
      {'label': 'Sentiment', 'icon': Icons.mood_rounded},
      {'label': 'Translate', 'icon': Icons.translate_rounded},
      {'label': 'Ask AI', 'icon': Icons.chat_bubble_outline_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workspace Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Intelligence Workspace',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Compact Horizontal Tab Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = _selectedAITab == index;
              final tab = tabs[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAITab = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isSelected
                              ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color:
                          isSelected
                              ? null
                              : isDark
                              ? AppColors.darkSurface
                              : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFF4F46E5)
                                : isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 14,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab['label'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color:
                                isSelected
                                    ? Colors.white
                                    : isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),

        // Tab Content Panel
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildSelectedTabContent(isDark),
        ),
      ],
    );
  }

  // --- Content Switcher for AI Workspace Tabs ---
  Widget _buildSelectedTabContent(bool isDark) {
    switch (_selectedAITab) {
      case 0:
        return _buildSummaryTab(isDark);
      case 1:
        return _buildActionItemsTab(isDark);
      case 2:
        return _buildKeywordsTab(isDark);
      case 3:
        return _buildSentimentTab(isDark);
      case 4:
        return _buildTranslateTab(isDark);
      case 5:
        return _buildAskAITab(isDark);
      default:
        return _buildSummaryTab(isDark);
    }
  }

  // 1. AI Summary Tab
  Widget _buildSummaryTab(bool isDark) {
    final hasSummary =
        _updatedNote.aiSummary != null &&
        _updatedNote.aiSummary!.trim().isNotEmpty;
    final summaryText = _updatedNote.aiSummary ?? '';
    final summaryPreview =
        ContentPreviewHelper.getPreview(summaryText, wordLimit: 80);

    return Container(
      key: const ValueKey('ai_summary_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Executive Summary',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    if (hasSummary && summaryPreview.totalWords > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${summaryPreview.totalWords} words',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasSummary) ...[
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSpeakingSummary
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        color:
                            _isSpeakingSummary
                                ? const Color(0xFFEF4444)
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B)),
                        size: 20,
                      ),
                      tooltip: _isSpeakingSummary ? 'Stop' : 'Listen',
                      onPressed: _toggleSpeakSummary,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                      tooltip: 'Copy summary',
                      onPressed:
                          () => _copyToClipboard(
                            _updatedNote.aiSummary!,
                            'Summary',
                          ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon:
                          isSummarizing
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                      tooltip: 'Regenerate summary',
                      onPressed: isSummarizing ? null : _generateSummary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          if (isSummarizing)
            _buildAILoadingState(
              'Gemini is generating an executive summary...',
              isDark,
            )
          else if (hasSummary) ...[
            SelectableText(
              summaryPreview.previewText,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.6,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF1E293B),
              ),
            ),
            if (summaryPreview.isTruncated) ...[
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.fullContentReader,
                      arguments: FullContentReaderArgs(
                        noteTitle: _updatedNote.title,
                        contentType: ReaderContentType.aiSummary,
                        fullText: summaryText,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B).withOpacity(0.5)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: Color(0xFF8B5CF6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Read full summary',
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
                        Row(
                          children: [
                            Text(
                              '${summaryPreview.totalWords} words',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ] else
            _buildAIEmptyPrompt(
              title: 'No Summary Generated Yet',
              description:
                  'Synthesize key insights and decisions into a crisp executive briefing.',
              buttonText: 'Generate Summary',
              onGenerate: _generateSummary,
              isLoading: isSummarizing,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // 2. Action Items Tab
  Widget _buildActionItemsTab(bool isDark) {
    final hasActions = _updatedNote.hasActionItems;

    return Container(
      key: const ValueKey('ai_actions_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Action Items & Tasks',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              if (hasActions)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                      tooltip: 'Copy action items',
                      onPressed: () {
                        final items =
                            _updatedNote.actionItems
                                ?.map((e) => '• $e')
                                .join('\n') ??
                            '';
                        _copyToClipboard(items, 'Action Items');
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon:
                          isExtracting
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                      tooltip: 'Re-extract action items',
                      onPressed:
                          isExtracting ? null : _extractKeywordsAndActions,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (isExtracting)
            _buildAILoadingState('Extracting tasks and action items...', isDark)
          else if (hasActions)
            Column(
              children:
                  _updatedNote.actionItems!.map((item) {
                    final isChecked = _checkedActionItems.contains(item);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isChecked) {
                                _checkedActionItems.remove(item);
                              } else {
                                _checkedActionItems.add(item);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? AppColors.darkScaffold
                                      : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isChecked
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 19,
                                  color:
                                      isChecked
                                          ? const Color(0xFF10B981)
                                          : (isDark
                                              ? AppColors.darkTextMuted
                                              : const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      height: 1.45,
                                      decoration:
                                          isChecked
                                              ? TextDecoration.lineThrough
                                              : null,
                                      color:
                                          isChecked
                                              ? (isDark
                                                  ? AppColors.darkTextMuted
                                                  : const Color(0xFF94A3B8))
                                              : (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : const Color(0xFF1E293B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            )
          else
            _buildAIEmptyPrompt(
              title: 'No Action Items Extracted',
              description:
                  'Automatically pull deliverables, assignments, and follow-ups.',
              buttonText: 'Extract Action Items',
              onGenerate: _extractKeywordsAndActions,
              isLoading: isExtracting,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // 3. Keywords & Topics Tab
  Widget _buildKeywordsTab(bool isDark) {
    final hasKeywords = _updatedNote.hasKeywords;

    return Container(
      key: const ValueKey('ai_keywords_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Key Topics & Tags',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              if (hasKeywords)
                IconButton(
                  icon:
                      isExtracting
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                  tooltip: 'Re-extract topics',
                  onPressed: isExtracting ? null : _extractKeywordsAndActions,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (isExtracting)
            _buildAILoadingState(
              'Extracting key topics and keywords...',
              isDark,
            )
          else if (hasKeywords)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _updatedNote.keywords!.map((keyword) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF6366F1).withOpacity(0.12)
                                : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF6366F1).withOpacity(0.25)
                                  : const Color(0xFFC7D2FE),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '#',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            keyword,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? const Color(0xFFC7D2FE)
                                      : const Color(0xFF4338CA),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            )
          else
            _buildAIEmptyPrompt(
              title: 'No Keywords Extracted',
              description:
                  'Index critical subjects, terminology, and semantic tags.',
              buttonText: 'Extract Keywords',
              onGenerate: _extractKeywordsAndActions,
              isLoading: isExtracting,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // 4. Sentiment Analysis Tab
  Widget _buildSentimentTab(bool isDark) {
    final hasSentiment = _updatedNote.hasSentiment;

    return Container(
      key: const ValueKey('ai_sentiment_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sentiment & Tone Analysis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
              ),
              if (hasSentiment)
                IconButton(
                  icon:
                      isAnalyzing
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                  tooltip: 'Re-analyze tone',
                  onPressed: isAnalyzing ? null : _analyzeSentiment,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 14),

          if (isAnalyzing)
            _buildAILoadingState(
              'Analyzing emotional tone and polarity...',
              isDark,
            )
          else if (hasSentiment)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _updatedNote.sentimentEmoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Tone: ${_updatedNote.sentiment!.toUpperCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Evaluated from transcription nuance and linguistic expressions.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
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
            )
          else
            _buildAIEmptyPrompt(
              title: 'Sentiment Not Analyzed Yet',
              description:
                  'Detect whether the note conveys a positive, neutral, or constructive tone.',
              buttonText: 'Analyze Sentiment',
              onGenerate: _analyzeSentiment,
              isLoading: isAnalyzing,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // 5. Translations Tab
  Widget _buildTranslateTab(bool isDark) {
    final languages = [
      {'code': 'French', 'flag': '🇫🇷'},
      {'code': 'Spanish', 'flag': '🇪🇸'},
      {'code': 'German', 'flag': '🇩🇪'},
      {'code': 'Yoruba', 'flag': '🇳🇬'},
      {'code': 'Igbo', 'flag': '🇳🇬'},
      {'code': 'Arabic', 'flag': '🇸🇦'},
    ];

    final translatedText = _updatedNote.translations?[_selectedLanguage];
    final hasTranslation = translatedText != null && translatedText.isNotEmpty;

    return Container(
      key: const ValueKey('ai_translate_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Multi-Language Translation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Language Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children:
                  languages.map((lang) {
                    final langName = lang['code']!;
                    final isSelected = _selectedLanguage == langName;
                    final isAvailable =
                        _updatedNote.translations?.containsKey(langName) ??
                        false;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedLanguage = langName);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF6366F1)
                                    : isDark
                                    ? AppColors.darkScaffold
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF4F46E5)
                                      : isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lang['flag']!,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                langName,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? AppColors.darkTextPrimary
                                              : const Color(0xFF0F172A)),
                                ),
                              ),
                              if (isAvailable) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color:
                                      isSelected
                                          ? Colors.white70
                                          : const Color(0xFF10B981),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          if (isTranslating)
            _buildAILoadingState(
              'Translating content to $_selectedLanguage...',
              isDark,
            )
          else if (hasTranslation)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Translation in $_selectedLanguage',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          tooltip: 'Copy translation',
                          onPressed:
                              () => _copyToClipboard(
                                translatedText,
                                '$_selectedLanguage translation',
                              ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                          tooltip: 'Re-translate',
                          onPressed: () => _translateText(_selectedLanguage),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  translatedText,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    height: 1.6,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF1E293B),
                  ),
                ),
              ],
            )
          else
            _buildAIEmptyPrompt(
              title: 'Not Translated to $_selectedLanguage',
              description:
                  'Translate this note seamlessly preserving context and terminology.',
              buttonText: 'Translate to $_selectedLanguage',
              onGenerate: () => _translateText(_selectedLanguage),
              isLoading: isTranslating,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // 6. Ask AI Tab (Conversational Q&A)
  Widget _buildAskAITab(bool isDark) {
    final qaEntries = _updatedNote.qaResults?.entries.toList() ?? [];

    return Container(
      key: const ValueKey('ai_ask_tab'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Text(
            'Ask Note Assistant',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Query factual details, dates, key names, or request expansions.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 16),

          // Question Input Box with Coral Send Button
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask a question about this note...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13.5,
                        color:
                            isDark
                                ? AppColors.darkTextMuted
                                : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      if (!isAnswering) _answerQuestion();
                    },
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: isAnswering ? null : _answerQuestion,
                      child: Center(
                        child:
                            isAnswering
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Q&A Conversation History
          if (qaEntries.isNotEmpty) ...[
            Text(
              'Questions Answered',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            ...qaEntries.reversed.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question bubble
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                entry.key,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Answer bubble
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkScaffold
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              entry.value,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                height: 1.5,
                                color:
                                    isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No questions asked yet. Ask Gemini anything about this note!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color:
                        isDark
                            ? AppColors.darkTextMuted
                            : const Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Widgets for AI States ---
  Widget _buildAILoadingState(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
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
    );
  }

  Widget _buildAIEmptyPrompt({
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onGenerate,
    required bool isLoading,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isLoading ? null : onGenerate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        buttonText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }
}
