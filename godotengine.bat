@echo off

cd /d "%~dp0"

for /F %%A in ('powershell.exe -Command "if ($(Get-ExecutionPolicy) -eq \"Restricted\") { echo 1 } else {echo 0}" ') do set policy=%%A
if %policy% EQU 1 (
	echo "Your computer is set to NOT allow PowerShell scripts. Please press any key to continue, you will be asked to allow administrative rights once, than a window will open and close instantly, this will allow PowerShell to run freecad_weekly_installer for the future. If you don't want this: close this window and delete godotengine.bat - it will not work without this change."
	pause
	powershell.exe -Command "Start-Process powershell.exe -Verb runAs -ArgumentList \"-Command Set-ExecutionPolicy RemoteSigned -Force;\""
)

powershell.exe -Command "Invoke-WebRequest https://github.com/Tinsus/godotengine-updater/raw/main/godotengine.ps1 -OutFile godotengine.ps1"
powershell.exe -file "godotengine.ps1"
del "godotengine.ps1"
