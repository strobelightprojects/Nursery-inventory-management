' Launch the Python backend silently
Set WshShell = CreateObject("WScript.Shell")
' The /c tells cmd.exe to execute the command and then terminate
' The /min tells it to start minimized (optional)
WshShell.Run "cmd.exe /c ""{app}\api_backend.exe""", 0, false 

' Wait a moment for the server to spin up
WScript.Sleep 5000 ' 5 seconds (adjust if needed)

' Launch the Flutter frontend
WshShell.Run """{app}\nursery_inventory_app.exe""", 1, false 

Set WshShell = Nothing