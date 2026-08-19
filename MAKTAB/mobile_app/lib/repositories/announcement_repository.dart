import '../models/announcement.dart';
import '../services/database_helper.dart';

class AnnouncementRepository {
  Future<List<Announcement>> getAllAnnouncements() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('announcements');
    return maps.map((e) => Announcement.fromMap(e)).toList();
  }

  Future<int> insertAnnouncement(Announcement item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('announcements', item.toMap());
  }
  Future<int> updateAnnouncement(Announcement item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('announcements', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<int> deleteAnnouncement(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
  }

}