import '../models/syllabus.dart';
import '../services/database_helper.dart';

class SyllabusRepository {
  Future<List<SyllabusItem>> getAllItems() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('syllabus_items');
    return maps.map((e) => SyllabusItem.fromMap(e)).toList();
  }

  Future<int> insertItem(SyllabusItem item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('syllabus_items', item.toMap());
  }
  Future<int> updateItem(SyllabusItem item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('syllabus_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<int> deleteItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('syllabus_items', where: 'id = ?', whereArgs: [id]);
  }

}