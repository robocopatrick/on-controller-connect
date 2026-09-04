Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Parent $scriptPath
$bat = Join-Path $scriptDirectory "controllerconnected.bat"
$log = Join-Path $scriptDirectory "controller.log"
$monitorSwitcher = "C:\Users\pat\Documents\Setups\MonitorProfileSwitcher_v0700\MonitorSwitcher.exe"
$tvProfile = "C:\Users\pat\AppData\Roaming\MonitorSwitcher\Profiles\TV.xml"
$startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "PS5 Controller Monitor.lnk"

$state = [hashtable]::Synchronized(@{
    Connected = $false
    HasPreviousState = $false
    Monitoring = $true
    SwitchToTv = $true
})

function Test-ControllerConnected {
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

    $isConnected = Test-ControllerConnected
    if (-not $state.HasPreviousState -or $isConnected -ne $state.Connected) {
        $state.Connected = $isConnected
        $state.HasPreviousState = $true
        Set-TrayIcon $isConnected
        Write-ControllerState $isConnected
        if ($isConnected -and $state.SwitchToTv) {
            Switch-ToTvProfile
        }
        & $updateStatus
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