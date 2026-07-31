import 'package:flutter/material.dart';

/// Placeholder for Settings (PLAN.md Phase 9.3). Real implementation lands
/// in Milestone 2; an Appearance/skin section is added in Milestone 3.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings — coming in Milestone 2')),
    );
  }
}
