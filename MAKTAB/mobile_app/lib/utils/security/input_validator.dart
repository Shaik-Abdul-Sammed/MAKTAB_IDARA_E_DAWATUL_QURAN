class InputValidator {
  static String? validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN is required';
    }
    if (value.length < 4 || value.length > 6) {
      return 'PIN must be 4-6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name is too short';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^[0-9]{10,12}$').hasMatch(value)) {
        return 'Enter a valid phone number (10-12 digits)';
      }
    }
    return null;
  }
}