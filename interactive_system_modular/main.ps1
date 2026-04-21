# main.ps1 - Modular Interactive System (entry point)
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition



# Base folder for logs etc.
$baseFolder = Join-Path $env:USERPROFILE "powershell"
if (-not (Test-Path $baseFolder)) { New-Item -ItemType Directory -Path $baseFolder | Out-Null }

# import helpers and submenu modules
. "$PSScriptRoot\helpers\logging.ps1"
. "$PSScriptRoot\submenus\network.ps1"
. "$PSScriptRoot\submenus\services.ps1"
. "$PSScriptRoot\submenus\disk.ps1"
. "$PSScriptRoot\submenus\security.ps1"
. "$PSScriptRoot\submenus\users.ps1"
. "$PSScriptRoot\submenus\control_panel.ps1"
. "$PSScriptRoot\submenus\devices.ps1"
. "$PSScriptRoot\submenus\sendfile.ps1"
. "$PSScriptRoot\submenus\backup.ps1"

function Show-MainMenu {
    param([string]$BaseFolder)

if (-not $BaseFolder -or $BaseFolder -eq "") {
    $BaseFolder = Join-Path $env:USERPROFILE "powershell"
    if (-not (Test-Path $BaseFolder)) {
        New-Item -ItemType Directory -Path $BaseFolder | Out-Null
    }
}

    do {
        Clear-Host
        Write-Host "=== Interactive System (Modular) ===" -ForegroundColor Cyan
        Write-Host "1 - Task Manager"
        Write-Host "2 - Network"
        Write-Host "3 - Services"
        Write-Host "4 - Disk Usage & System Health"
        Write-Host "5 - Security & Firewall"
        Write-Host "6 - Accounts"
        Write-Host "7 - Control Panel / System Utilities"
        Write-Host "8 - Device Management / Peripherals"
        Write-Host "9 - Send File (Transfers)"
        Write-Host "10 - Backup & Restore"
        Write-Host "0 - Exit"

        $choice = Read-Host "Enter your choice (0-10)"
        switch ($choice) {
            "0" { return }
            "1" { Start-Process "taskmgr.exe" }
            "2" { Show-NetworkMenu -BaseFolder $BaseFolder }
            "3" { Show-ServicesMenu -BaseFolder $BaseFolder }
            "4" { Show-DiskMenu -BaseFolder $BaseFolder }
            "5" { Show-SecurityMenu -BaseFolder $BaseFolder }
            "6" { Show-UsersMenu -BaseFolder $BaseFolder }
            "7" { Show-ControlPanelMenu -BaseFolder $BaseFolder }
            "8" { Show-DevicesMenu -BaseFolder $BaseFolder }
            "9" { Show-SendFileMenu -BaseFolder $BaseFolder }
            "10" { Show-BackupMenu -BaseFolder $BaseFolder }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to return to menu..."
        Read-Host
    } while ($true)
}

# run
Show-MainMenu -BaseFolder $baseFolder
Write-Host "`nExiting script. Thank you!" -ForegroundColor Cyan
