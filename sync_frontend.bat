@echo off
echo ====================================================
echo POS System: Local Sync (Frontend to Backend)
echo ====================================================

:: 1. Build Flutter Web
echo Step 1: Building Flutter Web...
cd frontend
call flutter clean
call flutter build web --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)
cd ..

:: 2. Prepare Backend Public Folder
echo Step 2: Preparing backend/public folder...
if not exist "backend\public" mkdir "backend\public"

:: Clean folder using CMD commands
echo Cleaning old files...
del /s /q "backend\public\*" >nul 2>&1
for /d %%x in ("backend\public\*") do rd /s /q "%%x" >nul 2>&1

:: 3. Copy Build Files
echo Step 3: Copying files to backend/public...
xcopy /E /I /Y "frontend\build\web\*" "backend\public\"

echo ====================================================
echo SUCCESS!
echo.
echo Next Steps:
echo 1. git add backend/public
echo 2. git commit -m "Sync frontend build"
echo 3. git push
echo 4. Render will auto-deploy.
echo ====================================================
pause
