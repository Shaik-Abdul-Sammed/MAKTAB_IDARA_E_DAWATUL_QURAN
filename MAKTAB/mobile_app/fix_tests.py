import glob
import os

test_files = [
    "test/auth_provider_test.dart",
    "test/backup_restore_service_test.dart",
    "test/repositories/attendance_repository_test.dart",
    "test/repositories/batch_repository_test.dart",
    "test/repositories/quran_progress_repository_test.dart",
    "test/repositories/student_repository_test.dart",
    "test/repositories/user_repository_test.dart",
    "test/teacher_admin_connection_test.dart"
]

for file in test_files:
    path = os.path.join(".", file)
    with open(path, "r") as f:
        content = f.read()

    # ensure import DatabaseHelper exists
    if "import 'package:maktab_app/services/database_helper.dart';" not in content:
        content = "import 'package:maktab_app/services/database_helper.dart';\n" + content

    if "await DatabaseHelper.instance.close();\n    await databaseFactory.deleteDatabase" not in content:
        content = content.replace(
            "await databaseFactory.deleteDatabase",
            "await DatabaseHelper.instance.close();\n    await databaseFactory.deleteDatabase"
        )
        
    with open(path, "w") as f:
        f.write(content)
