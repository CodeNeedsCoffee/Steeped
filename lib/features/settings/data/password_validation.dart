/// Shortest new password the app will submit. The server itself only
/// requires non-empty (and allows blank for `root`), so this is purely a
/// client-side floor to stop a trivially weak password being set by
/// accident.
const int minPasswordLength = 8;

enum PasswordProblem { currentEmpty, newEmpty, tooShort, sameAsCurrent, mismatch }

/// Client-side checks run before `PATCH /api/me/password` is called.
/// Returns what's wrong, or null when the input is submittable; the screen
/// turns the problem into localized text.
///
/// Kept as a plain function rather than living inside the screen's State so
/// the rules can be unit-tested without pumping a widget.
PasswordProblem? validatePasswordChange({
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
}) {
  if (currentPassword.isEmpty) return PasswordProblem.currentEmpty;
  if (newPassword.isEmpty) return PasswordProblem.newEmpty;
  if (newPassword.length < minPasswordLength) return PasswordProblem.tooShort;
  if (newPassword == currentPassword) return PasswordProblem.sameAsCurrent;
  if (newPassword != confirmPassword) return PasswordProblem.mismatch;
  return null;
}
