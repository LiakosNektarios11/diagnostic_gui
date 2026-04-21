# services.ps1 - Services submenu
param([string]$BaseFolder)

function Show-ServicesMenu {
    param([string]$BaseFolder)
    $servicesExit = $false
    do {
        Clear-Host
        Write-Host "`n=== Services ===" -ForegroundColor Magenta
        Write-Host "1 - List Services"
        Write-Host "2 - Manage Services (services.msc)"
        Write-Host "3 - Start-Stop-Restart Service"
        Write-Host "0 - Return to Main Menu"

        $svcChoice = Read-Host "Enter choice (0-3)"
        $logFolder = Join-Path $BaseFolder "service_logs"

        switch ($svcChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- Services List ---" -ForegroundColor Yellow
                $serviceData = Get-Service | Select-Object Name, Status
                Write-Host ($serviceData | Format-Table -AutoSize | Out-String)
                Save-Log -Content $serviceData -DefaultFolder $logFolder -DefaultName "service_list"
            }
            "2" {
                Write-Host "`n--- Services Management ---" -ForegroundColor Yellow
                Start-Process "services.msc"
                Save-Log -Content ("Services opened at $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')") -DefaultFolder $logFolder -DefaultName "services_open"
            }
            "3" {
                if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
                    Write-Host "You must run this script as Administrator to manage services!" -ForegroundColor Red
                    continue
                }
                Write-Host "`n--- Manage Service ---" -ForegroundColor Yellow
                $svcName = Read-Host "Enter service name"
                Write-Host "1 - Start"
                Write-Host "2 - Stop"
                Write-Host "3 - Restart"
                $action = Read-Host "Select action (1-3)"
                try {
                    switch ($action) {
                        "1" {
                            Start-Service -Name $svcName -ErrorAction Stop
                            Write-Host "Service $svcName started." -ForegroundColor Green
                            Save-Log -Content "Service $svcName started at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "service_control"
                        }
                        "2" {
                            Stop-Service -Name $svcName -ErrorAction Stop
                            Write-Host "Service $svcName stopped." -ForegroundColor Green
                            Save-Log -Content "Service $svcName stopped at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "service_control"
                        }
                        "3" {
                            Restart-Service -Name $svcName -ErrorAction Stop
                            Write-Host "Service $svcName restarted." -ForegroundColor Green
                            Save-Log -Content "Service $svcName restarted at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "service_control"
                        }
                        default { Write-Host "Invalid action." -ForegroundColor Red }
                    }
                } catch {
                    Write-Host "Error managing service $svcName $_" -ForegroundColor Red
                }
            }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
