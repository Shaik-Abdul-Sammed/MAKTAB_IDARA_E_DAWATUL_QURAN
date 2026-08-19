abstract class IAuthService {
  Future<bool> login(String pin);
  Future<void> logout();
  Future<bool> changePin(String oldPin, String newPin);
  Future<bool> verifyAdminPin(String pin);
}