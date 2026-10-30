import 'package:echonotes/features/auth/ui/login_screen.dart';
import 'package:echonotes/features/auth/ui/signup_screen.dart';
import 'package:echonotes/features/legal/ui/legal_terms_privacy_screen.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/features/notes/ui/main_app_screen.dart';
import 'package:echonotes/features/onboarding/ui/onboarding_screen.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:echonotes/features/share_receiver/ui/share_import_screen.dart';
import 'package:echonotes/features/splash/ui/splash_screen.dart';
import 'package:echonotes/features/notes/ui/note_detail_screen.dart';
import 'package:echonotes/features/notes/ui/full_content_reader_screen.dart';
import 'package:echonotes/widgets/new_note_screen.dart';
import 'package:flutter/material.dart';

import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/collections/ui/collection_ai_screen.dart';
import 'package:echonotes/features/collections/ui/collection_detail_screen.dart';
import 'package:echonotes/features/collections/ui/collections_screen.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String newNote = '/new_note';
  static const String noteDetail = '/note_detail';
  static const String onBoarding = '/onboarding';
  static const String legalTermsPrivacy = '/legal';
  static const String shareImport = '/share_import';
  static const String collections = '/collections';
  static const String collectionDetail = '/collection_detail';
  static const String collectionAI = '/collection_ai';
  static const String fullContentReader = '/full_content_reader';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignupScreen(),
      home: (context) => const MainAppScreen(),
      collections: (context) => const CollectionsScreen(),
      collectionDetail: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as EchoCollection;
        return CollectionDetailScreen(collection: args);
      },
      collectionAI: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as EchoCollection;
        return CollectionAIScreen(collection: args);
      },
      legalTermsPrivacy: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final initialTab = (args is int) ? args : 0;
        return LegalTermsPrivacyScreen(initialTabIndex: initialTab);
      },
      newNote: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map<String, dynamic>) {
          return NewNoteScreen(
            initialAudioPath: args['initialAudioPath'] as String?,
          );
        } else if (args is String) {
          return NewNoteScreen(initialAudioPath: args);
        }
        return const NewNoteScreen();
      },
      onBoarding: (context) => const OnboardingScreen(),
      noteDetail: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Note;
        return NoteDetailScreen(note: args);
      },
      fullContentReader: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as FullContentReaderArgs;
        return FullContentReaderScreen(
          noteTitle: args.noteTitle,
          contentType: args.contentType,
          fullText: args.fullText,
        );
      },
      shareImport: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is SharedAudioPayload) {
          return ShareImportScreen(payload: args);
        }
        final pending = ShareReceiverService().currentPending;
        if (pending != null) {
          return ShareImportScreen(payload: pending);
        }
        return const Scaffold(
          body: Center(child: Text('No shared audio found.')),
        );
      },
    };
  }
}

