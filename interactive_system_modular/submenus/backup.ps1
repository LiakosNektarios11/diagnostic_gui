# backup.ps1 - Backup & Restore submenu
param([string]$BaseFolder)

function Show-BackupMenu {
    param([string]$BaseFolder)
    $backupExit = $false
    $logFolder = Join-Path $BaseFolder "backup_logs"
    if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder | Out-Null }

    do {
        Clear-Host
        Write-Host "`n=== Backup & Restore ===" -ForegroundColor Cyan
        Write-Host "1 - Backup folder to ZIP"
        Write-Host "2 - Restore ZIP to folder"
        Write-Host "3 - Backup folder and Upload (FTP/SFTP) - quick mode"
        Write-Host "0 - Return to Main Menu"

        $backupChoice = Read-Host "Enter choice (0-3)"
        switch ($backupChoice) {
            "0" { return }
            "1" {
                $src = Read-Host "Enter folder path to backup"
                $dest = Read-Host "Enter ZIP file name (with full path)"
                try {
                    Compress-Archive -Path $src -DestinationPath $dest -Force
                    Write-Host "Backup created: $dest" -ForegroundColor Green
                    Save-Log -Content "Backup created: $dest from $src" -DefaultFolder $logFolder -DefaultName "backup"
                } catch {
                    Write-Host "Error creating backup: $_" -ForegroundColor Red
                    Save-Log -Content "Backup failed: $_" -DefaultFolder $logFolder -DefaultName "backup_error"
                }
            }
            "2" {
                $zip = Read-Host "Enter ZIP file path"
                $dest = Read-Host "Enter destination folder"
                try {
                    Expand-Archive -Path $zip -DestinationPath $dest -Force
                    Write-Host "Restored to: $dest" -ForegroundColor Green
                    Save-Log -Content "Restore: $zip -> $dest" -DefaultFolder $logFolder -DefaultName "restore"
                } catch {
                    Write-Host "Error restoring: $_" -ForegroundColor Red
                    Save-Log -Content "Restore failed: $_" -DefaultFolder $logFolder -DefaultName "restore_error"
                }
            }
            "3" {
                Write-Host "`n--- Backup & Upload (quick) ---" -ForegroundColor Yellow
                $src = Read-Host "Enter folder path to backup"
                $tmpZip = Join-Path $env:TEMP ("backup_$([System.IO.Path]::GetRandomFileName()).zip")
                try {
                    Compress-Archive -Path $src -DestinationPath $tmpZip -Force
                    Write-Host "ZIP created: $tmpZip"
                    # Reuse sendfile menu logic? For now ask for FTP/SFTP host and use WinSCP if available
                    $host1 = Read-Host "Enter FTP/SFTP host (or leave blank to skip upload)"
                    if ($host1) {
                        $user = Read-Host "Enter username"
                        $pass = Read-Host "Enter password"
                        $remotePath = Read-Host "Enter remote path (e.g. /backups/)"
                        # Simple reuse of WinSCP approach if available
                        $dllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
                        if (-Not (Test-Path $dllPath)) { Write-Host "WinSCP .NET assembly not found at $dllPath" -ForegroundColor Red }
                        else {
                            Add-Type -Path $dllPath
                            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                                Protocol = [WinSCP.Protocol]::Sftp
                                HostName = $host1
                                UserName = $user
                                Password = $pass
                            }
                            $session = New-Object WinSCP.Session
                            try {
                                $session.Open($sessionOptions)
                                $transferResult = $session.PutFiles($tmpZip, $remotePath)
                                $transferResult.Check()
                                Write-Host "Backup uploaded to ${host1:$remotePath}" -ForegroundColor Green
                                Save-Log -Content "Backup uploaded to ${host:$remotePath}" -DefaultFolder $logFolder -DefaultName "backup_upload"
                            } catch {
                                Write-Host " Upload failed: $_" -ForegroundColor Red
                                Save-Log -Content "Upload failed: $_" -DefaultFolder $logFolder -DefaultName "backup_upload_error"
                            } finally { if ($session) { $session.Dispose() } }
                        }
                    }
                } catch {
                    Write-Host "Error during backup/upload: $_" -ForegroundColor Red
                    Save-Log -Content "Backup/upload error: $_" -DefaultFolder $logFolder -DefaultName "backup_error"
                } finally {
                    if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue }
                }
            }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }

        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
