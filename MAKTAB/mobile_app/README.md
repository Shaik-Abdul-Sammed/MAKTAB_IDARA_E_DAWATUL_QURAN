# 📱 Maktab Manager Mobile Application

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android)](https://android.com)

The official Flutter mobile application for **Maktab Idara-e-Dawatul Quran**. Designed for Administrators/Managers and Teachers, featuring full offline SQLite caching and multi-device cloud synchronization over 4G, 5G, or Wi-Fi.

---

## 🎨 Complete Application Feature Suite

### 🔐 Security & Access Control
- **Role-Based Authentication**: Custom portals for Administrators/Managers and Teachers.
- **PIN-Based Sign-In**: Salted SHA-256 password hashing.
- **Biometric Integration**: Instant login using Fingerprint / Face ID (`local_auth`).
- **Lockout Protection**: 5 failed login attempt rate-limiting (30-second lockout). Zero data-loss purge safety.
- **Password Vault**: Central encrypted storage for manager to view and manage user PIN credentials.

### 👨‍💼 Administrator / Manager Dashboard
- **Live Statistics Overview**: Total students count, active batches, teacher headcount, and daily attendance percentages.
- **Batch & Class Management**: Create and configure batches, section names, room numbers, and teacher assignments.
- **Batch Promotion Tool**: Advance students across academic years with a single tap.
- **Teacher Directory & Management**: Add, edit, or deactivate teacher accounts and reset PINs.
- **Student Enrollment**: Complete student registration with guardian phone, roll numbers, Date of Birth (DOB), and photos.
- **Reports & Data Export**: Visual attendance calendars, memorization logs, and CSV/PDF export capabilities.

### 👨‍🏫 Teacher Dashboard
- **Quick Action Hub**: Instant access to mark student attendance, log Quran lessons, and submit daily checklists.
- **Single-Tap Attendance**: Rapid Present/Absent/Late logging for assigned batch students.
- **Quran Progress Tracker**: Record Surah, Ayah range (`from` - `to`), recitation grade, and teacher feedback per student.
- **Daily Checklist**: Track classroom preparation, student discipline, and daily Maktab tasks.
- **Teacher Attendance & Check-In**: Log daily teacher check-in / check-out times with optional face verification.

### 💳 Financial & Administrative Utilities
- **Fee Payment Register**: Track tuition fee collections (amount, payment date, month/year, payment method, receipt number).
- **Payment History Logs**: Historical fee records per student.
- **Settings & Network Config**: Easily view or override the active FastAPI server base URL at runtime.

---

## 🛠️ Technology Stack

- **UI Framework**: Flutter 3.x with Material Design 3
- **State Management**: `Provider` (`ChangeNotifier`)
- **Routing**: `go_router`
- **Local Database**: `sqflite` (SQLite) & `shared_preferences`
- **Network Client**: `http` REST API client with offline retry queue
- **Security**: Local fingerprint / biometric authentication (`local_auth`) and cleartext HTTP support for local IPs.

---

## 🚀 Building & Running

### 1. Static Code Analysis
Verify zero lint or syntax errors:
```bash
flutter analyze lib/
```

### 2. Run on Emulator / Connected Device
```bash
flutter run
```

### 3. Build Release Android APK
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
