import 'package:flutter/material.dart';

/// Placeholder for the post-login home shell (library browsing, Phase 4;
/// mini-player, Phase 5). Real implementation lands in those phases.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Steeped')),
      body: const Center(child: Text('Home — coming in Phases 4 & 5')),
    );
  }
}
