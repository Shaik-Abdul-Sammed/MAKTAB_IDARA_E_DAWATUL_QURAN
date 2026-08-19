import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart';

void main() {
  group('Batch Model Tests', () {
    test('Batch serialization and deserialization', () {
      final batch = Batch(
        id: 1,
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        teacherId: 3,
      );

      final map = batch.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Morning Batch');
      expect(map['teacher_id'], 3);

      final deserializedBatch = Batch.fromMap(map);
      expect(deserializedBatch.id, 1);
      expect(deserializedBatch.name, 'Morning Batch');
      expect(deserializedBatch.teacherId, 3);
    });
  });
}
