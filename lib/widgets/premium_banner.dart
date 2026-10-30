import 'package:flutter/material.dart';

/// Paywall removed — this widget is now a no-op stub.
class PremiumBanner extends StatelessWidget {
  final bool isTablet;
  const PremiumBanner({super.key, this.isTablet = false});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
