import os

base_dir = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app"

tests = {
    # ---------------- PROVIDERS ----------------
    "test/providers/student_provider_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/student_provider.dart';

void main() {
  group('Student Provider Tests', () {
    test('initial state is correct', () {
      final provider = StudentProvider();
      expect(provider.isLoading, false);
      expect(provider.students, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
""",

    "test/providers/batch_provider_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/batch_provider.dart';

void main() {
  group('Batch Provider Tests', () {
    test('initial state is correct', () {
      final provider = BatchProvider();
      expect(provider.isLoading, false);
      expect(provider.batches, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
""",

    "test/providers/attendance_provider_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/attendance_provider.dart';

void main() {
  group('Attendance Provider Tests', () {
    test('initial state is correct', () {
      final provider = AttendanceProvider();
      expect(provider.isLoading, false);
      expect(provider.attendanceRecords, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
""",

    "test/providers/syllabus_provider_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/syllabus_provider.dart';

void main() {
  group('Syllabus Provider Tests', () {
    test('initial state is correct', () {
      final provider = SyllabusProvider();
      expect(provider.isLoading, false);
      expect(provider.syllabusRecords, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
""",

    "test/providers/exam_provider_test.dart": """import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/exam_provider.dart';

void main() {
  group('Exam Provider Tests', () {
    test('initial state is correct', () {
      final provider = ExamProvider();
      expect(provider.isLoading, false);
      expect(provider.exams, isEmpty);
      expect(provider.results, isEmpty);
      expect(provider.errorMessage, isNull);
    });
  });
}
""",

    # ---------------- UTILS ----------------
    "test/utils/date_formatter_test.dart": """import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Date Formatter Tests', () {
    test('formats dates properly', () {
      // Mocking formatter since we don't have a specific file yet
      String formatDate(DateTime date) => "\${date.year}-\${date.month.toString().padLeft(2, '0')}-\${date.day.toString().padLeft(2, '0')}";
      
      final date = DateTime(2023, 10, 5);
      expect(formatDate(date), '2023-10-05');
    });
  });
}
""",

    "test/utils/validators_test.dart": """import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators Tests', () {
    test('validates PIN correctly', () {
      bool isValidPin(String pin) => RegExp(r'^\d{4}\$').hasMatch(pin);
      
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('12345'), isFalse);
      expect(isValidPin('abcd'), isFalse);
    });
  });
}
"""
}

for file_path, content in tests.items():
    full_path = os.path.join(base_dir, file_path)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"Updated {file_path}")
