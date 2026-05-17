/// Pharmacy password rules (registration, recovery). Policy: **minimum length only**.
abstract final class KpmsPasswordPolicy {
  /// Minimum length for new passwords (signup, reset, recovery completion).
  static const int pharmacyMinNewPasswordLength = 8;

  static final RegExp _hasUpper = RegExp(r'[A-Z]');
  static final RegExp _hasLower = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _hasSpecial = RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]''');

  /// New passwords: at least [pharmacyMinNewPasswordLength] characters (no complexity requirement).
  static bool meetsPharmacySignupRules(String password) {
    return password.length >= pharmacyMinNewPasswordLength;
  }

  /// Minimum length for sign-in (Supabase allows 6+; we keep 6 for legacy accounts).
  static bool meetsSignInMinimum(String password) => password.length >= 6;

  /// 0 = empty … 4 = strong (optional UI hint; not enforced as policy).
  static int strengthScore(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= pharmacyMinNewPasswordLength) s++;
    if (p.length >= 12) s++;
    if (p.length >= 16) s++;
    if (_hasUpper.hasMatch(p)) s++;
    if (_hasLower.hasMatch(p)) s++;
    if (_hasDigit.hasMatch(p)) s++;
    if (_hasSpecial.hasMatch(p)) s++;
    if (s <= 2) return 1;
    if (s <= 4) return 2;
    if (s <= 6) return 3;
    return 4;
  }
}
