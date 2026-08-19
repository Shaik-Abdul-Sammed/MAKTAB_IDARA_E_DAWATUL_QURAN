# 📖 Maktab Idara-e-Dawatul Quran Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supported-4169E1?logo=postgresql)](https://postgresql.org)
[![SQLite](https://img.shields.io/badge/SQLite-Offline_First-003B57?logo=sqlite)](https://sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Cost](https://img.shields.io/badge/Cost-₹0%20%2F%20%240%20Month-brightgreen)](#-zero-cost-infrastructure)

An enterprise-grade, offline-first **Maktab Quran School Management Platform** designed for multi-device synchronization across mobile networks (4G/5G/Wi-Fi) at **₹0 / $0 monthly infrastructure cost**.

---

## 🌟 Comprehensive App Features

### 🔐 1. Authentication & Security
- **Dual-Role Access Control**: Separate, tailored interfaces for Administrators/Managers and Teachers.
- **PIN Authentication**: Fast, secure 4-digit PIN login backed by salted SHA-256 hashing.
- **Biometric Authentication**: Fingerprint and Face ID support for quick unlock (`local_auth`).
- **Lockout Protection**: Temporary 30-second lockout after 5 failed login attempts to prevent brute-force access.
- **Password & PIN Vault**: Secure central vault for managers to manage and retrieve all personnel PINs.

### 👥 2. Student & Batch Management
- **Student Profiles**: Comprehensive student records including guardian name/phone, admission date, roll number, Date of Birth (DOB), and photo.
- **Batch / Class Organization**: Create and manage classes, sections, room assignments, and primary teacher allocations.
- **Academic Promotion**: One-click batch promotion tool to advance students to the next academic level.

### 📖 3. Quran Progress Tracker
- **Recitation & Memorization Logs**: Record Surah name, Ayah range (`from` - `to`), performance grades, and teacher notes.
- **Progress History**: Track historical recitation records and memorization milestones per student.

### 📅 4. Attendance Tracking & Analytics
- **Student Attendance**: Mark daily attendance (Present / Absent / Late) with instant batch progress updates.
- **Teacher Attendance**: Log teacher daily attendance, check-in / check-out times, and optional face verification.
- **Interactive Calendar Views**: Visual monthly calendar views for student and batch attendance tracking.

### 💳 5. Fee Collection & Receipts
- **Tuition Fee Vault**: Record fee payments with amount, payment date, month/year, payment method, and receipt numbers.
- **Payment History**: View detailed financial records and payment status per student.

### ⚡ 6. Offline-First & Multi-Device Sync
- **Local SQLite Caching**: Local database (`maktab.db`) ensures zero-latency UI performance even without an internet connection.
- **Cloud REST Synchronization**: Bi-directional REST sync with self-hosted FastAPI backend over 4G, 5G, or Wi-Fi.

---

## 🏗️ System Architecture

```text
                                INTERNET
                                   │
               ┌───────────────────┼───────────────────┐
               │                   │                   │
               ▼                   ▼                   ▼
          Manager Phone       Teacher Phone 1     Teacher Phone 2
             (5G/4G)             (4G/5G)             (Wi-Fi)
               │                   │                   │
               └───────────────────┼───────────────────┘
                                   │
                                 HTTPS
                                   │
                                   ▼
                      ┌─────────────────────────┐
                      │    FREE CLOUD HOST      │
                      │  (Render.com / Koyeb)   │
                      │  FastAPI REST Server    │
                      └────────────┬────────────┘
                                   │
                                   ▼
                      ┌─────────────────────────┐
                      │   PERSISTENT DATABASE   │
                      │  (PostgreSQL / SQLite)  │
                      └─────────────────────────┘
```

---

## 📂 Repository Structure

```text
MAKTAB_IDARA_E_DAWATUL_QURAN/
├── MAKTAB/
│   ├── backend/               # Python FastAPI REST API Backend
│   │   ├── main.py            # API Routes & Lifespan Handlers
│   │   ├── database.py        # Dual-Driver Database Engine (PostgreSQL / SQLite)
│   │   ├── migrate_to_postgres.py # Data Migration Utility
│   │   ├── render.yaml        # Render 1-Click Cloud Deployment Spec
│   │   └── requirements.txt   # Python Dependencies
│   └── mobile_app/            # Flutter Mobile Application
│       ├── lib/               # Dart Source Code (UI, Providers, Repositories)
│       ├── android/           # Android Native Project Configuration
│       ├── ios/               # iOS Native Project Configuration
│       └── pubspec.yaml       # Flutter Project Dependencies
└── README.md                  # System Documentation
```

---

## 🚀 Quick Start Guide

### 1. Running the FastAPI Backend Locally
```bash
# Navigate to backend directory
cd MAKTAB/backend

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start local server
python3 main.py
```
*API will run at `http://0.0.0.0:8000` with health check available at `http://localhost:8000/health`.*

### 2. Building the Flutter Mobile App
```bash
# Navigate to mobile app directory
cd MAKTAB/mobile_app

# Install dependencies
flutter pub get

# Run static code analysis
flutter analyze lib/

# Build production release APK
flutter build apk --release
```
*Generated APK location: `MAKTAB/mobile_app/build/app/outputs/flutter-apk/app-release.apk`*

---

## 💰 Zero-Cost Infrastructure

| Component | Technology / Host | Cost | Notes |
| :--- | :--- | :--- | :--- |
| **Mobile App** | Flutter | **₹0 / $0** | Open-source, compiled native Android APK |
| **Backend API** | FastAPI / Python | **₹0 / $0** | Hosted on Render Free Web Service |
| **Production Database** | PostgreSQL / SQLite | **₹0 / $0** | Render Free PostgreSQL / Local Persistent Disk |
| **Authentication** | Custom PIN + Salt | **₹0 / $0** | Server-side security, zero third-party auth fees |

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for details.