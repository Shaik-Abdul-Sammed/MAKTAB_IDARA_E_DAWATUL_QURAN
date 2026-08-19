# Maktab Manager Self-Hosted REST API Backend (₹0 Cost)

This is the **100% Free ($0/month)** self-hosted REST API backend for the **Maktab Manager** mobile application.

## Prerequisites
- Python 3.9 or higher

## Linux Setup & Execution
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

## Windows Setup & Execution (PowerShell)
```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

## Automated Local Database Backup
```bash
chmod +x backup.sh
./backup.sh
```

## Endpoints
- `GET /health` -> Health check status
- `POST /api/v1/auth/login` -> Teacher / Admin PIN authentication
- `POST /api/v1/sync/push` -> Push local offline records to backend DB
- `GET /api/v1/sync/pull/{maktab_id}` -> Download remote records for a Maktab
