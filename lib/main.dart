import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/share_receiver/services/share_receiver_service.dart';
import 'package:echonotes/services/settings_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode
              ? AppleProvider.appAttestWithDeviceCheckFallback
              : AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('Firebase App Check activation notice: $e');
  }
  await Supabase.initialize(
    url: 'https://tfrphyseflawashlscod.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRmcnBoeXNlZmxhd2FzaGxzY29kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MjU2OTcsImV4cCI6MjA3MTAwMTY5N30.bwlfg7MFqXM7a3wgUgh-_fJO8FP6_aOvXYS2UC4NL7U',
  );
  await SettingsService().init();
  await ShareReceiverService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService().themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: AppRoutes.navigatorKey,
          title: 'EchoNotes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.getRoutes(),
        );
      },
    );
  }
}
