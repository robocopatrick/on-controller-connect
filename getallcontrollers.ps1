Get-PnPDevice -Class HIDClass |
ForEach {
    $PSItem |
    Where-Object {$_.HardwareID -match 'HID_DEVICE_SYSTEM_GAME'} |
    Select-Object -Property FriendlyName, DeviceID, Status, HardwareID, Name, Class
}