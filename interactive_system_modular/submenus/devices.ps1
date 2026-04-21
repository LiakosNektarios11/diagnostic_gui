# devices.ps1 - Device Management / Peripherals submenu
param([string]$BaseFolder)

function Show-DevicesMenu {
    param([string]$BaseFolder)
    $deviceExit = $false
    $logFolder = Join-Path $BaseFolder "device_logs"
    do {
        Clear-Host
        Write-Host "`n=== Device Management / Peripherals ===" -ForegroundColor Cyan
        Write-Host "1 - List All Devices (PnP)"
        Write-Host "2 - List COM Ports"
        Write-Host "3 - List USB Devices"
        Write-Host "4 - List Printers"
        Write-Host "5 - Enable / Disable Device"
        Write-Host "6 - Eject / Safely Remove USB Device"
        Write-Host "7 - Device Properties"
        Write-Host "0 - Return to Main Menu"

        $devChoice = Read-Host "Enter choice (0-7)"
        switch ($devChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- All Devices ---" -ForegroundColor Yellow
                $allDevices = Get-PnpDevice | Select-Object Status, Class, FriendlyName, InstanceId
                Write-Host ($allDevices | Format-Table -AutoSize | Out-String)
                Save-Log -Content $allDevices -DefaultFolder $logFolder -DefaultName "all_devices"
            }
           "2" {
                Write-Host "`n--- COM Ports ---" -ForegroundColor Yellow
                $comPorts = Get-WmiObject Win32_SerialPort | Select-Object DeviceID, Name, Description

                if ($comPorts) {
                    Write-Host ($comPorts | Format-Table -AutoSize | Out-String)
                    Save-Log -Content $comPorts -DefaultFolder $logFolder -DefaultName "com_ports"
                } else {
                    Write-Host "No COM ports found." -ForegroundColor Yellow
                    Save-Log -Content "No COM ports found." -DefaultFolder $logFolder -DefaultName "com_ports"
                }
            }

            "3" {
                Write-Host "`n--- USB Devices ---" -ForegroundColor Yellow
                $usbDevices = Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq "USB" } | Select-Object Status, FriendlyName, InstanceId
                Write-Host ($usbDevices | Format-Table -AutoSize | Out-String)
                Save-Log -Content $usbDevices -DefaultFolder $logFolder -DefaultName "usb_devices"
            }
            "4" {
                Write-Host "`n--- Printers ---" -ForegroundColor Yellow
                $printers = Get-Printer | Select-Object Name, PrinterStatus, Default
                Write-Host ($printers | Format-Table -AutoSize | Out-String)
                Save-Log -Content $printers -DefaultFolder $logFolder -DefaultName "printers"
            }
            "5" {
                Write-Host "`n--- Enable / Disable Device ---" -ForegroundColor Yellow
                $deviceId = Read-Host "Enter Device Instance ID (from List All Devices)"
                $action = Read-Host "Enter action (enable/disable)"
                try {
                    if ($action -eq "enable") {
                        Enable-PnpDevice -InstanceId $deviceId -Confirm:$false
                        Write-Host "Device enabled." -ForegroundColor Green
                        Save-Log -Content "Device $deviceId enabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                    } elseif ($action -eq "disable") {
                        Disable-PnpDevice -InstanceId $deviceId -Confirm:$false
                        Write-Host "Device disabled." -ForegroundColor Green
                        Save-Log -Content "Device $deviceId disabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                    } else {
                        Write-Host "Invalid action." -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Error managing device: $_" -ForegroundColor Red
                }
            }
            "6" {
                Write-Host "`n--- Eject / Safely Remove USB Device ---" -ForegroundColor Yellow
                $usbDrives = Get-Disk | Where-Object { $_.BusType -eq 'USB' -and $_.IsOffline -eq $false } | Select-Object Number, FriendlyName, SerialNumber, Size
                if ($usbDrives.Count -eq 0) {
                    Write-Host "No USB drives detected." -ForegroundColor Red
                } else {
                    Write-Host "Connected USB drives:" -ForegroundColor Cyan
                    $i = 1
                    $usbDrives | ForEach-Object { Write-Host "$i - $_.FriendlyName (Size: $([math]::Round($_.Size/1GB,2)) GB, Serial: $_.SerialNumber)"; $i++ }
                    $selection = Read-Host "Select USB to eject (number)"
                    if ($selection -match '^\d+$' -and $selection -le $usbDrives.Count -and $selection -gt 0) {
                        $diskToEject = $usbDrives[$selection - 1]
                        try {
                            Set-Disk -Number $diskToEject.Number -IsOffline $true -ErrorAction Stop
                            Write-Host "USB drive '$($diskToEject.FriendlyName)' safely ejected." -ForegroundColor Green
                            Save-Log -Content "USB drive '$($diskToEject.FriendlyName)' ejected at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "usb_eject"
                        } catch {
                            Write-Host "Error ejecting USB drive: $_" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "Invalid selection." -ForegroundColor Red
                    }
                }
            }
            "7" {
                Write-Host "`n--- Device Properties ---" -ForegroundColor Yellow
                $deviceId = Read-Host "Enter Device Instance ID"

                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    Write-Host "No Device Instance ID entered. Skipping." -ForegroundColor Red
                } else {
                    try {
                        $devProps = Get-PnpDeviceProperty -InstanceId $deviceId
                        Write-Host ($devProps | Format-Table -AutoSize | Out-String)
                        Save-Log -Content $devProps -DefaultFolder $logFolder -DefaultName "device_properties_$deviceId"
                    } catch {
                        Write-Host "Error retrieving properties: $_" -ForegroundColor Red
                    }
                }
            }

            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
