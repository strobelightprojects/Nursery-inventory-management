Set shell = CreateObject("Shell.Application")
' Execute the batch file with the "runas" (Admin) verb
shell.ShellExecute "App_Launcher.bat", "", "", "runas", 1