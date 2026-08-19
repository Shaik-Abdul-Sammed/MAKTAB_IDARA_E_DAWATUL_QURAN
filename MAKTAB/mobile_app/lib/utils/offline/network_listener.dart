// Stub for network listener.
// Since Maktab is strictly offline, this is mostly a placeholder for 
// any future "local network sync" features.
import 'dart:async';

class NetworkListener {
  static bool _isConnected = false;
  static final StreamController<bool> _controller = StreamController<bool>.broadcast();

  static Stream<bool> get onNetworkChange => _controller.stream;

  static bool get isConnected => _isConnected;

  static void simulateNetworkChange(bool connected) {
    _isConnected = connected;
    _controller.add(connected);
  }
  
  static void dispose() {
    _controller.close();
  }
}