import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:echonotes/services/assembly_ai_services.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AssemblyAIService Key Loading & Redaction Tests', () {
    test('Resolves empty string gracefully when no keys are set', () {
      dotenv.clean();
      dotenv.loadFromString(envString: '', isOptional: true);
      final service = AssemblyAIService();
      expect(service.apiKey, '');
    });

    test('Resolves ASSEMBLY_AI_KEY from dotenv', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'ASSEMBLY_AI_KEY=test_key_12345');
      final service = AssemblyAIService();
      expect(service.apiKey, 'test_key_12345');
    });

    test('Resolves ASSEMBLYAI_API_KEY as standard fallback', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'ASSEMBLYAI_API_KEY=standard_aai_key');
      final service = AssemblyAIService();
      expect(service.apiKey, 'standard_aai_key');
    });

    test('Resolves ASSEMBLY_AI_API_KEY as alternate fallback', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'ASSEMBLY_AI_API_KEY=alternate_aai_key');
      final service = AssemblyAIService();
      expect(service.apiKey, 'alternate_aai_key');
    });

    test('Trims whitespace from configured keys', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'ASSEMBLY_AI_KEY=   trimmed_key   ');
      final service = AssemblyAIService();
      expect(service.apiKey, 'trimmed_key');
    });
  });

  group('Responsive Summary & Content Header Widget Tests', () {
    Widget buildTestHeader({
      required double containerWidth,
      required String title,
      required int wordCount,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: containerWidth,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The responsive header pattern implemented in NoteDetailScreen
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
                                title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (wordCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.grey.shade200,
                                  ),
                                  child: Text(
                                    '$wordCount words',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, size: 20),
                              onPressed: () {},
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {},
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              onPressed: () {},
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Narrow Samsung phone width (320dp) renders without right overflow',
      (tester) async {
        // 320dp is the narrowest common Android viewport
        tester.view.physicalSize = const Size(320 * 2, 640 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestHeader(
            containerWidth: 320,
            title: 'Executive Summary',
            wordCount: 84,
          ),
        );
        await tester.pumpAndSettle();

        // Verify all 3 action buttons are present and visible
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.text('Executive Summary'), findsOneWidget);
        expect(find.text('84 words'), findsOneWidget);

        // Ensure zero Flutter overflow errors were emitted
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Standard Android phone width (360dp) renders cleanly without right overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2.75, 800 * 2.75);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestHeader(
            containerWidth: 360,
            title: 'Executive Summary',
            wordCount: 120,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.text('Executive Summary'), findsOneWidget);
        expect(find.text('120 words'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Large font scaling / accessibility text scales smoothly without right overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2.5, 760 * 2.5);
        tester.view.devicePixelRatio = 2.5;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: buildTestHeader(
              containerWidth: 340,
              title: 'Executive Summary',
              wordCount: 250,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
