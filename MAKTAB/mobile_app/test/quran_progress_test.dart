import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/quran_progress.dart';

void main() {
  group('QuranProgress Model Tests', () {
    test('QuranProgress can be created and serialized', () {
      final progress = QuranProgress(
        id: 1,
        studentId: 2,
        date: '2023-10-25',
        surah: 'Al-Fatiha',
        ayahFrom: 1,
        ayahTo: 7,
        grade: 'A',
        remarks: 'Good',
      );

      final map = progress.toMap();
      
      expect(map['id'], 1);
      expect(map['student_id'], 2);
      expect(map['date'], '2023-10-25');
      expect(map['surah'], 'Al-Fatiha');
      expect(map['ayah_from'], 1);
      expect(map['ayah_to'], 7);
      expect(map['grade'], 'A');
      expect(map['remarks'], 'Good');

      final deserialized = QuranProgress.fromMap(map);
      
      expect(deserialized.id, 1);
      expect(deserialized.studentId, 2);
      expect(deserialized.date, '2023-10-25');
      expect(deserialized.surah, 'Al-Fatiha');
      expect(deserialized.ayahFrom, 1);
      expect(deserialized.ayahTo, 7);
      expect(deserialized.grade, 'A');
      expect(deserialized.remarks, 'Good');
    });
  });
}
