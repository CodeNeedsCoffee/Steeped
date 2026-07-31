import 'auth_user.dart';

/// Envelope returned by both `POST /login` and `POST /auth/refresh`.
/// `serverSettings` is kept as a raw map for now — typing the full settings
/// surface is out of scope until a feature actually needs a specific field.
class LoginResult {
  const LoginResult({
    required this.user,
    required this.userDefaultLibraryId,
    required this.serverSettings,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      userDefaultLibraryId: json['userDefaultLibraryId'] as String?,
      serverSettings:
          (json['serverSettings'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final AuthUser user;
  final String? userDefaultLibraryId;
  final Map<String, dynamic> serverSettings;

  String? get serverVersion => serverSettings['version'] as String?;
}
