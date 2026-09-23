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
    final List<Map<String, dynamic>> maps;
    if (user1Id == 1 || user2Id == 1) {
      maps = await db.rawQuery('''
        SELECT * FROM messages
        WHERE (sender_id IN (?, 1) AND receiver_id = ?) 
           OR (sender_id = ? AND receiver_id IN (?, 1))
        ORDER BY timestamp ASC
      ''', [user1Id, user2Id, user2Id, user1Id]);
    } else {
      maps = await db.query(
        'messages',
        where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
        whereArgs: [user1Id, user2Id, user2Id, user1Id],
        orderBy: 'timestamp ASC',
      );
    }
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

  // Mark all messages from sender as read for receiver
  Future<void> markMessagesAsReadBetween(int receiverId, int senderId, {bool isAdmin = false}) async {
    final db = await _dbHelper.database;
    if (isAdmin) {
      await db.rawUpdate(
        'UPDATE messages SET is_read = 1 WHERE (receiver_id = ? OR receiver_id = 1) AND sender_id = ?',
        [receiverId, senderId],
      );
    } else {
      await db.rawUpdate(
        'UPDATE messages SET is_read = 1 WHERE receiver_id = ? AND sender_id = ?',
        [receiverId, senderId],
      );
    }
  }

  // Get latest message between two users
  Future<Map<String, dynamic>?> getLatestMessageBetween(int user1Id, int user2Id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT content, timestamp, is_read, sender_id FROM messages
      WHERE (sender_id = ? AND receiver_id = ?) 
         OR (sender_id = ? AND receiver_id = ?)
         OR (sender_id = 1 AND receiver_id = ?)
         OR (sender_id = ? AND receiver_id = 1)
      ORDER BY timestamp DESC LIMIT 1
    ''', [user1Id, user2Id, user2Id, user1Id, user2Id, user2Id]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Get unread count from a specific sender
  Future<int> getUnreadCountBetween(int receiverId, int senderId, {bool isAdmin = false}) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      isAdmin
          ? 'SELECT COUNT(*) as count FROM messages WHERE (receiver_id = ? OR receiver_id = 1) AND sender_id = ? AND is_read = 0'
          : 'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND sender_id = ? AND is_read = 0',
      isAdmin ? [receiverId, senderId] : [receiverId, senderId],
    );
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      final val = result.first.values.first;
      if (val is int) return val;
      if (val is num) return val.toInt();
    }
    return 0;
  }

  // Total unread count for receiver
  Future<int> getUnreadCountForReceiver(int receiverId, {bool isAdmin = false}) async {
    final db = await _dbHelper.database;
    final int safeId = receiverId > 0 ? receiverId : 1;
    final List<Map<String, dynamic>> result;
    if (isAdmin) {
      result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE (receiver_id = ? OR receiver_id = 1) AND (sender_id != ? AND sender_id != 1) AND is_read = 0',
        [safeId, safeId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM messages WHERE receiver_id = ? AND is_read = 0',
        [safeId],
      );
    }
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      final val = result.first['count'] ?? result.first.values.first;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }
    return 0;
  }
}
