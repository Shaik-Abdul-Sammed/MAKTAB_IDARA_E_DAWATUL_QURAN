import '../domain/interfaces/i_user_repository.dart';
import '../domain/dtos/user_dto.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../models/user.dart';

class TeacherRepository implements IUserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> insertUser(UserDTO user) async {
    final db = await _dbHelper.database;
    final id = await db.insert('users', user.toMap());
    final createdUser = User.fromMap({...user.toMap(), 'id': id});
    await CloudSyncService.instance.pushUser(createdUser);
    return id;
  }

  @override
  Future<List<UserDTO>> getAllTeachers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['teacher'],
    );
    return List.generate(maps.length, (i) => UserDTO.fromMap(maps[i]));
  }

  @override
  Future<UserDTO?> getUserById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return UserDTO.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<int> updateUser(UserDTO user) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await CloudSyncService.instance.pushUser(User.fromMap(user.toMap()));
    return res;
  }

  @override
  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
