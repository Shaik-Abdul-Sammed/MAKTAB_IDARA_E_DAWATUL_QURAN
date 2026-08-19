import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/quran_progress.dart';

void main() {
  group('QuranProgress Model Tests', () {
    test('QuranProgress serialization and deserialization', () {
      final progress = QuranProgress(
        id: 1,
        studentId: 2,
        date: '2023-10-27',
        surah: 'Al-Fatihah',
        ayahFrom: 1,
        ayahTo: 7,
        grade: 'A',
      );

      final map = progress.toMap();
      expect(map['id'], 1);
      expect(map['student_id'], 2);
      expect(map['grade'], 'A');

      final deserialized = QuranProgress.fromMap(map);
      expect(deserialized.id, 1);
      expect(deserialized.studentId, 2);
      expect(deserialized.surah, 'Al-Fatihah');
      expect(deserialized.ayahTo, 7);
    });
  });
}
