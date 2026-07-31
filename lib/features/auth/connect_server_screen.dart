import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/session_controller.dart';

/// PLAN.md Phase 3.1 + 3.7: enter a server URL, validate it's reachable and
/// really is an Audiobookshelf server via `GET /status`, then move on to
/// login. Offline/unreachable states are surfaced inline rather than
/// crashing or hanging.
class ConnectServerScreen extends ConsumerStatefulWidget {
  const ConnectServerScreen({super.key});

  @override
  ConsumerState<ConnectServerScreen> createState() =>
      _ConnectServerScreenState();
}

class _ConnectServerScreenState extends ConsumerState<ConnectServerScreen> {
  final _urlController = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _errorMessage = 'Enter a server address.');
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final (url, status) = await ref
          .read(sessionControllerProvider.notifier)
          .checkServer(rawUrl);

      if (!status.looksLikeAudiobookshelf) {
        setState(
          () => _errorMessage = "That doesn't look like an Audiobookshelf server.",
        );
        return;
      }
      if (!status.isInit) {
        setState(
          () => _errorMessage =
              'This server has no admin account set up yet — finish setup in a browser first.',
        );
        return;
      }

      if (!mounted) return;
      await context.push('/login', extra: url);
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Couldn't reach that server — check the address and your connection.";
      case DioExceptionType.connectionError:
        return "Couldn't connect. Check the address and that the server is online.";
      case DioExceptionType.badResponse:
        return 'Server responded with an error (${e.response?.statusCode}). Check the address.';
      default:
        return "Couldn't reach that server. Check the address and try again.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter your Audiobookshelf server address',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Server address',
                hintText: 'audiobookshelf.example.com',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _continue(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isChecking ? null : _continue,
              child: _isChecking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
