class Validators {
  static bool validateEmail(String value) {
    if (value.isEmpty) {
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(value);
  }

  static bool validateAccountType(String value) {
    return value == 'admin' || value == 'lecturer' || value == 'student';
  }

  static bool validatePassword(String value) {
    if (value.isEmpty) {
      return false;
    }
    final passwordRegex = RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,}$');
    return passwordRegex.hasMatch(value);
  }
}