import '../models/student.dart';
import '../models/user.dart';

class LanguageResolver {
  static const _supported = {'en', 'ur', 'hi', 'te'};

  static String forStudent(Student student) {
    final lang = student.preferredLanguage.trim().toLowerCase();
    return _supported.contains(lang) ? lang : 'en';
  }

  static String forUser(User user) {
    final lang = user.preferredLanguage.trim().toLowerCase();
    return _supported.contains(lang) ? lang : 'en';
  }

  static String forRecipient({Student? student, User? user}) {
    if (student != null) return forStudent(student);
    if (user != null) return forUser(user);
    return 'en';
  }

  static bool isSupported(String lang) => _supported.contains(lang);
  static List<String> get supportedLanguages => _supported.toList();
}
