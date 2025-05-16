class Validators {
  /// returns true if the [value] is an email
  static bool validateEmail(String value) {
    if (value.isEmpty) {
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(value);
  }

  /// returns true if the [value] is a valid account type
  static bool validateAccountType(String value) {
    return value == 'admin' || value == 'lecturer' || value == 'student';
  }

  /// returns true if the [value] is a valid and complex password
  static bool validatePassword(String value) {
    if (value.isEmpty) {
      return false;
    }
    final passwordRegex = RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$');
    return passwordRegex.hasMatch(value);
  }
}