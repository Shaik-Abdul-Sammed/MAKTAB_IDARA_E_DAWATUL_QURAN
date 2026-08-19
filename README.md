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

## 🌟 Key Features

- 📱 **Cross-Platform Mobile App**: Modern, responsive Flutter application for Android & iOS.
- ⚡ **Offline-First Architecture**: Local SQLite caching (`maktab.db`) ensures zero-latency user interaction even without an internet connection.
- ☁️ **Self-Hosted FastAPI Backend**: Lightweight Python REST API deployed for **₹0/month** on cloud hosts (Render / Koyeb) or local servers.
- 🔄 **Multi-Device Cloud Sync**: Real-time REST synchronization allowing Managers and Teachers to connect seamlessly from anywhere in the world on 4G, 5G, or Wi-Fi.
- 🔒 **Security & Multi-Tenant Isolation**: PIN hashing, optional JWT tokens, rate-limiting lockout protection, and strict `maktab_id` data isolation.
- 📚 **Quran Progress Tracking**: Detailed logging of Surah, Ayah ranges, grades, and teacher feedback for every student.
- 📅 **Smart Attendance**: Attendance tracking for both Students and Teachers with history logs and visual calendar views.
- 💳 **Fee Payments & Password Vault**: Comprehensive fee collection records, receipt generation, and encrypted credential management.

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