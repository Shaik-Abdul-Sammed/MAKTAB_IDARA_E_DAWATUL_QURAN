import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User can be created and serialized', () {
      final user = User(
        id: 1,
        name: 'admin',
        pinHash: 'hashed_pin',
        role: 'admin',
        isActive: true,
        createdAt: '2023-01-01',
      );

      final map = user.toMap();
      
      expect(map['id'], 1);
      expect(map['name'], 'admin');
      expect(map['pin_hash'], 'hashed_pin');
      expect(map['role'], 'admin');
      expect(map['is_active'], 1);
      expect(map['created_at'], '2023-01-01');

      final deserialized = User.fromMap(map);
      
      expect(deserialized.id, 1);
      expect(deserialized.name, 'admin');
      expect(deserialized.pinHash, 'hashed_pin');
      expect(deserialized.role, 'admin');
      expect(deserialized.isActive, true);
      expect(deserialized.createdAt, '2023-01-01');
    });
  });
}
