# users.ps1 - User Accounts & Sessions submenu
param([string]$BaseFolder)

function Show-UsersMenu {
    param([string]$BaseFolder)
    $userExit = $false
    $logFolder = Join-Path $BaseFolder "user_logs"
    if (-not ([bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator"))) {
        Write-Host "You must run this script as Administrator!" -ForegroundColor Red
    }
    do {
        Clear-Host
        Write-Host "`n=== User Accounts & Sessions ===" -ForegroundColor Cyan
        Write-Host "1 - List All User Accounts"
        Write-Host "2 - List Currently Logged-On Users"
        Write-Host "3 - Disable / Enable User Account"
        Write-Host "4 - Force Logoff User Session"
        Write-Host "0 - Return to Main Menu"

        $userChoice = Read-Host "Enter choice (0-4)"
        switch ($userChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- All User Accounts ---" -ForegroundColor Yellow
                $allUsers = Get-LocalUser | Select-Object Name, Enabled, Description
                Write-Host ($allUsers | Format-Table -AutoSize | Out-String)
                Save-Log -Content $allUsers -DefaultFolder $logFolder -DefaultName "all_users"
            }
            "2" {
                Write-Host "`n--- Currently Logged-On Users ---" -ForegroundColor Yellow
                $loggedUsers = quser 2>&1 | ForEach-Object { $_ }
                Write-Host ($loggedUsers | Out-String)
                Save-Log -Content $loggedUsers -DefaultFolder $logFolder -DefaultName "logged_on_users"
            }
            "3" {
                Write-Host "`n--- Enable/Disable User Account ---" -ForegroundColor Yellow
                $username = Read-Host "Enter username"
                $action = Read-Host "Enter action (enable/disable)"
                try {
                    if ($action -eq "disable") {
                        Disable-LocalUser -Name $username
                        Write-Host "User $username disabled." -ForegroundColor Green
                        Save-Log -Content "User $username disabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "user_modify"
                    } elseif ($action -eq "enable") {
                        Enable-LocalUser -Name $username
                        Write-Host "User $username enabled." -ForegroundColor Green
                        Save-Log -Content "User $username enabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "user_modify"
                    } else {
                        Write-Host "Invalid action." -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Error modifying user: $_" -ForegroundColor Red
                }
            }
            "4" {
                Write-Host "`n--- Force Logoff User Session ---" -ForegroundColor Yellow
                $sessionId = Read-Host "Enter session ID to log off"
                try {
                    logoff $sessionId
                    Write-Host "Session $sessionId logged off." -ForegroundColor Green
                    Save-Log -Content "Session $sessionId logged off at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "user_logoff"
                } catch {
                    Write-Host "Error logging off session: $_" -ForegroundColor Red
                }
            }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
