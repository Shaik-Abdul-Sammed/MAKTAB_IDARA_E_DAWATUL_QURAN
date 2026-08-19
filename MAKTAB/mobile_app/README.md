# 📱 Maktab Manager Mobile Application

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android)](https://android.com)

The official Flutter mobile application for **Maktab Idara-e-Dawatul Quran**. Provides role-based workflows for Administrators/Managers and Teachers with full offline caching and multi-device cloud synchronization.

---

## 🎨 App Features & Modules

### 👨‍💼 Administrator / Manager Portal
- **Dashboard**: High-level overview of total students, active batches, teachers, and attendance statistics.
- **Batch Management**: Create, assign, and manage class sections and room assignments.
- **Teacher Directory**: Manage teacher accounts, assigned batches, and PIN credentials.
- **Student Directory**: Full student enrollment, academic history, and guardian contact details.
- **Reports & Analytics**: Visual attendance calendars, Quran progress history, and fee payment exports.
- **Password Vault**: Encrypted pin and password manager for system personnel.

### 👨‍🏫 Teacher Portal
- **Teacher Dashboard**: Daily quick-actions for marking attendance and recording Quran progress.
- **Attendance Marking**: Single-tap present/absent/late status logging for assigned batches.
- **Quran Progress Tracker**: Log Surah, Ayah ranges, recitation grades, and teacher notes per student.
- **Daily Checklist**: Track daily Maktab tasks and classroom preparation logs.

---

## 🛠️ Technology Stack

- **UI Framework**: Flutter 3.x with Material Design 3
- **State Management**: `Provider` (`ChangeNotifier`)
- **Routing**: `go_router`
- **Local Persistence**: `sqflite` (SQLite) & `shared_preferences`
- **Network Client**: `http` REST API client with offline retry queue
- **Security**: Local fingerprint / biometric authentication (`local_auth`) and cleartext HTTP support for local IPs.

---

## 🚀 Building & Running

### 1. Prerequisites
- Flutter SDK 3.x installed on your PATH.
- Android SDK / Android Studio (for Android build).

### 2. Static Analysis
Verify that there are zero lint or syntax errors:
```bash
flutter analyze lib/
```

### 3. Run on Emulator / Device
```bash
flutter run
```

### 4. Build Release Android APK
Generate the release APK file for distribution to Manager and Teacher mobile devices:
```bash
flutter build apk --release
```
**Output File**:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🌐 Server URL Configuration

The app defaults to the production cloud HTTPS backend:
`https://maktab-idara-e-dawatul-quran.onrender.com`

Users can also view or update the active FastAPI Server URL inside the app by going to:
**Settings → Server & Network Sync → FastAPI Server URL**.
