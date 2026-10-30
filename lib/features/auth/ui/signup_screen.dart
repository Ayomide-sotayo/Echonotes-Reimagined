import 'package:echonotes/features/auth/ui/auth_screen.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialIsSignUp: true);
  }
}
