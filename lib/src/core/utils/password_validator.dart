class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigits;
  final bool hasSpecialCharacters;

  PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigits,
    required this.hasSpecialCharacters,
  });

  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigits &&
      hasSpecialCharacters;
}

class PasswordValidator {
  static PasswordValidationResult validate(String password) {
    return PasswordValidationResult(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasDigits: password.contains(RegExp(r'\d')),
      hasSpecialCharacters: password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
    );
  }

  static String? getError(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    final result = validate(value);
    if (!result.isValid) {
      return 'Password does not meet requirements';
    }
    return null;
  }
}
