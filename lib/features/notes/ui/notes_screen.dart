import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/components/echo_pill_badge.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/ui/widgets/move_note_sheet.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  final AuthService authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isSearchActive = false;

  final List<String> _filterOptions = ['All', 'Audio', 'Text', 'Unfiled'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (_searchQuery != query ||
          _isSearchActive != _searchController.text.isNotEmpty) {
        setState(() {
          _searchQuery = query;
          _isSearchActive = _searchController.text.isNotEmpty;
        });
      }
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = [
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
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  // Delete note function
  Future<void> _deleteNote(Note note) async {
    try {
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(note.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Note "${note.title}" deleted',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to delete note: $e',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        );
      }
    }
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(Note note) async {
    HapticFeedback.lightImpact();
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Delete Note',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this note? This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    note.type.toLowerCase() == 'audio'
                        ? EchoPillBadge.audio(isDark: isDark)
                        : EchoPillBadge.text(isDark: isDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note.title.isNotEmpty ? note.title : 'Untitled Note',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteNote(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.getCurrentUser();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                user == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('notes')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
            builder: (context, snapshot) {
              final rawNotes =
                  snapshot.hasData
                      ? snapshot.data!.docs
                          .map((doc) => Note.fromFirestore(doc))
                          .toList()
                      : <Note>[];

              // Filter by search query
              var filteredNotes = rawNotes;
              if (_searchQuery.isNotEmpty) {
                filteredNotes =
                    filteredNotes.where((note) {
                      final titleMatch = note.title.toLowerCase().contains(
                        _searchQuery,
                      );
                      final summaryMatch =
                          note.summary?.toLowerCase().contains(_searchQuery) ??
                          false;
                      final contentMatch =
                          note.mainContent?.toLowerCase().contains(
                            _searchQuery,
                          ) ??
                          false;
                      return titleMatch || summaryMatch || contentMatch;
                    }).toList();
              }

              // Filter by type or unfiled
              if (_selectedFilter == 'Audio' || _selectedFilter == 'Text') {
                filteredNotes =
                    filteredNotes
                        .where(
                          (note) =>
                              note.type.toLowerCase() ==
                              _selectedFilter.toLowerCase(),
                        )
                        .toList();
              } else if (_selectedFilter == 'Unfiled') {
                filteredNotes =
                    filteredNotes.where((note) => note.isUnfiled).toList();
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Editorial Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                      child: _buildEditorialHeader(rawNotes.length, isDark),
                    ),
                  ),

                  // Compact Search and Filter Controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: _buildSearchAndFilter(isDark),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Note List / Loading / Error / Empty states
                  _buildContentSliver(
                    user: user,
                    snapshot: snapshot,
                    notes: filteredNotes,
                    totalCount: rawNotes.length,
                    isDark: isDark,
                  ),

                  // Bottom padding ensuring complete clearance above floating dock & FAB
                  if (filteredNotes.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              );
            },
          ),
        ),
      ),
      // Floating Action Button positioned safely above the floating dock
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96, right: 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.newNote);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Note',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEditorialHeader(int totalCount, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Notes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              totalCount == 0
                  ? 'No notes in library'
                  : '$totalCount ${totalCount == 1 ? 'note' : 'notes'} indexed & synced',
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
        // Compact Quick Action with studio coral badge & premium slate text
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.035),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.newNote);
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'New',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sleek, compact search field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  _isSearchActive
                      ? const Color(0xFF6366F1).withOpacity(0.55)
                      : isDark
                      ? AppColors.darkBorder
                      : const Color(0xFFE2E8F0),
              width: _isSearchActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search notes, summaries, or content...',
              hintStyle: GoogleFonts.inter(
                color:
                    isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color:
                    _isSearchActive
                        ? const Color(0xFFE11D48)
                        : isDark
                        ? AppColors.darkTextMuted
                        : const Color(0xFF94A3B8),
                size: 20,
              ),
              suffixIcon:
                  _isSearchActive
                      ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Filter chips row
        Row(
          children:
              _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedFilter != filter) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7.5,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6),
                                  ],
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFF6366F1)
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
                                    ).withOpacity(0.24),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filter == 'Audio') ...[
                            Icon(
                              Icons.mic_rounded,
                              size: 13.5,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                          ] else if (filter == 'Text') ...[
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14.5,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                          ] else if (filter == 'Unfiled') ...[
                            Icon(
                              Icons.inbox_outlined,
                              size: 13.5,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            filter,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
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
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildContentSliver({
    required dynamic user,
    required AsyncSnapshot<QuerySnapshot> snapshot,
    required List<Note> notes,
    required int totalCount,
    required bool isDark,
  }) {
    if (user == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: _buildEmptyState(
            title: 'Sign in to View Notes',
            subtitle:
                'Please log in to synchronize and organize your notes library.',
            icon: Icons.lock_outline_rounded,
            isDark: isDark,
            actionLabel: null,
            onAction: null,
          ),
        ),
      );
    }

    if (snapshot.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: _buildEmptyState(
            title: 'Unable to Load Notes',
            subtitle:
                'An unexpected connection error occurred. Please check your network and try again.',
            icon: Icons.error_outline_rounded,
            isDark: isDark,
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE11D48),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading notes library...',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color:
                        isDark
                            ? AppColors.darkTextMuted
                            : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (notes.isEmpty) {
      if (_searchQuery.isNotEmpty || _selectedFilter != 'All') {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: _buildEmptyState(
              title: 'No Matching Notes',
              subtitle:
                  'No notes match your current search or filter criteria.',
              icon: Icons.search_off_rounded,
              isDark: isDark,
              actionLabel: 'Clear Filters',
              isSecondaryAction: true,
              onAction: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearchActive = false;
                  _selectedFilter = 'All';
                });
              },
            ),
          ),
        );
      }

      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: _buildEmptyState(
            title: 'Your Library is Empty',
            subtitle:
                'Capture your first thought, voice memo, or meeting transcription to get started.',
            icon: Icons.note_alt_outlined,
            isDark: isDark,
            actionLabel: 'Create First Note',
            onAction: () => Navigator.pushNamed(context, AppRoutes.newNote),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final note = notes[index];
          return _buildScannableNoteCard(note, isDark);
        }, childCount: notes.length),
      ),
    );
  }

  Widget _buildScannableNoteCard(Note note, bool isDark) {
    final isAudio = note.type.toLowerCase() == 'audio';
    final previewText =
        note.aiSummary ?? note.mainContent ?? 'No content preview';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(note.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFECACA), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          await _showDeleteConfirmation(note);
          return false; // Dialog handles Firestore delete
        },
        child: Container(
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(
                  context,
                  AppRoutes.noteDetail,
                  arguments: note,
                );
              },
              borderRadius: BorderRadius.circular(18),
              splashColor: const Color(0xFF6366F1).withOpacity(0.06),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metadata & Badges Row
                    Row(
                      children: [
                        isAudio
                            ? EchoPillBadge.audio(isDark: isDark)
                            : EchoPillBadge.text(isDark: isDark),
                        const SizedBox(width: 8),
                        if (note.sentiment != null &&
                            note.sentiment!.isNotEmpty) ...[
                          EchoPillBadge.sentiment(note.sentiment),
                          const SizedBox(width: 8),
                        ],
                        if (note.aiSummary != null &&
                            note.aiSummary!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.12),
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
                                  'AI',
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
                        if (note.collectionName != null &&
                            note.collectionName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.folder_rounded,
                                  size: 11,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  note.collectionName!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatRelativeDate(note.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColors.darkTextMuted
                                    : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quick Move Icon Button
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => MoveNoteSheet.show(context, note: note),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.drive_file_move_outlined,
                              size: 18,
                              color:
                                  isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Quick Delete Icon Button
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showDeleteConfirmation(note),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color:
                                  isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Note Title
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isNotEmpty
                                ? note.title
                                : 'Untitled Note',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color:
                              isDark
                                  ? AppColors.darkTextMuted
                                  : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Concise Preview
                    Text(
                      previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.45,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required String? actionLabel,
    required VoidCallback? onAction,
    bool isSecondaryAction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 70),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  isDark
                      ? const Color(0xFF6366F1).withOpacity(0.12)
                      : const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isDark
                        ? const Color(0xFF6366F1).withOpacity(0.25)
                        : const Color(0xFFC7D2FE).withOpacity(0.7),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color:
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            if (isSecondaryAction)
              // Calmer, duller rose button for Clear Filters
              Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF6366F1).withOpacity(0.12)
                          : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF6366F1).withOpacity(0.28)
                            : const Color(0xFFC7D2FE),
                    width: 1.1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color:
                                isDark
                                    ? const Color(0xFFA5B4FC)
                                    : const Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            actionLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color:
                                  isDark
                                      ? const Color(0xFFA5B4FC)
                                      : const Color(0xFF4F46E5),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 11,
                      ),
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
