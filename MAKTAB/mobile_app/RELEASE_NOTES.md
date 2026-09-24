# Maktab App — Release Notes

## Version
1.0.0

## Core features
- Manager login via Firebase email/password
- Teacher login via Teacher ID + PIN (offline-capable)
- Student management (add, edit, batch assignment)
- Attendance marking (manual + voice)
- Attendance history (per batch, per student, grouped by date)
- Quran progress tracking
- Teacher attendance (marked by manager, synced to teacher device)
- Cross-device sync via Firebase RTDB

## Known limitations
- Firebase Auth accounts of deleted teachers are orphaned (require manual deletion in Firebase Console, or a future Cloud Function).
- Voice attendance supports en_IN locale. Other locales fall back to device default.
- Offline mode queues writes; sync resumes on reconnect.
- Push notifications (OS-level) not yet implemented. In-app bell notifications work; system tray alerts require FCM integration.

## Sync architecture
- Cloud Firestore/RTDB: Firebase Realtime Database
- Local: SQLite with `is_synced` flags
- Push-before-pull on app resume
- Single-flight pull guard prevents storms
- Role-aware collection lists (teachers do not pull salary_payments or fee_payments)

## Security
- RTDB rules scoped by `maktabId` and `role`
- Teacher credentials stored in `flutter_secure_storage`
- Manager/teacher Firebase Auth passwords derived from SHA-256 of PIN with salt

## Build
- `flutter build apk --release --target-platform=android-arm64 --tree-shake-icons`
- Output: `build/app/outputs/flutter-apk/app-release.apk`
