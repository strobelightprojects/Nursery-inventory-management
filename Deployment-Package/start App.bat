@echo off
title Nursery Inventory Server Manager

REM 1. Start the backend server quietly in the background
start /min "" "api_server.exe"

REM 2. Wait for 3 seconds to ensure the server process is listening on port 5000
timeout /t 3 /nobreak >nul

REM 3. Start the main Flutter client. The VBScript wrapper waits here until the client closes.
start /wait "" "nursery_inventory_app.exe"

REM 4. When the Flutter app closes, kill the backend process
taskkill /IM api_server.exe /F