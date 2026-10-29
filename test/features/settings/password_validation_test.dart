import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/settings/data/password_validation.dart';

void main() {
  PasswordProblem? validate({
    String current = 'oldpassword',
    String next = 'newpassword',
    String? confirm,
  }) {
    return validatePasswordChange(
      currentPassword: current,
      newPassword: next,
      confirmPassword: confirm ?? next,
    );
  }

  group('validatePasswordChange', () {
    test('accepts a valid change', () {
      expect(validate(), isNull);
    });

    test('requires the current password', () {
      expect(validate(current: ''), PasswordProblem.currentEmpty);
    });

    test('requires a new password', () {
      expect(validate(next: ''), PasswordProblem.newEmpty);
    });

    test('rejects a new password under the minimum length', () {
      final short = 'a' * (minPasswordLength - 1);
      expect(validate(next: short), PasswordProblem.tooShort);
    });

    test('accepts a new password exactly at the minimum length', () {
      expect(validate(next: 'a' * minPasswordLength), isNull);
    });

    test('rejects reusing the current password', () {
      expect(
        validate(current: 'samepassword', next: 'samepassword'),
        PasswordProblem.sameAsCurrent,
      );
    });

    test('rejects a mismatched confirmation', () {
      expect(
        validate(next: 'newpassword', confirm: 'newpasswerd'),
        PasswordProblem.mismatch,
      );
    });

    // The empty-current check has to win here, otherwise the length rule
    // would report the less useful of the two problems.
    test('reports the missing current password before other problems', () {
      expect(validate(current: '', next: 'x'), PasswordProblem.currentEmpty);
    });
  });
}
