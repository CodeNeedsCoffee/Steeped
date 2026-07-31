import 'package:flutter/material.dart';

/// Placeholder for "Connect to Server" (PLAN.md Phase 3.1) — enter a server
/// URL and validate reachability. Real implementation lands in Phase 3.
class ConnectServerScreen extends StatelessWidget {
  const ConnectServerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server')),
      body: const Center(child: Text('Connect to Server — coming in Phase 3')),
    );
  }
}
