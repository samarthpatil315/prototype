/// Pure, unit-tested input validation helpers.
class Validators {
  const Validators._();

  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  static final RegExp _phone = RegExp(r'^[+]?[0-9\s-]{7,15}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Use letters and numbers';
    }
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? value, {bool requiredField = false}) {
    if (value == null || value.trim().isEmpty) {
      return requiredField ? 'Phone is required' : null;
    }
    if (!_phone.hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }

  static bool isValidAmount(String? value) {
    if (value == null) return false;
    final n = num.tryParse(value.replaceAll(',', '').trim());
    return n != null && n >= 0;
  }
}
