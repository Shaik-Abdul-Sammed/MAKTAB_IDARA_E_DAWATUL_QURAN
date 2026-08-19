- `[x]` **1. Core Database & Models**
  - `[x]` Update `DatabaseHelper` to version 5, add `dob` column to `users` table.
  - `[x]` Fix SQLite errors in v4 by adding `IF NOT EXISTS` to index creation.
  - `[x]` Add `dob` field to `User` model.
  - `[x]` Add `dob` field to `UserDTO` model.

- `[x]` **2. Authentication & Routing**
  - `[x]` Update `router.dart` redirect logic for `/welcome` and `/register`.
  - `[x]` Update `router.dart` to prevent auto-skipping Face Verification for teachers.
  - `[x]` Update `auth_provider.dart` to support persistent sessions (`initialize()`).
  - `[x]` Update `auth_provider.dart` to use `dob` instead of `000000` for `resetAdminPin()`.
  
- `[x]` **3. Registration UI**
  - `[x]` Add Date of Birth (DOB) field to `RegisterScreen`.
  - `[x]` Update `LoginScreen` forgot PIN dialog to use Date of Birth.

- `[x]` **4. Calendar Feature**
  - `[x]` Implement Calendar view for attendance/events on Teacher Dashboard (Improvement #58).

- `[x]` **5. Bug Fixes & Navigation**
  - `[x]` Fix all ListTile assertion errors across screens.
  - `[x]` Link Messages between Admin and Teachers (`/chat/:id`).
  - `[x]` Add External Support screen linking.
  - `[x]` Fix Test failures (auth_provider_test).
