@echo off
echo ================================
echo   TRAWiMe Backend Setup
echo ================================
echo.

echo [1/5] Creating virtual environment...
python -m venv venv

echo [2/5] Activating virtual environment...
call venv\Scripts\activate

echo [3/5] Installing dependencies...
pip install -r requirements.txt

echo [4/5] Setup complete!
echo.
echo Next steps:
echo 1. Create PostgreSQL database: trawime_db
echo 2. Update DATABASE_URL in .env file
echo 3. Run: python seed_data.py (optional)
echo 4. Run: uvicorn app.main:app --reload
echo.
echo API will be available at: http://localhost:8000
echo API Docs at: http://localhost:8000/docs
echo.
pause
