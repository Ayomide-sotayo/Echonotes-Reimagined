import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/auth/logic/auth_services.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/services/collections_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal bottom sheet for creating or editing an EchoCollection.
class CreateEditCollectionDialog extends StatefulWidget {
  final EchoCollection? collection; // null if creating, populated if editing

  const CreateEditCollectionDialog({super.key, this.collection});

  static Future<EchoCollection?> show(
    BuildContext context, {
    EchoCollection? collection,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<EchoCollection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => CreateEditCollectionDialog(collection: collection),
    );
  }

  @override
  State<CreateEditCollectionDialog> createState() =>
      _CreateEditCollectionDialogState();
}

class _CreateEditCollectionDialogState
    extends State<CreateEditCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late int _selectedColor;
  late String _selectedIcon;
  bool _isSaving = false;

  bool get _isEditing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.collection?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.collection?.description ?? '',
    );
    _selectedColor =
        widget.collection?.colorHex ?? EchoCollection.presetColors.first;
    _selectedIcon = widget.collection?.icon ?? 'folder';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = AuthService().getCurrentUser()?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save collections.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isEditing) {
        await CollectionsService().updateCollection(
          collectionId: widget.collection!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _selectedIcon,
          colorHex: _selectedColor,
        );
        if (mounted) {
          Navigator.of(context).pop(
            widget.collection!.copyWith(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              icon: _selectedIcon,
              colorHex: _selectedColor,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } else {
        final newCollection = await CollectionsService().createCollection(
          userId: userId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _selectedIcon,
          colorHex: _selectedColor,
        );
        if (mounted) {
          Navigator.of(context).pop(newCollection);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving collection: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: 24 + keyboardPadding,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
              const SizedBox(height: 18),

              // Title row with icon preview
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(_selectedColor).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Color(_selectedColor).withOpacity(0.32),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      EchoCollection.presetIcons[_selectedIcon] ??
                          Icons.folder_rounded,
                      color: Color(_selectedColor),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Collection' : 'New Collection',
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
                          _isEditing
                              ? 'Update name, theme & icon'
                              : 'Group your related notes & audio recordings',
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
              const SizedBox(height: 22),

              // Name input
              Text(
                'Collection Name',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., Theology School, Work Meetings',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color:
                        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor:
                      isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a collection name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description input (optional)
              Text(
                'Description (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Add an optional topic overview or study goals…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color:
                        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor:
                      isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Color Palette Picker
              Text(
                'Collection Theme Color',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children:
                      EchoCollection.presetColors.map((colorValue) {
                        final isSelected = _selectedColor == colorValue;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = colorValue);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Color(colorValue).withOpacity(0.55),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child:
                                isSelected
                                    ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                    : null,
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Icon Picker
              Text(
                'Collection Icon',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children:
                      EchoCollection.presetIcons.entries.map((entry) {
                        final isSelected = _selectedIcon == entry.key;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIcon = entry.key);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Color(_selectedColor).withOpacity(0.18)
                                      : (isDark
                                          ? AppColors.darkScaffold
                                          : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Color(_selectedColor)
                                        : (isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Icon(
                              entry.value,
                              size: 20,
                              color:
                                  isSelected
                                      ? Color(_selectedColor)
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF64748B)),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 26),

              // Action buttons (Cancel & Save)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color:
                              isDark
                                  ? AppColors.darkTextSecondary
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSaving ? null : _handleSave,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Text(
                                        _isEditing
                                            ? 'Save Changes'
                                            : 'Create Collection',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
