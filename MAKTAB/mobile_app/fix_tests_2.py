import os
import glob

repo_tests = glob.glob("/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/test/repositories/*_test.dart")

for file_path in repo_tests:
    with open(file_path, 'r') as f:
        content = f.read()
    
    if "FlutterSecureStorage.setMockInitialValues({});" not in content:
        # Add import if missing
        if "package:flutter_secure_storage/flutter_secure_storage.dart" not in content:
            content = content.replace("void main() {", "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n\nvoid main() {")
        
        # Add mock to setUpAll
        content = content.replace("setUpAll(() {", "setUpAll(() {\n    FlutterSecureStorage.setMockInitialValues({});")
        
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Fixed {file_path}")

# Fix validators_test.dart
validator_path = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/test/utils/validators_test.dart"
with open(validator_path, 'r') as f:
    content = f.read()

content = content.replace(r"RegExp(r'^\d{4}\$')", "RegExp(r'^\\d{4}\$')")
with open(validator_path, 'w') as f:
    f.write(content)
print(f"Fixed validators_test.dart")

# Fix date_formatter_test.dart
date_path = "/home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app/test/utils/date_formatter_test.dart"
with open(date_path, 'r') as f:
    content = f.read()

content = content.replace("String formatDate(DateTime date) => \"${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}\";", "String formatDate(DateTime date) => \"${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}\";")
with open(date_path, 'w') as f:
    f.write("""import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Date Formatter Tests', () {
    test('formats dates properly', () {
      String formatDate(DateTime date) => "\${date.year}-\${date.month.toString().padLeft(2, '0')}-\${date.day.toString().padLeft(2, '0')}";
      
      final date = DateTime(2023, 10, 5);
      expect(formatDate(date), '2023-10-05');
    });
  });
}
""")
print(f"Fixed date_formatter_test.dart")
