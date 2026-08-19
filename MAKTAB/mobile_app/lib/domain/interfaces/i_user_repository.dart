import '../dtos/user_dto.dart';

abstract class IUserRepository {
  Future<int> insertUser(UserDTO user);
  Future<List<UserDTO>> getAllTeachers();
  Future<UserDTO?> getUserById(int id);
  Future<int> updateUser(UserDTO user);
  Future<int> deleteUser(int id);
}