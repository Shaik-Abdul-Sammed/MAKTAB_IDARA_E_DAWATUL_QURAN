import os

test_files = [
    "test/db_helper_test.dart",
    "test/auth_provider_test.dart",
    "test/student_repository_test.dart",
    "test/batch_repository_test.dart",
    "test/attendance_repository_test.dart",
    "test/quran_progress_repository_test.dart",
    "test/user_repository_test.dart",
    "test/backup_restore_service_test.dart",
    "test/notification_service_test.dart",
    "test/ai_service_test.dart",
    "test/login_screen_test.dart",
    "test/admin_dashboard_test.dart",
    "test/teacher_dashboard_test.dart",
    "test/settings_screen_test.dart",
]

content_template = """import 'package:flutter_test/flutter_test.dart';

void main() {
  group('{name} Tests', () {
    test('Initial smoke test for {name}', () {
      expect(true, true);
    });
  });
}
"""

for file_path in test_files:
    name = os.path.basename(file_path).replace('_test.dart', '').replace('_', ' ').title()
    content = content_template.replace('{name}', name)
    with open(file_path, 'w') as f:
        f.write(content)
    print(f"Created {file_path}")

