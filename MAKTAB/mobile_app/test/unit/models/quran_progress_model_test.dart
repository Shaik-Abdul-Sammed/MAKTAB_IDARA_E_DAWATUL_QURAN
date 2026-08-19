import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/quran_progress.dart';

void main() {
  group('QuranProgress Model Unit Tests', () {
    final qpMap = {
      'id': 200,
      'student_id': 1,
      'date': '2026-08-05',
      'surah': 'Surah Al-Baqarah (2)',
      'ayah_from': 1,
      'ayah_to': 10,
      'grade': 'A+',
      'remarks': 'Excellent makhraj',
    };

    test('fromMap should construct QuranProgress correctly', () {
      final qp = QuranProgress.fromMap(qpMap);
      expect(qp.id, 200);
      expect(qp.studentId, 1);
      expect(qp.surah, 'Surah Al-Baqarah (2)');
      expect(qp.ayahFrom, 1);
      expect(qp.ayahTo, 10);
      expect(qp.grade, 'A+');
      expect(qp.remarks, 'Excellent makhraj');
    });

    test('toMap should convert QuranProgress to Map correctly', () {
      final qp = QuranProgress(
        id: 200,
        studentId: 1,
        date: '2026-08-05',
        surah: 'Surah Al-Baqarah (2)',
        ayahFrom: 1,
        ayahTo: 10,
        grade: 'A+',
        remarks: 'Excellent makhraj',
      );
      final map = qp.toMap();
      expect(map['id'], 200);
      expect(map['surah'], 'Surah Al-Baqarah (2)');
      expect(map['ayah_from'], 1);
      expect(map['ayah_to'], 10);
      expect(map['grade'], 'A+');
    });
  });
}
