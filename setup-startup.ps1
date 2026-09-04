$scriptPath = Join-Path $PSScriptRoot "controllertray.ps1"
$startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "PS5 Controller Monitor.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = "Monitor PS5 controller connection state"
$shortcut.Save()

Write-Host "Startup shortcut created: $startupShortcut"