import '../repositories/audit_repository.dart';
import '../models/audit_log.dart';
import '../utils/security/session_manager.dart';

class AuditService {
  final AuditRepository _repository = AuditRepository();
  final SessionManager _sessionManager = SessionManager();

  Future<void> logAction({
    required String action,
    required String entityType,
    required int entityId,
    required String details,
  }) async {
    final role = await _sessionManager.getCurrentRole();
    final log = AuditLog(
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now().toIso8601String(),
      performedBy: role ?? 'UNKNOWN',
    );
    await _repository.insert(log);
  }

  Future<List<AuditLog>> getRecentLogs() async {
    return await _repository.getLogs(limit: 50);
  }
}