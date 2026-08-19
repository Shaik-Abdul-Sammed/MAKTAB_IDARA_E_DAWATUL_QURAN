import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User serialization and deserialization', () {
      final user = User(
        id: 1,
        name: 'Test User',
        pinHash: 'hashed_pin',
        role: 'teacher',
        createdAt: '2023-10-27T10:00:00Z',
      );

      final map = user.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Test User');
      expect(map['pin_hash'], 'hashed_pin');
      expect(map['role'], 'teacher');
      expect(map['created_at'], '2023-10-27T10:00:00Z');

      final deserializedUser = User.fromMap(map);
      expect(deserializedUser.id, 1);
      expect(deserializedUser.name, 'Test User');
      expect(deserializedUser.pinHash, 'hashed_pin');
    });
  });
}
