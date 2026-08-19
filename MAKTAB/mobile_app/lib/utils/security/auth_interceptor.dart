// This is an offline-first app, so "intercepting" usually means checking 
// local session validity before allowing critical actions.
class AuthInterceptor {
  static bool isSessionValid(String token, String expiry) {
    try {
      DateTime expiryDate = DateTime.parse(expiry);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  static String generateLocalSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}