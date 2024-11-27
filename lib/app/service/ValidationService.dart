import 'package:get/get.dart';

class ValidationService extends GetxService {
  // Check if email is valid
  bool validateEmail(String email) {
    String pattern =
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  // Check if password is strong (minimum 6 characters)
  bool validatePassword(String password) {
    return password.length >= 6;
  }

  // General input validation example
  bool validateNotEmpty(String input) {
    return input.isNotEmpty;
  }
}