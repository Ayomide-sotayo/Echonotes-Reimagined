import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/collections/ui/collections_screen.dart';
import 'package:echonotes/features/notes/ui/home_screen.dart';
import 'package:echonotes/features/notes/ui/notes_screen.dart';
import 'package:echonotes/features/notes/ui/profile_screen.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Widget> get _screens => [
    HomeScreen(
      onViewAll: () => _onItemTapped(1),
      onSearch: () => _onItemTapped(1),
      onProfile: () => _onItemTapped(3),
    ),
    const NotesScreen(),
    const CollectionsScreen(),
    const ProfileScreen(),
  ];

  // Clean minimal outline icons matching the reference image style
  final List<IconData> _inactiveIcons = [
    Icons.home_outlined,
    Icons.description_outlined,
    Icons.folder_outlined,
    Icons.person_outline_rounded,
  ];

  final List<IconData> _activeIcons = [
    Icons.home_rounded,
    Icons.description_rounded,
    Icons.folder_rounded,
    Icons.person_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    ShareReceiverService().pendingAudioNotifier.addListener(_onPendingAudioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingShareAudio();
    });
  }

  void _onPendingAudioChanged() {
    _checkPendingShareAudio();
  }

  void _checkPendingShareAudio() {
    if (!mounted) return;
    final pending = ShareReceiverService().currentPending;
    if (pending != null && !ShareReceiverService().isImportScreenActive) {
      Navigator.of(context).pushNamed(
        AppRoutes.shareImport,
        arguments: pending,
      );
    }
  }

  @override
  void dispose() {
    ShareReceiverService().pendingAudioNotifier.removeListener(_onPendingAudioChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 28, right: 28, bottom: 16),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                _inactiveIcons.length,
                (index) => _buildNavItem(index, isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, bool isDark) {
    final isSelected = _selectedIndex == index;

    // Accessible tap target: minimum 48px width and full dock height (58px)
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.accentCoral.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              scale: isSelected ? 1.08 : 1.0,
              child:
                  isSelected
                      ? ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                        child: Icon(
                          _activeIcons[index],
                          size: 23,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        _inactiveIcons[index],
                        size: 23,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E293B),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
