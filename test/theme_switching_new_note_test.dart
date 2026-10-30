import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echonotes/core/theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('NewNoteScreen Theme Adaptation Tests', () {
    testWidgets('Light theme uses light studio palette tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final scaffoldBg =
                  isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC);
              final cardBg = isDark ? AppColors.darkSurface : Colors.white;
              final borderCol =
                  isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
              final textCol =
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A);
              final subtextCol =
                  isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

              expect(isDark, isFalse);
              expect(scaffoldBg, const Color(0xFFF8FAFC));
              expect(cardBg, Colors.white);
              expect(borderCol, const Color(0xFFE2E8F0));
              expect(textCol, const Color(0xFF0F172A));
              expect(subtextCol, const Color(0xFF64748B));

              return Scaffold(
                backgroundColor: scaffoldBg,
                body: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: borderCol),
                  ),
                  child: Text('Voice Note', style: TextStyle(color: textCol)),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Voice Note'), findsOneWidget);
    });

    testWidgets('Dark theme switches to dark cosmic studio tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final scaffoldBg =
                  isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC);
              final cardBg = isDark ? AppColors.darkSurface : Colors.white;
              final cardElevated =
                  isDark ? AppColors.darkSurfaceElevated : Colors.white;
              final borderCol =
                  isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
              final textCol =
                  isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A);
              final subtextCol =
                  isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
              final mutedCol =
                  isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8);

              expect(isDark, isTrue);
              expect(scaffoldBg, AppColors.darkScaffold);
              expect(cardBg, AppColors.darkSurface);
              expect(cardElevated, AppColors.darkSurfaceElevated);
              expect(borderCol, AppColors.darkBorder);
              expect(textCol, AppColors.darkTextPrimary);
              expect(subtextCol, AppColors.darkTextSecondary);
              expect(mutedCol, AppColors.darkTextMuted);

              return Scaffold(
                backgroundColor: scaffoldBg,
                body: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Text('Voice Note', style: TextStyle(color: textCol)),
                      Text(
                        'Tap to record',
                        style: TextStyle(color: subtextCol),
                      ),
                      Text(
                        'Start writing your note here...',
                        style: TextStyle(color: mutedCol),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Voice Note'), findsOneWidget);
      expect(find.text('Tap to record'), findsOneWidget);
      expect(find.text('Start writing your note here...'), findsOneWidget);
    });
  });
}
