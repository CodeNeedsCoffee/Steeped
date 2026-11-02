import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;

import 'masked_server_address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/profile_switcher.dart';
import 'state/session_controller.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 3.2: username/password login. `serverUrl` is passed in
/// from [ConnectServerScreen] via the route's `extra`. On success,
/// [SessionController] transitions to `SessionAuthenticated` and the
/// router's redirect takes over — this screen doesn't navigate itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({required this.serverUrl, this.addMode = false, super.key});

  final String serverUrl;

  /// Adding another account while signed in: stops playback once the
  /// credentials check out, then lands on the new account's home.
  final bool addMode;

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
      setState(() => _errorMessage = context.l10n.enterUsername);
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
            beforeActivate: widget.addMode
                ? ref.read(profileSwitcherProvider).prepareForChange
                : null,
          );
      // Tells the password manager the credentials worked, so it offers to
      // save (or update) them.
      TextInput.finishAutofillContext();
      if (widget.addMode && mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = context.l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  String _messageFor(DioException e) {
    if (e.response?.statusCode == 401) {
      return context.l10n.incorrectCredentials;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return context.l10n.lostConnection;
    }
    return context.l10n.loginFailed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.logIn)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: AutofillGroup(
          // A failed login must not make the manager save the typo.
          onDisposeAction: AutofillContextAction.cancel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MaskedServerAddress(
                widget.serverUrl,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.l10n.username,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.password,
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
                    : Text(context.l10n.logIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
