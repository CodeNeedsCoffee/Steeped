import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/state/session_controller.dart';
import 'data/password_validation.dart';

/// Changes the signed-in user's password via `PATCH /api/me/password`.
/// Mirrors [LoginScreen]'s form structure (controllers disposed here, one
/// in-flight flag, one error string rendered under the fields) rather than
/// introducing a second form idiom.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentController.text;
    final newPassword = _newController.text;

    final validationError = validatePasswordChange(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: _confirmController.text,
    );
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _messageFor(DioException e) {
    final status = e.response?.statusCode;
    if (status == 400) {
      // The server sends a plain-text, already-readable reason here
      // ("Invalid password" for a wrong current password), so prefer it
      // over anything this app could guess.
      final body = e.response?.data;
      if (body is String && body.trim().isNotEmpty) return body.trim();
      return "Couldn't change your password. Check your current password.";
    }
    if (status == 403) {
      return "Your account isn't allowed to change its password.";
    }
    if (status == 429) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Lost connection to the server.';
    }
    return "Couldn't change your password. Try again.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            enabled: !_isSubmitting,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newController,
            obscureText: true,
            enabled: !_isSubmitting,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'At least $minPasswordLength characters',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            obscureText: true,
            enabled: !_isSubmitting,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _isSubmitting ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Real server behavior, not a warning this app invents: a
          // successful change invalidates the user's other JWT sessions.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Changing your password signs you out on your other '
                  'devices. This one stays signed in.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Change Password'),
          ),
        ],
      ),
    );
  }
}
