# 🏢 Maktab Project Overview & Architecture Guide

Welcome to the core repository for **Maktab Idara-e-Dawatul Quran**. This folder contains the complete source code for both the **Mobile App** and the **Cloud Backend REST API**.

---

## 📁 System Components

### 1. [`mobile_app/`](file:///home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/mobile_app)
- **Framework**: Flutter 3.x (Dart)
- **Local Database**: SQLite (`maktab.db` via `sqflite`)
- **State Management**: Provider Pattern
- **Target OS**: Android & iOS

### 2. [`backend/`](file:///home/rgukt/Github/MAKTAB_IDARA_E_DAWATUL_QURAN/MAKTAB/backend)
- **Framework**: Python 3.9+ / FastAPI / Uvicorn
- **Production Database**: PostgreSQL (or local `maktab_backend.db` SQLite)
- **Hosting**: Render.com Free Tier / Self-Hosted
- **Security**: Salted SHA-256 PIN hashing, CORS, `maktab_id` scoping

---

## 🗄️ Unified Database Schema

Both the local mobile SQLite database and the backend database maintain identical relational schemas:

| Table Name | Primary Key | Key Columns | Purpose |
| :--- | :--- | :--- | :--- |
| `users` | `id` | `maktab_id`, `name`, `pin_hash`, `role`, `mobile` | User accounts (Admin & Teacher) |
| `batches` | `id` | `maktab_id`, `name`, `section`, `teacher_id` | Class/Batch groupings |
| `students` | `id` | `maktab_id`, `name`, `guardian_name`, `batch_id` | Enrolled student profiles |
| `attendance` | `id` | `maktab_id`, `student_id`, `date`, `status` | Daily student attendance records |
| `teacher_attendance` | `id` | `maktab_id`, `teacher_id`, `date`, `status` | Teacher attendance logs |
| `quran_progress` | `id` | `maktab_id`, `student_id`, `surah`, `grade` | Quran recitation & memorization tracking |
| `fee_payments` | `id` | `maktab_id`, `student_id`, `amount`, `month`, `year` | Student tuition fee collection logs |

---

## 🔐 Multi-Device Synchronization Flow

```text
[Phone A: Manager]                    [Cloud Server: FastAPI]                  [Phone B: Teacher]
        │                                        │                                      │
   (Creates Student)                             │                                      │
        │                                        │                                      │
        ├─── POST /api/v1/sync/push ────────────►│                                      │
        │    (Save to Cloud PostgreSQL)          │                                      │
        │                                        │                                      │
        │                                        │◄─── GET /api/v1/sync/pull/maktab_id ─┤
        │                                        │     (Returns updated records)        │
        │                                        │                                      │
        │                                        ├─────────────────────────────────────►│
        │                                        │                                (Student Appears)
```

---

## 🛠️ Developer Commands

```bash
# Analyze Flutter code
cd mobile_app && flutter analyze lib/

# Build release Android APK
cd mobile_app && flutter build apk --release

# Run FastAPI backend locally
cd backend && python3 main.py

# Migrate SQLite data to PostgreSQL
cd backend && python3 migrate_to_postgres.py
```
