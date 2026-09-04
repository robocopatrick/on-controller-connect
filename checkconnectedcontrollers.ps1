$bat = Join-Path $PSScriptRoot "controllerconnected.bat"

$wasConnected = $false
$hasPreviousState = $false

while ($true) {

    $controller = @(Get-PnpDevice -Class HIDClass | Where-Object {
        $_.HardwareID -match "HID_DEVICE_SYSTEM_GAME"
    })

    $connectedDevices = @($controller | Where-Object { $_.Status -match "^OK$" })
    $isConnected = [bool]$connectedDevices

    if (-not $hasPreviousState -or $isConnected -ne $wasConnected) {
        $state = if ($isConnected) { "Connected" } else { "Disconnected" }
        Write-Host "PS5 controller $state"
        Start-Process -FilePath $env:ComSpec -ArgumentList @(
            "/d",
            "/c",
            "`"$bat`" $state"
        ) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -Wait
    }

    $wasConnected = $isConnected
    $hasPreviousState = $true

    Start-Sleep -Seconds 1
}