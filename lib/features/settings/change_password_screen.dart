import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/state/session_controller.dart';
import 'data/password_validation.dart';
import '../../l10n/l10n.dart';

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
      setState(
        () => _errorMessage = switch (validationError) {
          PasswordProblem.currentEmpty => context.l10n.pwEnterCurrent,
          PasswordProblem.newEmpty => context.l10n.pwEnterNew,
          PasswordProblem.tooShort => context.l10n.pwTooShort(minPasswordLength),
          PasswordProblem.sameAsCurrent => context.l10n.pwSame,
          PasswordProblem.mismatch => context.l10n.pwMismatch,
        },
      );
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
        SnackBar(content: Text(context.l10n.passwordChanged)),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = context.l10n.somethingWentWrong);
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
      return context.l10n.couldntChangePasswordCheckCurrent;
    }
    if (status == 403) {
      return context.l10n.passwordChangeNotAllowed;
    }
    if (status == 429) {
      return context.l10n.tooManyAttempts;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return context.l10n.lostConnection;
    }
    return context.l10n.couldntChangePassword;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.changePassword)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            enabled: !_isSubmitting,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: context.l10n.currentPassword,
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
              labelText: context.l10n.newPassword,
              helperText: context.l10n.atLeastCharacters(minPasswordLength),
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
            decoration: InputDecoration(
              labelText: context.l10n.confirmNewPassword,
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
                  context.l10n.changingYourPasswordSignsYou,
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
                : Text(context.l10n.changePassword),
          ),
        ],
      ),
    );
  }
}
