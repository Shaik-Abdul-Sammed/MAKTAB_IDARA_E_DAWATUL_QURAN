// Local usage tracking.
class AnalyticsHelper {
  static final Map<String, int> _eventCounts = {};

  static void logEvent(String eventName) {
    if (_eventCounts.containsKey(eventName)) {
      _eventCounts[eventName] = _eventCounts[eventName]! + 1;
    } else {
      _eventCounts[eventName] = 1;
    }
    // Could eventually dump this to a local DB table to see which features are used most
  }
  
  static Map<String, int> getUsageStats() {
    return _eventCounts;
  }
}