/// Shortest new password the app will submit. The server itself only
/// requires non-empty (and allows blank for `root`), so this is purely a
/// client-side floor to stop a trivially weak password being set by
/// accident.
const int minPasswordLength = 8;

/// Client-side checks run before `PATCH /api/me/password` is called.
/// Returns the message to show, or null when the input is submittable.
///
/// Kept as a plain function rather than living inside the screen's State so
/// the rules can be unit-tested without pumping a widget.
String? validatePasswordChange({
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
}) {
  if (currentPassword.isEmpty) {
    return 'Enter your current password.';
  }
  if (newPassword.isEmpty) {
    return 'Enter a new password.';
  }
  if (newPassword.length < minPasswordLength) {
    return 'New password must be at least $minPasswordLength characters.';
  }
  if (newPassword == currentPassword) {
    return 'New password must be different from your current one.';
  }
  if (newPassword != confirmPassword) {
    return "New passwords don't match.";
  }
  return null;
}
