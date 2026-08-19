import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _defaultUrl = 'https://maktab-idara-e-dawatul-quran.onrender.com';
  static String? _cachedBaseUrl;

  static Future<String> get baseUrl async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedBaseUrl = prefs.getString('api_base_url') ?? _defaultUrl;
    } catch (_) {
      _cachedBaseUrl = _defaultUrl;
    }
    return _cachedBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    _cachedBaseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', url);
    } catch (_) {}
  }
}
