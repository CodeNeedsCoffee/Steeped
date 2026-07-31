import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/session_controller.dart';

/// PLAN.md Phase 3.2: username/password login. `serverUrl` is passed in
/// from [ConnectServerScreen] via the route's `extra`. On success,
/// [SessionController] transitions to `SessionAuthenticated` and the
/// router's redirect takes over — this screen doesn't navigate itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({required this.serverUrl, super.key});

  final String serverUrl;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Enter a username.');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(
            serverUrl: widget.serverUrl,
            username: username,
            password: password,
          );
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  String _messageFor(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Incorrect username or password.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Lost connection to the server.';
    }
    return 'Login failed. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.serverUrl,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _login(),
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
              onPressed: _isLoggingIn ? null : _login,
              child: _isLoggingIn
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
