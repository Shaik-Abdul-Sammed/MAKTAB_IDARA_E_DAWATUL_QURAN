import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart';

void main() {
  group('Batch Model Tests', () {
    test('Batch can be created and serialized', () {
      final batch = Batch(
        id: 1,
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        teacherId: 2,
      );

      final map = batch.toMap();
      
      expect(map['id'], 1);
      expect(map['name'], 'Morning Batch');
      expect(map['timing'], '08:00 AM - 10:00 AM');
      expect(map['teacher_id'], 2);

      final deserializedBatch = Batch.fromMap(map);
      
      expect(deserializedBatch.id, 1);
      expect(deserializedBatch.name, 'Morning Batch');
      expect(deserializedBatch.timing, '08:00 AM - 10:00 AM');
      expect(deserializedBatch.teacherId, 2);
    });

    test('Batch copyWith works correctly', () {
      final batch = Batch(
        id: 1,
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        teacherId: 2,
      );

      final updatedBatch = batch.copyWith(name: 'Evening Batch', timing: '04:00 PM - 06:00 PM');
      
      expect(updatedBatch.id, 1);
      expect(updatedBatch.name, 'Evening Batch');
      expect(updatedBatch.timing, '04:00 PM - 06:00 PM');
      expect(updatedBatch.teacherId, 2);
    });
  });
}
