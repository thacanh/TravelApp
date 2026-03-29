@echo off
echo ================================
echo   Starting TRAWiMe Backend
echo ================================
echo.

call venv\Scripts\activate
echo Backend starting at http://localhost:8000
echo API Docs at http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop
echo.
uvicorn app.main:app --reload
