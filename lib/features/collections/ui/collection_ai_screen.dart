import 'dart:async';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/collection_chat_message.dart';
import 'package:echonotes/features/collections/models/collection_conversation.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collection_ai_service.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive AI Knowledge Workspace for Collection-level search and Q&A.
/// Supports multi-note grounded synthesis, verified source citations, and
/// persistent conversation history.
class CollectionAIScreen extends StatefulWidget {
  final EchoCollection collection;

  const CollectionAIScreen({super.key, required this.collection});

  @override
  State<CollectionAIScreen> createState() => _CollectionAIScreenState();
}

class _CollectionAIScreenState extends State<CollectionAIScreen> {
  final CollectionAIService _aiService = CollectionAIService();
  final CollectionsService _collectionsService = CollectionsService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _activeConversationId;
  bool _isLoading = false;
  String? _errorMessage;
  List<Note> _collectionNotes = [];
  StreamSubscription<List<Note>>? _notesSub;
  final List<CollectionChatMessage> _localMessages = [];

  // Universal study & knowledge starter prompts for any subject
  final List<String> _suggestedPrompts = [
    'What are the core themes and main takeaways across these notes?',
    'Summarize the key concepts and ideas discussed.',
    'Compare the different perspectives or topics covered.',
    'List all practical action items, facts, or instructions mentioned.',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeNotes();
  }

  void _subscribeNotes() {
    final userId = AuthService().getCurrentUser()?.uid ?? '';
    if (userId.isEmpty) return;

    _notesSub = _collectionsService
        .getNotesForCollectionStream(userId, collectionId: widget.collection.id)
        .listen((notes) {
      if (mounted) {
        setState(() {
          _collectionNotes = notes;
        });
      }
    });
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    _questionController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAskQuestion([String? presetQuestion]) async {
    final questionText = (presetQuestion ?? _questionController.text).trim();
    if (questionText.isEmpty || _isLoading) return;

    final userId = AuthService().getCurrentUser()?.uid ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to ask questions.')),
      );
      return;
    }

    if (_collectionNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This collection has no notes or recordings yet. Add notes first!',
          ),
        ),
      );
      return;
    }

    final userMsg = CollectionChatMessage(
      id: 'local_u_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: questionText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _localMessages.add(userMsg);
      _isLoading = true;
      _errorMessage = null;
      if (presetQuestion == null) {
        _questionController.clear();
      }
    });
    _scrollToBottom();

    try {
      final result = await _aiService.askQuestion(
        userId: userId,
        collectionId: widget.collection.id,
        collectionName: widget.collection.name,
        question: questionText,
        conversationId: _activeConversationId,
      );

      final asstMsg = CollectionChatMessage(
        id: (result['messageId'] as String?) ??
            'local_a_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'assistant',
        text: (result['answer'] as String?) ?? '',
        citations: (result['citations'] as List<GroundedCitation>?) ?? [],
        isInsufficientEvidence:
            (result['isInsufficientEvidence'] as bool?) ?? false,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _localMessages.add(asstMsg);
          _activeConversationId = result['conversationId'] as String?;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _startNewConversation() {
    setState(() {
      _localMessages.clear();
      _activeConversationId = null;
      _errorMessage = null;
    });
  }

  void _showConversationsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService().getCurrentUser()?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Past Conversations',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_comment_rounded,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Start New Thread',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _startNewConversation();
                  },
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<CollectionConversation>>(
                    stream: _aiService.getConversationsStream(
                      userId,
                      widget.collection.id,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SpinKitThreeBounce(
                            color: AppColors.primaryLight,
                            size: 24,
                          ),
                        );
                      }
                      final convs = snapshot.data ?? [];
                      if (convs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No conversation history for this collection yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollCtrl,
                        itemCount: convs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conv = convs[index];
                          final isSelected = conv.id == _activeConversationId;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                AppColors.primaryLight.withOpacity(0.08),
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: conv.lastMessage.isNotEmpty
                                ? Text(
                                    conv.lastMessage,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 12.5),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                              ),
                              onPressed: () async {
                                await _aiService.deleteConversation(
                                  userId,
                                  conv.id,
                                );
                                if (_activeConversationId == conv.id) {
                                  _startNewConversation();
                                }
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _activeConversationId = conv.id;
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToNote(String noteId) {
    // Find note in loaded collection notes
    final match = _collectionNotes.firstWhere(
      (n) => n.id == noteId,
      orElse: () => Note(
        id: noteId,
        title: 'Note Reference',
        type: 'audio',
        createdAt: DateTime.now(),
        userId: AuthService().getCurrentUser()?.uid ?? '',
      ),
    );

    Navigator.of(context).pushNamed(AppRoutes.noteDetail, arguments: match);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService().getCurrentUser()?.uid ?? '';
    final themeColor = widget.collection.color;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: themeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.collection.name} AI',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${_collectionNotes.length} notes indexed',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Daily usage queries remaining badge
          StreamBuilder<int>(
            stream: _aiService.getDailyQueriesRemainingStream(userId),
            builder: (context, snapshot) {
              final remaining = snapshot.data ?? CollectionAIService.dailyLimit;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: remaining > 0
                      ? AppColors.primaryLight.withOpacity(0.12)
                      : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: remaining > 0
                        ? AppColors.primaryLight.withOpacity(0.25)
                        : Colors.red.withOpacity(0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$remaining left',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: remaining > 0
                          ? AppColors.primaryLight
                          : Colors.red.shade400,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF64748B),
            onPressed: _showConversationsSheet,
            tooltip: 'Conversation History',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.red,
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),

            // Chat Messages Stream
            Expanded(
              child: _localMessages.isNotEmpty
                  ? ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      itemCount: _localMessages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _localMessages.length) {
                          return _buildThinkingBubble(isDark);
                        }
                        final msg = _localMessages[index];
                        return _buildMessageBubble(msg, isDark);
                      },
                    )
                  : (_activeConversationId == null
                      ? _buildEmptyState(isDark)
                      : StreamBuilder<List<CollectionChatMessage>>(
                          stream: _aiService.getMessagesStream(
                            userId,
                            _activeConversationId!,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SpinKitThreeBounce(
                                  color: AppColors.primaryLight,
                                  size: 24,
                                ),
                              );
                            }

                            final messages = snapshot.data ?? [];
                            if (messages.isEmpty && !_isLoading) {
                              return _buildEmptyState(isDark);
                            }

                            return ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: messages.length + (_isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= messages.length) {
                                  return _buildThinkingBubble(isDark);
                                }
                                final msg = messages[index];
                                return _buildMessageBubble(msg, isDark);
                              },
                            );
                          },
                        )),
            ),

            // Input Bar
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.collection.color.withOpacity(0.2),
                  AppColors.primaryLight.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_rounded,
              size: 48,
              color: widget.collection.color,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ask ${widget.collection.name}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Synthesize lessons, compare topics, and trace key concepts across all ${_collectionNotes.length} notes with verified citations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGGESTED QUESTIONS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._suggestedPrompts.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleAskQuestion(prompt),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDark ? 0.2 : 0.03,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 17,
                          color: widget.collection.color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            prompt,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 48),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.collection.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SpinKitPulse(color: widget.collection.color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Searching collection transcripts...',
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
                  'BM25 ranking and Gemini synthesis in progress',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
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
    );
  }

  Widget _buildMessageBubble(CollectionChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.collection.color.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: widget.collection.color,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryLight
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.displayText,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isUser
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A)),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Insufficient evidence notice
          if (!isUser && msg.isInsufficientEvidence) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 36),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Information not fully covered in this collection.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Verified Citations
          if (!isUser && msg.citations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                'VERIFIED EVIDENCE (${msg.citations.length})',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                children: msg.citations.map((c) {
                  return _buildCitationCard(c, isDark);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationCard(GroundedCitation citation, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withOpacity(0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToNote(citation.noteId),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10B981),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        citation.noteTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
                if (citation.snippet.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${citation.snippet}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkScaffold
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: TextField(
                controller: _questionController,
                focusNode: _focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleAskQuestion(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about ${_collectionNotes.length} notes...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.collection.color,
                  AppColors.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.collection.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
              onPressed: _isLoading ? null : () => _handleAskQuestion(),
            ),
          ),
        ],
      ),
    );
  }
}
