import 'package:maktab_app/models/app_message.dart';
import 'package:maktab_app/services/database_helper.dart';

class MessageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insert a new message
  Future<int> insertMessage(AppMessage message) async {
    final db = await _dbHelper.database;
    return await db.insert('messages', message.toMap());
  }

  // Get messages for a specific user (either as sender or receiver)
  Future<List<AppMessage>> getMessagesForUser(int userId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'receiver_id = ? OR sender_id = ? OR receiver_id IS NULL',
      whereArgs: [userId, userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AppMessage.fromMap(map)).toList();
  }

  // Get conversation between two users
  Future<List<AppMessage>> getConversation(int user1Id, int user2Id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [user1Id, user2Id, user2Id, user1Id],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => AppMessage.fromMap(map)).toList();
  }

  // Get all broadcast messages (receiver_id is null)
  Future<List<AppMessage>> getBroadcastMessages() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'receiver_id IS NULL',
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AppMessage.fromMap(map)).toList();
  }

  // Mark message as read
  Future<void> markAsRead(int messageId) async {
    final db = await _dbHelper.database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }
}
