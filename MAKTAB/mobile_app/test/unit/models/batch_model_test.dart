import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart';

void main() {
  group('Batch Model Unit Tests', () {
    final batchMap = {
      'id': 10,
      'name': 'Morning Hifz Batch A',
      'timing': '06:00 AM - 08:00 AM',
      'teacher_id': 3,
    };

    test('fromMap should construct Batch correctly', () {
      final b = Batch.fromMap(batchMap);
      expect(b.id, 10);
      expect(b.name, 'Morning Hifz Batch A');
      expect(b.timing, '06:00 AM - 08:00 AM');
      expect(b.teacherId, 3);
    });

    test('toMap should convert Batch to Map correctly', () {
      final b = Batch(
        id: 10,
        name: 'Morning Hifz Batch A',
        timing: '06:00 AM - 08:00 AM',
        teacherId: 3,
      );
      final map = b.toMap();
      expect(map['id'], 10);
      expect(map['name'], 'Morning Hifz Batch A');
      expect(map['timing'], '06:00 AM - 08:00 AM');
      expect(map['teacher_id'], 3);
    });

    test('copyWith should update fields correctly', () {
      final b = Batch(
        id: 10,
        name: 'Morning Hifz Batch A',
        timing: '06:00 AM - 08:00 AM',
      );
      final updated = b.copyWith(
        name: 'Evening Nazira Batch',
        teacherId: 5,
      );
      expect(updated.id, 10);
      expect(updated.name, 'Evening Nazira Batch');
      expect(updated.timing, '06:00 AM - 08:00 AM');
      expect(updated.teacherId, 5);
    });
  });
}
