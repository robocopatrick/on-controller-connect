Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Parent $scriptPath
$bat = Join-Path $scriptDirectory "controllerconnected.bat"
$log = Join-Path $scriptDirectory "controller.log"
$gamePathFile = Join-Path $scriptDirectory "controller-game.txt"
$launchGameFile = Join-Path $scriptDirectory "launch-game-on-connect.txt"
$monitorSwitcher = "C:\Users\pat\Documents\Setups\MonitorProfileSwitcher_v0700\MonitorSwitcher.exe"
$tvProfile = "C:\Users\pat\AppData\Roaming\MonitorSwitcher\Profiles\TV.xml"
$startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "PS5 Controller Monitor.lnk"
$launchGameValue = if (Test-Path $launchGameFile) { Get-Content $launchGameFile -Raw } else { "" }
$gamePathValue = if (Test-Path $gamePathFile) { Get-Content $gamePathFile -Raw } else { "" }
if ($null -eq $launchGameValue) { $launchGameValue = "" }
if ($null -eq $gamePathValue) { $gamePathValue = "" }

$state = [hashtable]::Synchronized(@{
    Connected = $false
    HasPreviousState = $false
    Monitoring = $true
    SwitchToTv = $true
    LaunchGame = $launchGameValue.Trim() -eq "true"
    GamePath = $gamePathValue.Trim()
})

function Write-TrayLog([string]$message) {
    Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
}

function Test-ControllerConnected {
    Import-Module PnpDevice -ErrorAction SilentlyContinue
    $controllers = @(Get-PnpDevice -Class HIDClass -ErrorAction SilentlyContinue | Where-Object {
        $_.HardwareID -match "HID_DEVICE_SYSTEM_GAME"
    })
    $connectedDevices = @($controllers | Where-Object { $_.Status -match "^OK$" })
    return [bool]$connectedDevices
}

function Write-ControllerState([bool]$connected) {
    $eventState = if ($connected) { "Connected" } else { "Disconnected" }
    Start-Process -FilePath $env:ComSpec -ArgumentList @(
        "/d",
        "/c",
        "`"$bat`" $eventState"
    ) -WorkingDirectory $scriptDirectory -WindowStyle Hidden -Wait
}

function Switch-ToTvProfile {
    if (-not (Test-Path $monitorSwitcher) -or -not (Test-Path $tvProfile)) {
        return
    }

    Start-Process -FilePath $monitorSwitcher -ArgumentList "-load:`"$tvProfile`"" -WindowStyle Hidden -Wait
}

function Set-GamePath([string]$path) {
    $state.GamePath = $path
    if ([string]::IsNullOrWhiteSpace($path)) {
        if (Test-Path $gamePathFile) {
            Remove-Item $gamePathFile -Force
        }
        return
    }

    Set-Content -Path $gamePathFile -Value $path -Encoding UTF8
}

function Launch-ConfiguredGame {
    if ([string]::IsNullOrWhiteSpace($state.GamePath) -or -not (Test-Path $state.GamePath -PathType Leaf)) {
        return
    }

    Start-Process -FilePath $state.GamePath -WorkingDirectory (Split-Path $state.GamePath -Parent)
}

function Set-StartupShortcut([bool]$enabled) {
    if ($enabled) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupShortcut)
        $shortcut.TargetPath = (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $shortcut.WorkingDirectory = $scriptDirectory
        $shortcut.Description = "Monitor PS5 controller connection state"
        $shortcut.Save()
    } elseif (Test-Path $startupShortcut) {
        Remove-Item $startupShortcut -Force
    }
}

function New-GamepadIcon([bool]$connected) {
    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $symbolColor = if ($connected) {
        [System.Drawing.Color]::White
    } else {
        [System.Drawing.Color]::FromArgb(255, 145, 145, 145)
    }
    $symbolPen = New-Object System.Drawing.Pen($symbolColor, 2)

    $triangle = [System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point(20, 5)),
        (New-Object System.Drawing.Point(16, 13)),
        (New-Object System.Drawing.Point(24, 13))
    )
    $graphics.DrawRectangle($symbolPen, 6, 5, 8, 8)
    $graphics.DrawPolygon($symbolPen, $triangle)
    $graphics.DrawLine($symbolPen, 6, 22, 14, 30)
    $graphics.DrawLine($symbolPen, 14, 22, 6, 30)
    $graphics.DrawEllipse($symbolPen, 17, 21, 8, 8)

    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $graphics.Dispose()
    $symbolPen.Dispose()
    $bitmap.Dispose()
    return $icon
}

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon = New-GamepadIcon $false
$notifyIcon.Icon = $trayIcon
$notifyIcon.Visible = $true
$notifyIcon.Text = "PS5 Controller Monitor"

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = $contextMenu.Items.Add("Status: starting...")
$statusItem.Enabled = $false
$contextMenu.Items.Add("-") | Out-Null

$monitorItem = $contextMenu.Items.Add("Monitoring enabled")
$monitorItem.CheckOnClick = $true
$monitorItem.Checked = $true

$tvItem = $contextMenu.Items.Add("Switch to TV profile on connect")
$tvItem.CheckOnClick = $true
$tvItem.Checked = $true

$launchGameItem = $contextMenu.Items.Add("Launch game on connect")
$launchGameItem.CheckOnClick = $true
$launchGameItem.Checked = $state.LaunchGame
$selectedGameItem = $contextMenu.Items.Add("Selected game: $(if ([string]::IsNullOrWhiteSpace($state.GamePath)) { 'none' } else { [System.IO.Path]::GetFileName($state.GamePath) })")
$selectedGameItem.Enabled = $false
$chooseGameItem = $contextMenu.Items.Add("Choose game executable...")
$clearGameItem = $contextMenu.Items.Add("Clear game executable")
$clearGameItem.Enabled = -not [string]::IsNullOrWhiteSpace($state.GamePath)

$startupItem = $contextMenu.Items.Add("Launch at login")
$startupItem.CheckOnClick = $true
$startupItem.Checked = Test-Path $startupShortcut

$refreshItem = $contextMenu.Items.Add("Check now")
$openLogItem = $contextMenu.Items.Add("Open log")
$contextMenu.Items.Add("-") | Out-Null
$exitItem = $contextMenu.Items.Add("Exit")
$notifyIcon.ContextMenuStrip = $contextMenu

function Set-TrayIcon([bool]$connected) {
    $newIcon = New-GamepadIcon $connected
    $oldIcon = $notifyIcon.Icon
    $notifyIcon.Icon = $newIcon
    $script:trayIcon = $newIcon
    if ($oldIcon) {
        $oldIcon.Dispose()
    }
}

$updateStatus = {
    $stateText = if ($state.Connected) { "Connected" } else { "Disconnected" }
    $statusItem.Text = "Status: $stateText"
    $notifyIcon.Text = "PS5 Controller: $stateText"
}

$checkController = {
    if (-not $state.Monitoring) {
        return
    }

    try {
        $isConnected = Test-ControllerConnected
        if (-not $state.HasPreviousState -or $isConnected -ne $state.Connected) {
            $state.Connected = $isConnected
            $state.HasPreviousState = $true
            Set-TrayIcon $isConnected
            & $updateStatus

            try {
                Write-ControllerState $isConnected
                if ($isConnected -and $state.SwitchToTv) {
                    Switch-ToTvProfile
                }
                if ($isConnected -and $state.LaunchGame) {
                    Launch-ConfiguredGame
                }
            } catch {
                Write-TrayLog "Tray action failed: $($_.Exception.Message)"
            }
        }
    } catch {
        $statusItem.Text = "Status: error"
        $notifyIcon.Text = "PS5 Controller: error"
        Write-TrayLog "Tray check failed: $($_.Exception.Message)"
    }
}

$monitorItem.Add_Click({
    $state.Monitoring = $monitorItem.Checked
    if ($state.Monitoring) {
        $state.HasPreviousState = $false
        & $checkController
    }
})

$tvItem.Add_Click({ $state.SwitchToTv = $tvItem.Checked })
$launchGameItem.Add_Click({
    $state.LaunchGame = $launchGameItem.Checked
    Set-Content -Path $launchGameFile -Value $state.LaunchGame -Encoding UTF8
})
$chooseGameItem.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Game executables (*.exe)|*.exe|All files (*.*)|*.*"
    $dialog.Title = "Choose a game executable"
    if (-not [string]::IsNullOrWhiteSpace($state.GamePath) -and (Test-Path $state.GamePath)) {
        $dialog.FileName = $state.GamePath
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Set-GamePath $dialog.FileName
        $selectedGameItem.Text = "Selected game: $([System.IO.Path]::GetFileName($state.GamePath))"
        $clearGameItem.Enabled = $true
    }
    $dialog.Dispose()
})
$clearGameItem.Add_Click({
    Set-GamePath ""
    $selectedGameItem.Text = "Selected game: none"
    $clearGameItem.Enabled = $false
})
$startupItem.Add_Click({ Set-StartupShortcut $startupItem.Checked })
$refreshItem.Add_Click({
    $state.HasPreviousState = $false
    & $checkController
})
$openLogItem.Add_Click({ Start-Process notepad.exe $log })
$exitItem.Add_Click({ $notifyIcon.Visible = $false; $applicationContext.ExitThread() })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick($checkController)

$applicationContext = New-Object System.Windows.Forms.ApplicationContext
$timer.Start()
& $checkController
[System.Windows.Forms.Application]::Run($applicationContext)

$timer.Stop()
$notifyIcon.Dispose()
$trayIcon.Dispose()
$contextMenu.Dispose()