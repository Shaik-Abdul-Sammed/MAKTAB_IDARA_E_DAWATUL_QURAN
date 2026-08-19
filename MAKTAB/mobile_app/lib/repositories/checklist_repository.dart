import '../models/checklist.dart';
import '../services/database_helper.dart';

class ChecklistRepository {
  Future<List<ChecklistQuestion>> getAllQuestions() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('checklist_questions');
    return maps.map((e) => ChecklistQuestion.fromMap(e)).toList();
  }

  Future<List<ChecklistSubmission>> getAllSubmissions() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('checklist_submissions');
    return maps.map((e) => ChecklistSubmission.fromMap(e)).toList();
  }

  Future<int> insertQuestion(ChecklistQuestion item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('checklist_questions', item.toMap());
  }
  Future<int> updateQuestion(ChecklistQuestion item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('checklist_questions', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<int> deleteQuestion(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('checklist_questions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSubmission(ChecklistSubmission item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('checklist_submissions', item.toMap());
  }
  Future<int> updateSubmission(ChecklistSubmission item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('checklist_submissions', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<int> deleteSubmission(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('checklist_submissions', where: 'id = ?', whereArgs: [id]);
  }

}
