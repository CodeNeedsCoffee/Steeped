import 'package:flutter/material.dart';

/// Bootstrap screen shown while startup state (saved server/session) is
/// checked. Phase 3 wires real navigation logic; this is a placeholder.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
