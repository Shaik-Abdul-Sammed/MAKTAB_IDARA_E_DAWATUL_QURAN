# ⚡ Maktab Manager FastAPI REST Backend (₹0 Cost)

[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supported-4169E1?logo=postgresql)](https://postgresql.org)
[![Render](https://img.shields.io/badge/Render-Deployed-000000?logo=render)](https://render.com)

The self-hosted Python FastAPI REST API server powering multi-device synchronization for **Maktab Manager**. Designed to run on **100% Free Cloud Infrastructure ($0/month)** or local servers.

---

## ⚡ Features

- **Lifespan Context Management**: Modern, clean startup initialization without deprecated handlers.
- **Dual Database Driver**: Connects automatically to **PostgreSQL** when `DATABASE_URL` is set, or falls back to local persistent **SQLite** (`maktab_backend.db`).
- **Multi-Tenant Isolation**: Enforces `maktab_id` scoping across all REST endpoints.
- **Environment Configuration**: Automatic `.env` loading via `python-dotenv`.
- **Render 1-Click Deployment**: Pre-configured `render.yaml` specification.

---

## 🌐 Production REST API Endpoints

```http
GET  /health
POST /api/v1/auth/login
POST /api/v1/sync/push
GET  /api/v1/sync/pull/{maktab_id}
```

### Endpoint Reference

#### 1. Health Check
- **URL**: `GET /health`
- **Response**:
```json
{
  "status": "ok",
  "service": "Maktab Manager REST API",
  "database": "Local Persistent SQLite",
  "environment": "Production Cloud / Self-Hosted"
}
```

#### 2. Authentication
- **URL**: `POST /api/v1/auth/login`
- **Body**: `{"pin_hash": "<SHA256_HASH>"}`
- **Response**: User object & `maktab_id`.

#### 3. Push Records (Offline to Cloud)
- **URL**: `POST /api/v1/sync/push`
- **Body**: Array of updated users, batches, students, attendance, Quran progress, and fee records.

#### 4. Pull Records (Cloud to Mobile)
- **URL**: `GET /api/v1/sync/pull/{maktab_id}`
- **Response**: Complete latest database snapshot for the given `maktab_id`.

---

## 🛠️ Local Installation & Execution

### 1. Linux / macOS
```bash
cd MAKTAB/backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start backend server
python3 main.py
```

### 2. Windows (PowerShell)
```powershell
cd MAKTAB\backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py
```

---

## ☁️ Deploying to Render.com (100% Free / $0 Month)

1. Sign up at [https://render.com](https://render.com) (No credit card required).
2. Click **New +** → **Web Service** → Connect your GitHub Repository.
3. Configure settings:
   - **Root Directory**: `MAKTAB/backend`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. Deploy! Your backend will be live at `https://<your-app>.onrender.com`.

---

## 🔄 SQLite to PostgreSQL Data Migration

If you have existing data in `maktab_backend.db` that you wish to transfer to your cloud PostgreSQL database:

```bash
cd MAKTAB/backend
export DATABASE_URL="postgresql://user:password@host:5432/maktab_db"
python3 migrate_to_postgres.py
```
*Script executes idempotently using `ON CONFLICT(id) DO UPDATE` to prevent duplicates.*
