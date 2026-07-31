import 'package:flutter/material.dart';

/// Placeholder for username/password login (PLAN.md Phase 3.2). Real
/// implementation lands in Phase 3.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: const Center(child: Text('Log In — coming in Phase 3')),
    );
  }
}
