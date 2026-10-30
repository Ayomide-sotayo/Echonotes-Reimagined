import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/components/echo_pill_badge.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:echonotes/features/collections/ui/widgets/create_edit_collection_dialog.dart';
import 'package:echonotes/features/collections/ui/widgets/move_note_sheet.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Screen displaying all notes belonging to a specific EchoCollection,
/// with search, collection editing, note unfiling, and deletion safeguards.
class CollectionDetailScreen extends StatefulWidget {
  final EchoCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final CollectionsService _collectionsService = CollectionsService();
  late EchoCollection _currentCollection;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentCollection = widget.collection;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleEditCollection() async {
    final updated = await CreateEditCollectionDialog.show(
      context,
      collection: _currentCollection,
    );
    if (updated != null && mounted) {
      setState(() => _currentCollection = updated);
    }
  }

  Future<void> _handleDeleteCollection() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
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
                  'Delete Collection?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
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
                'Are you sure you want to delete "${_currentCollection.name}"?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your notes will NOT be deleted. They will safely remain in your library under Unfiled.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                          height: 1.35,
                        ),
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
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final userId = AuthService().getCurrentUser()?.uid ?? '';
      try {
        await _collectionsService.deleteCollection(
          collectionId: _currentCollection.id,
          userId: userId,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Collection deleted. Notes preserved in Unfiled.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
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
              content: Text('Failed to delete collection: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService().getCurrentUser()?.uid ?? '';
    final themeColor = _currentCollection.color;

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
            color:
                isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentCollection.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, size: 21),
            color: themeColor,
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.collectionAI,
                arguments: _currentCollection,
              );
            },
            tooltip: 'Ask Collection AI',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 21),
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            onPressed: _handleEditCollection,
            tooltip: 'Edit Collection',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            onPressed: _handleDeleteCollection,
            tooltip: 'Delete Collection',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Note>>(
          stream: _collectionsService.getNotesForCollectionStream(
            userId,
            collectionId: _currentCollection.id,
          ),
          builder: (context, snapshot) {
            final allNotes = snapshot.data ?? [];
            final filteredNotes =
                _searchQuery.isEmpty
                    ? allNotes
                    : allNotes.where((note) {
                      final q = _searchQuery.toLowerCase();
                      return note.title.toLowerCase().contains(q) ||
                          (note.summary?.toLowerCase().contains(q) ?? false) ||
                          (note.transcription?.toLowerCase().contains(q) ??
                              false);
                    }).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Collection Banner Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.25 : 0.04,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: themeColor.withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  _currentCollection.iconData,
                                  color: themeColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentCollection.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDark
                                                ? AppColors.darkTextPrimary
                                                : const Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${allNotes.length} ${allNotes.length == 1 ? 'note' : 'notes'} organized',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_currentCollection.description != null &&
                              _currentCollection.description!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _currentCollection.description!,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.collectionAI,
                                  arguments: _currentCollection,
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      themeColor.withOpacity(0.18),
                                      AppColors.primaryLight.withOpacity(0.10),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: themeColor.withOpacity(0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ask Collection AI',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppColors.darkTextPrimary
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Synthesize & search across ${allNotes.length} notes',
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
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 13,
                                      color: themeColor,
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

                // Search Bar within Collection
                if (allNotes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search notes in this collection…',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13.5,
                              color:
                                  isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 19,
                              color:
                                  isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 17),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // Note List or Empty State
                if (allNotes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(isDark, themeColor),
                  )
                else if (filteredNotes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No notes match "$_searchQuery"',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = filteredNotes[index];
                          return _buildNoteCard(note, isDark, themeColor);
                        },
                        childCount: filteredNotes.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color themeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentCollection.iconData,
                color: themeColor,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notes in this collection yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color:
                    isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Move existing notes from your library or import shared audio directly into ${_currentCollection.name}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Collections'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note, bool isDark, Color themeColor) {
    final isAudio = note.type.toLowerCase() == 'audio';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.noteDetail,
              arguments: note,
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Type Pill & Menu
                Row(
                  children: [
                    isAudio
                        ? EchoPillBadge.audio(isDark: isDark)
                        : EchoPillBadge.text(isDark: isDark),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      onSelected: (action) async {
                        if (action == 'move') {
                          await MoveNoteSheet.show(context, note: note);
                        } else if (action == 'remove') {
                          await _collectionsService.removeNoteFromCollection(note.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Moved "${note.title}" to Unfiled'),
                                backgroundColor: const Color(0xFF0F172A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'move',
                          child: Row(
                            children: [
                              const Icon(Icons.drive_file_move_outlined, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'Move to another collection',
                                style: GoogleFonts.inter(fontSize: 13.5),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.folder_off_outlined, size: 18, color: Colors.orange),
                              const SizedBox(width: 10),
                              Text(
                                'Remove to Unfiled',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Note Title
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

                // Note Preview text
                if (note.mainContent != null && note.mainContent!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.mainContent!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Footer row: date & sentiment
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(note.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (note.hasSentiment) ...[
                      const SizedBox(width: 10),
                      Text(note.sentimentEmoji, style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }
}
