import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/lib"

files = {
    # ---------------- OFFLINE QUEUE ----------------
    "utils/offline/queue_item.dart": """class QueueItem {
  final int? id;
  final String action; // e.g., 'INSERT_ATTENDANCE'
  final String payload; // JSON string of the data
  final String status; // 'PENDING', 'FAILED', 'COMPLETED'
  final String createdAt;

  QueueItem({
    this.id,
    required this.action,
    required this.payload,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'payload': payload,
    'status': status,
    'created_at': createdAt,
  };

  factory QueueItem.fromMap(Map<String, dynamic> map) => QueueItem(
    id: map['id'],
    action: map['action'],
    payload: map['payload'],
    status: map['status'],
    createdAt: map['created_at'],
  );
}""",

    "utils/offline/queue_manager.dart": """import 'dart:convert';
import 'package:maktab_app/services/database_helper.dart';
import 'queue_item.dart';

class QueueManager {
  static const String tableName = 'offline_queue';

  static Future<void> createTable(db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<int> enqueue(String action, Map<String, dynamic> payload) async {
    final db = await DatabaseHelper.database;
    final item = QueueItem(
      action: action,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().toIso8601String(),
    );
    return await db.insert(tableName, item.toMap());
  }

  static Future<List<QueueItem>> getPendingItems() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(tableName, where: 'status = ?', whereArgs: ['PENDING']);
    return List.generate(maps.length, (i) => QueueItem.fromMap(maps[i]));
  }

  static Future<void> markCompleted(int id) async {
    final db = await DatabaseHelper.database;
    await db.update(tableName, {'status': 'COMPLETED'}, where: 'id = ?', whereArgs: [id]);
  }
}""",

    "utils/offline/network_listener.dart": """// Stub for network listener.
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
}""",

    "utils/offline/sync_manager.dart": """import 'queue_manager.dart';
import '../logging/logger.dart';

class SyncManager {
  static bool isSyncing = false;

  static Future<void> syncPendingItems() async {
    if (isSyncing) return;
    
    isSyncing = true;
    try {
      final items = await QueueManager.getPendingItems();
      if (items.isEmpty) {
        AppLogger.info('No items to sync.');
        return;
      }

      AppLogger.info('Found ${items.length} items to sync.');
      for (var item in items) {
        // Here we would typically send to a server.
        // For Maktab offline, maybe we process local background tasks here.
        await Future.delayed(const Duration(milliseconds: 100)); // Simulate processing
        await QueueManager.markCompleted(item.id!);
      }
      AppLogger.info('Sync completed.');
    } catch (e) {
      AppLogger.error('Sync failed', e);
    } finally {
      isSyncing = false;
    }
  }
}""",

    # ---------------- AUDIT TRAIL ----------------
    "domain/models/audit_log.dart": """class AuditLog {
  final int? id;
  final String action; // e.g. 'UPDATE_ATTENDANCE'
  final String entityType; // e.g. 'Attendance'
  final int entityId;
  final String details; // JSON of what changed
  final String timestamp;
  final String? performedBy; // Role or Teacher ID

  AuditLog({
    this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
    this.performedBy,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'details': details,
    'timestamp': timestamp,
    'performed_by': performedBy,
  };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'],
    action: map['action'],
    entityType: map['entity_type'],
    entityId: map['entity_id'],
    details: map['details'],
    timestamp: map['timestamp'],
    performedBy: map['performed_by'],
  );
}""",

    "repositories/audit_repository.dart": """import 'package:maktab_app/services/database_helper.dart';
import '../domain/models/audit_log.dart';

class AuditRepository {
  static const String tableName = 'audit_logs';

  static Future<void> createTable(db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        performed_by TEXT
      )
    ''');
  }

  Future<int> insert(AuditLog log) async {
    final db = await DatabaseHelper.database;
    return await db.insert(tableName, log.toMap());
  }

  Future<List<AuditLog>> getLogs({int limit = 100, int offset = 0}) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(tableName, orderBy: 'timestamp DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => AuditLog.fromMap(maps[i]));
  }
}""",

    "services/audit_service.dart": """import '../repositories/audit_repository.dart';
import '../domain/models/audit_log.dart';
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
}""",
}

for file_path, content in files.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Filled {file_path}")
