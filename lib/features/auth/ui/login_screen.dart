import 'package:echonotes/features/auth/ui/auth_screen.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialIsSignUp: false);
  }
}
