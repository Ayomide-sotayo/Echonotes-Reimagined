import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:echonotes/features/collections/ui/widgets/create_edit_collection_dialog.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom sheet allowing users to move a note to any collection,
/// remove it to Unfiled, or create a new collection on the fly.
class MoveNoteSheet extends StatefulWidget {
  final Note note;

  const MoveNoteSheet({super.key, required this.note});

  static Future<bool?> show(BuildContext context, {required Note note}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => MoveNoteSheet(note: note),
    );
  }

  @override
  State<MoveNoteSheet> createState() => _MoveNoteSheetState();
}

class _MoveNoteSheetState extends State<MoveNoteSheet> {
  final CollectionsService _collectionsService = CollectionsService();
  bool _isMoving = false;

  Future<void> _selectCollection({String? collectionId, String? collectionName}) async {
    setState(() => _isMoving = true);
    HapticFeedback.mediumImpact();

    try {
      await _collectionsService.moveNoteToCollection(
        noteId: widget.note.id,
        collectionId: collectionId,
        collectionName: collectionName,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    collectionName != null && collectionName.isNotEmpty
                        ? 'Moved to "$collectionName"'
                        : 'Moved to Unfiled',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move note: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateAndAssign() async {
    final newCollection = await CreateEditCollectionDialog.show(context);
    if (newCollection != null && mounted) {
      await _selectCollection(
        collectionId: newCollection.id,
        collectionName: newCollection.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = AuthService().getCurrentUser()?.uid ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.drive_file_move_outlined,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move Note',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        widget.note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 18),

            // Destination list
            Flexible(
              child: StreamBuilder<List<EchoCollection>>(
                stream: _collectionsService.getCollectionsStream(userId),
                builder: (context, snapshot) {
                  final collections = snapshot.data ?? [];
                  final isNoteUnfiled = widget.note.isUnfiled;

                  return ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // "Unfiled" Option
                      _buildCollectionTile(
                        title: 'Unfiled Notes',
                        subtitle: 'Keep note outside any collection',
                        iconData: Icons.inbox_rounded,
                        color: const Color(0xFF64748B),
                        isSelected: isNoteUnfiled,
                        isDark: isDark,
                        onTap:
                            isNoteUnfiled || _isMoving
                                ? null
                                : () => _selectCollection(
                                  collectionId: null,
                                  collectionName: null,
                                ),
                      ),
                      const Divider(height: 16, thickness: 0.5),

                      // User's Collections
                      ...collections.map((col) {
                        final isSelected = widget.note.collectionId == col.id;
                        return _buildCollectionTile(
                          title: col.name,
                          subtitle: '${col.noteCount} notes',
                          iconData: col.iconData,
                          color: col.color,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap:
                              isSelected || _isMoving
                                  ? null
                                  : () => _selectCollection(
                                    collectionId: col.id,
                                    collectionName: col.name,
                                  ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // Create New Collection button
                      InkWell(
                        onTap: _isMoving ? null : _handleCreateAndAssign,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
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
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(
                                    0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Create New Collection',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTile({
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color color,
    required bool isSelected,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color:
            isSelected
                ? color.withOpacity(0.12)
                : (isDark ? AppColors.darkScaffold : Colors.white),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isSelected
                        ? color.withOpacity(0.4)
                        : (isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFF1F5F9)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
