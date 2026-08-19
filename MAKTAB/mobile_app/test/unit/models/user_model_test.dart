import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';

void main() {
  group('User Model Unit Tests', () {
    final userMap = {
      'id': 1,
      'name': 'Admin User',
      'pin_hash': 'hashed_pin_123',
      'role': 'admin',
      'is_active': 1,
      'created_at': '2026-08-01',
      'mobile': '9876543210',
    };

    test('fromMap should construct User correctly', () {
      final u = User.fromMap(userMap);
      expect(u.id, 1);
      expect(u.name, 'Admin User');
      expect(u.pinHash, 'hashed_pin_123');
      expect(u.role, 'admin');
      expect(u.isActive, isTrue);
      expect(u.createdAt, '2026-08-01');
      expect(u.mobile, '9876543210');
    });

    test('toMap should convert User to Map correctly', () {
      final u = User(
        id: 1,
        name: 'Admin User',
        pinHash: 'hashed_pin_123',
        role: 'admin',
        isActive: true,
        createdAt: '2026-08-01',
        mobile: '9876543210',
      );
      final map = u.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Admin User');
      expect(map['is_active'], 1);
      expect(map['mobile'], '9876543210');
    });

    test('copyWith should update fields correctly', () {
      final u = User(
        id: 1,
        name: 'Admin User',
        pinHash: 'hashed_pin_123',
        role: 'admin',
        createdAt: '2026-08-01',
      );
      final updated = u.copyWith(name: 'Super Admin', isActive: false);
      expect(updated.name, 'Super Admin');
      expect(updated.isActive, isFalse);
    });
  });
}
