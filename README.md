# On Controller Connect

A small set of Windows PowerShell scripts for detecting connected game controllers and triggering actions when a controller is plugged in or unplugged.

## Included scripts

- `checkconnectedcontrollers.ps1` — checks whether one or more controllers are currently connected.
- `getallcontrollers.ps1` — lists detected controllers.
- `controllerconnected.bat` — wrapper script for launching controller-related actions.
- `controllertray.ps1` — tray/notification helper for controller state changes.
- `setup-startup.ps1` — configures startup behavior for automatic controller monitoring.

## Typical use

Run the PowerShell scripts from Windows with administrative or user privileges as needed, and use the startup helper to enable automatic monitoring when you log in.

When `controllertray.ps1` is running, right-click its system tray icon, choose **Choose game executable...**, and enable **Launch game on connect**. The selected `.exe` is saved in `controller-game.txt` beside the scripts.

## License

Free for personal, educational, and non-commercial use. Commercial use, redistribution as part of a commercial product, or use by a commercial organization requires a paid license.
