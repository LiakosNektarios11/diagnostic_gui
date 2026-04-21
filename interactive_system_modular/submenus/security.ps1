# security.ps1 - Security & Firewall submenu
param([string]$BaseFolder)

function Show-SecurityMenu {
    param([string]$BaseFolder)
    $secExit = $false
    $logFolder = Join-Path $BaseFolder "security_logs"
    do {
        Clear-Host
        Write-Host "`n=== Security & Firewall ===" -ForegroundColor Cyan
        Write-Host "1 - Windows Firewall Status"
        Write-Host "2 - Active Ports"
        Write-Host "3 - Antivirus / Windows Defender Status"
        Write-Host "0 - Return to Main Menu"

        $secChoice = Read-Host "Enter choice (0-3)"

        switch ($secChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- Windows Firewall Status ---" -ForegroundColor Yellow
                try {
                    $fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
                    Write-Host ($fwProfiles | Format-Table -AutoSize | Out-String)
                    Save-Log -Content $fwProfiles -DefaultFolder $logFolder -DefaultName "firewall_status"
                } catch {
                    Write-Host "Unable to retrieve Firewall status." -ForegroundColor Red
                }
            }
            "2" {
                Write-Host "`n--- Active Ports ---" -ForegroundColor Yellow
                try {
                    $netstat = netstat -ano | Select-String "LISTENING"
                    Write-Host ($netstat | Out-String)
                    Save-Log -Content $netstat -DefaultFolder $logFolder -DefaultName "active_ports"
                } catch {
                    Write-Host "Unable to retrieve active ports." -ForegroundColor Red
                }
            }
            "3" {
                Write-Host "`n--- Antivirus / Windows Defender Status ---" -ForegroundColor Yellow
                try {
                    $defender = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" | Select-Object displayName, productState, pathToSignedProductExe
                    Write-Host ($defender | Format-Table -AutoSize | Out-String)
                    Save-Log -Content $defender -DefaultFolder $logFolder -DefaultName "antivirus_status"
                } catch {
                    Write-Host "Unable to retrieve Antivirus status." -ForegroundColor Red
                }
            }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
