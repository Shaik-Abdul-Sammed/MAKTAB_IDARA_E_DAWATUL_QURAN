#!/bin/bash
# One-click startup script for Maktab Manager FastAPI Server (Linux/macOS)

cd "$(dirname "$0")"

if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Installing requirements..."
pip install -r requirements.txt --quiet

echo "========================================================="
echo "   Maktab Manager Self-Hosted REST Backend Server        "
echo "   Listening on: http://0.0.0.0:8000                     "
echo "========================================================="
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
