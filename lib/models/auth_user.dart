import 'user_permissions.dart';

/// `user` object from the `POST /login` / `POST /auth/refresh` response
/// envelope. See `~/Code/audiobookshelf/server/Auth.js`
/// (`getUserLoginResponsePayload`, `handleLoginSuccess`) and
/// `server/models/User.js` (`toOldJSONForBrowser`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.type,
    required this.legacyToken,
    required this.isOldToken,
    required this.accessToken,
    required this.refreshToken,
    required this.isActive,
    required this.isLocked,
    required this.permissions,
    required this.hasOpenIDLink,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final librariesAccessible =
        (json['librariesAccessible'] as List<dynamic>?)?.cast<String>() ??
        const [];
    final itemTagsSelected =
        (json['itemTagsSelected'] as List<dynamic>?)?.cast<String>() ??
        const [];
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      type: json['type'] as String? ?? 'user',
      legacyToken: json['token'] as String?,
      isOldToken: json['isOldToken'] as bool? ?? false,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      permissions: UserPermissions.fromJson(
        (json['permissions'] as Map<String, dynamic>?) ?? const {},
        librariesAccessible: librariesAccessible,
        itemTagsSelected: itemTagsSelected,
      ),
      hasOpenIDLink: json['hasOpenIDLink'] as bool? ?? false,
    );
  }

  final String id;
  final String username;
  final String email;
  final String type; // 'root' | 'admin' | 'user' | 'guest'
  final String? legacyToken; // pre-2.26.0 static token
  final bool isOldToken;
  final String? accessToken; // 2.26.0+ short-lived JWT
  final String? refreshToken; // 2.26.0+ refresh token (only if requested)
  final bool isActive;
  final bool isLocked;
  final UserPermissions permissions;
  final bool hasOpenIDLink;

  /// The bearer token to actually use for API calls: prefer the new JWT,
  /// fall back to the legacy static token for servers older than 2.26.0.
  String? get effectiveToken => accessToken ?? legacyToken;

  bool get isNewAuthServer => accessToken != null;

  bool get canDelete => isActive && permissions.delete;
  bool get canUpdate => isActive && permissions.update;
  bool get canDownload => isActive && permissions.download;
  bool get canUpload => isActive && permissions.upload;

  AuthUser copyWith({String? accessToken, String? refreshToken}) {
    return AuthUser(
      id: id,
      username: username,
      email: email,
      type: type,
      legacyToken: legacyToken,
      isOldToken: isOldToken,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isActive: isActive,
      isLocked: isLocked,
      permissions: permissions,
      hasOpenIDLink: hasOpenIDLink,
    );
  }
}
