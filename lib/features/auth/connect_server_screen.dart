import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/session_storage.dart';
import 'data/server_profile_repository.dart';
import 'state/profile_switcher.dart';
import 'state/session_controller.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 3.1 + 3.7: enter a server URL, validate it's reachable and
/// really is an Audiobookshelf server via `GET /status`, then move on to
/// login. Offline/unreachable states are surfaced inline rather than
/// crashing or hanging.
class ConnectServerScreen extends ConsumerStatefulWidget {
  const ConnectServerScreen({this.addMode = false, super.key});

  /// True when reached from "Add server or account" while already signed
  /// in: continues to the add-mode login route instead of the first-run one.
  final bool addMode;

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
      setState(() => _errorMessage = context.l10n.enterServerAddress);
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
          () => _errorMessage = context.l10n.notAudiobookshelf,
        );
        return;
      }
      if (!status.isInit) {
        setState(
          () => _errorMessage = context.l10n.serverNotInitialized,
        );
        return;
      }

      if (!mounted) return;
      await context.push(
        widget.addMode ? '/add-server/login' : '/login',
        extra: url,
      );
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = context.l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return context.l10n.couldntReachCheckConnection;
      case DioExceptionType.connectionError:
        return context.l10n.couldntConnectCheckServer;
      case DioExceptionType.badResponse:
        return context.l10n.serverRespondedWithError(
          e.response?.statusCode ?? '?',
        );
      default:
        return context.l10n.couldntReachTryAgain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.addMode
              ? context.l10n.addAccountTitle
              : context.l10n.connectToServer,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.enterYourAudiobookshelfServerAddress,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autocorrect: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.l10n.serverAddress,
                hintText: context.l10n.audiobookshelfExampleCom,
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
                  : Text(context.l10n.continueLabel),
            ),
            if (!widget.addMode) const _SavedAccounts(),
          ],
        ),
      ),
    );
  }
}

/// Accounts that are still signed in on this device, offered on the connect
/// screen after one account's session ended, so the others stay reachable.
class _SavedAccounts extends ConsumerWidget {
  const _SavedAccounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(serverProfilesProvider).valueOrNull ?? const [];
    final usable = ref.watch(_usableProfilesProvider(profiles)).valueOrNull;
    if (usable == null || usable.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.savedAccounts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final p in usable)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(context.l10n.continueAsAccount(p.username)),
              subtitle: Text(hostOfServerUrl(p.serverUrl)),
              onTap: () => ref.read(profileSwitcherProvider).switchTo(p.id),
            ),
        ],
      ),
    );
  }
}

final _usableProfilesProvider = FutureProvider.autoDispose
    .family<List<ServerProfile>, List<ServerProfile>>((ref, profiles) async {
      final storage = ref.read(sessionStorageProvider);
      return [
        for (final p in profiles)
          if (await storage.hasCredentials(p.id)) p,
      ];
    });
