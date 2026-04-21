# control_panel.ps1 - Control Panel / System Utilities submenu
param([string]$BaseFolder)

function Show-ControlPanelMenu {
    param([string]$BaseFolder)
    $cpExit = $false
    $logFolder = Join-Path $BaseFolder "control_panel_logs"
    do {
        Clear-Host
        Write-Host "`n=== Control Panel / System Utilities ===" -ForegroundColor Cyan
        Write-Host "1 - View Installed Software"
        Write-Host "2 - Windows Updates Status & History"
        Write-Host "3 - System Restore Points"
        Write-Host "4 - Enable / Disable Windows Firewall"
        Write-Host "5 - Quick Antivirus / Windows Defender Scan"
        Write-Host "0 - Return to Main Menu"

        $cpChoice = Read-Host "Enter choice (0-5)"
        switch ($cpChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- Installed Software ---" -ForegroundColor Yellow
                $software = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
                            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
                Write-Host ($software | Format-Table -AutoSize | Out-String)
                Save-Log -Content $software -DefaultFolder $logFolder -DefaultName "installed_software"
            }
           "2" {
                Write-Host "`n--- Windows Updates ---" -ForegroundColor Yellow
                try {
                    # Ορίζουμε path στο logFolder αντί για Desktop
                    $updateLogPath = Join-Path $logFolder "WindowsUpdate.log"
                    Get-WindowsUpdateLog -LogPath $updateLogPath
                    Write-Host "Windows Update log saved to $updateLogPath"
                } catch {
                    Write-Host "Unable to retrieve updates." -ForegroundColor Red
                }
            }

            "3" {
                Write-Host "`n--- System Restore Points ---" -ForegroundColor Yellow
                # Έλεγχος για admin rights
                $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

                if (-not $isAdmin) {
                    Write-Host " Access denied. Please run PowerShell as Administrator to view restore points." -ForegroundColor Red
                } else {
                    try {
                        $restorePoints = Get-ComputerRestorePoint | Select-Object SequenceNumber, Description, CreationTime
                        Write-Host ($restorePoints | Format-Table -AutoSize | Out-String)
                        Save-Log -Content $restorePoints -DefaultFolder $logFolder -DefaultName "restore_points"
                    } catch {
                        Write-Host "Unable to retrieve restore points." -ForegroundColor Red
                    }
                }
            }

            "4" {
                Write-Host "`n--- Windows Firewall ---" -ForegroundColor Yellow
                try {
                    $fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
                    Write-Host ($fwProfiles | Format-Table -AutoSize | Out-String)
                    $fwAction = Read-Host "Enter profile name to toggle or 'none' to skip"
                    if ($fwAction -ne "none") {
                        $current = (Get-NetFirewallProfile -Name $fwAction).Enabled
                        if ($current) {
                            Set-NetFirewallProfile -Name $fwAction -Enabled False
                            Write-Host "$fwAction firewall disabled." -ForegroundColor Green
                        } else {
                            Set-NetFirewallProfile -Name $fwAction -Enabled True
                            Write-Host "$fwAction firewall enabled." -ForegroundColor Green
                        }
                        Save-Log -Content "Firewall $fwAction toggled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "firewall_toggle"
                    }
                } catch {
                    Write-Host "Error managing firewall: $_" -ForegroundColor Red
                }
            }
            "5" {
                Write-Host "`n--- Quick Antivirus Scan ---" -ForegroundColor Yellow
                $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

                if (-not $isAdmin) {
                    Write-Host "Please run PowerShell as Administrator to perform antivirus scan." -ForegroundColor Red
                } else {
                    try {
                        $defender = Get-Service WinDefend
                        if ($defender.Status -ne "Running") {
                            Write-Host "Windows Defender service is not running. Attempting to start..." -ForegroundColor Yellow
                            Start-Service WinDefend
                        }

                        Start-MpScan -ScanType QuickScan
                        Write-Host "Quick scan initiated." -ForegroundColor Green
                        Save-Log -Content "Quick antivirus scan started at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "antivirus_scan"
                    } catch {
                        Write-Host "Error starting antivirus scan: $_" -ForegroundColor Red
                    }
                }
            }

            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
