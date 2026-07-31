/// Response shape of `GET /status` — used to validate a URL is really an
/// Audiobookshelf server before attempting login. See
/// `~/Code/audiobookshelf/server/Server.js` (`getServerStatus` route).
class ServerStatus {
  const ServerStatus({
    required this.app,
    required this.serverVersion,
    required this.isInit,
    required this.language,
    required this.authMethods,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      app: json['app'] as String? ?? '',
      serverVersion: json['serverVersion'] as String? ?? '',
      isInit: json['isInit'] as bool? ?? false,
      language: json['language'] as String? ?? 'en-us',
      authMethods:
          (json['authMethods'] as List<dynamic>?)?.cast<String>() ??
          const ['local'],
    );
  }

  final String app;
  final String serverVersion;
  final bool isInit;
  final String language;
  final List<String> authMethods;

  /// True only when the response looks like a real, already-initialized
  /// Audiobookshelf server (mirrors the reference app's validation, which
  /// requires `isInit`/`language` keys to be present at all).
  bool get looksLikeAudiobookshelf => app == 'audiobookshelf';
}
