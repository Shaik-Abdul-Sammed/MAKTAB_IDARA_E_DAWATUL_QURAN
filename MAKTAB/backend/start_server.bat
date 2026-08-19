@echo off
REM One-click startup script for Maktab Manager FastAPI Server (Windows)

cd /d "%~dp0"

if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
)

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing requirements...
pip install -r requirements.txt --quiet

echo =========================================================
echo    Maktab Manager Self-Hosted REST Backend Server        
echo    Listening on: http://0.0.0.0:8000                     
echo =========================================================
python -m uvicorn main:app --host 0.0.0.0 --port 8000
pause
