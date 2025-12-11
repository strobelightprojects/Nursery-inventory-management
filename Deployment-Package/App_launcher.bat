@echo off
:: Start the server silently, then launch the client
start /min "" "api_server.exe"
start "" "nursery_inventory_app.exe"