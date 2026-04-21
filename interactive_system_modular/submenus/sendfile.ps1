# sendfile.ps1 - Send File submenu (modular)
param([string]$BaseFolder)

function Show-SendFileMenu {
    param([string]$BaseFolder)
    $sendExit = $false
    do {
        Clear-Host
        Write-Host "`n=== Send File ===" -ForegroundColor Cyan
        Write-Host "1 - Local Network (UNC / PowerShell Remoting)"
        Write-Host "2 - FTP/SFTP Upload"
        Write-Host "3 - HTTP/HTTPS Upload"
        Write-Host "4 - Email Attachment"
        Write-Host "0 - Return to Main Menu"

        $sendChoice = Read-Host "Enter choice (0-4)"
        $logFolder = Join-Path $BaseFolder "network_logs"

        switch ($sendChoice) {
            "0" { return }
            "1" {
                Write-Host "`n--- Local Network File Transfer ---" -ForegroundColor Yellow
                $filePath = Read-Host "Enter full path of the file to send"
                $destHost = Read-Host "Enter target computer name or IP"
                $destPath = Read-Host "Enter destination folder path (UNC path or local path on remote)"
                $username = Read-Host "Enter username (e.g. $destHost\user or DOMAIN\user, leave blank if not needed)"
                $passwordInput = Read-Host "Enter password (leave blank if not needed)"
                try {
                    if ($destPath -match "^[a-zA-Z]:\\") {
                        $drive = $destPath.Substring(0,1)
                        $rest  = $destPath.Substring(2).TrimStart("\")
                        $destPath = "$drive`$$rest"
                    }
                    $fullDest = "\\$destHost\$destPath"
                    if ($username -and $passwordInput) {
                        $securePassword = ConvertTo-SecureString $passwordInput -AsPlainText -Force
                        $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
                        $driveName = "Z"
                        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $fullDest -Credential $cred -ErrorAction Stop | Out-Null
                        Copy-Item -Path $filePath -Destination "${driveName}:\" -Force -ErrorAction Stop
                        Remove-PSDrive -Name $driveName
                    } else {
                        Copy-Item -Path $filePath -Destination $fullDest -Force -ErrorAction Stop
                    }
                    Write-Host "✅ File sent successfully!" -ForegroundColor Green
                    Save-Log -Content "Sent file $filePath to $fullDest at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "file_transfer_local"
                } catch {
                    Write-Host "Error sending file: $_" -ForegroundColor Red
                    Save-Log -Content "Failed to send $filePath to $fullDest : $_" -DefaultFolder $logFolder -DefaultName "file_transfer_local"
                }
            }
            "2" {
                Write-Host "`n--- FTP/SFTP Upload ---" -ForegroundColor Yellow
                $host1 = Read-Host "Enter FTP/SFTP host (IP or hostname)"
                $username = Read-Host "Enter username"
                $password = Read-Host "Enter password"
                $localFile = Read-Host "Enter full path of the file to upload"
                $remotePath = Read-Host "Enter remote path (e.g., /home/user/)"
                $fingerprint = $null
                try {
                    if (Get-Command ssh-keyscan -ErrorAction SilentlyContinue) {
                        $rawKey = ssh-keyscan -t rsa $host1 2>$null | Select-String "ssh-rsa"
                        if ($rawKey) {
                            $bytes = [System.Text.Encoding]::ASCII.GetBytes(($rawKey -split " ")[2])
                            $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
                            $fingerprint = "ssh-rsa 2048 " + ($hash | ForEach-Object { $_.ToString("x2") }) -join ":"
                            Write-Host "Detected fingerprint: $fingerprint"
                        }
                    }
                } catch { }
                if (-not $fingerprint) { $fingerprint = Read-Host "Enter SSH Host Key Fingerprint (or leave blank to skip)" }
                $dllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
                if (-Not (Test-Path $dllPath)) { Write-Host "WinSCP .NET assembly not found at $dllPath" -ForegroundColor Red; return }
                Add-Type -Path $dllPath
                try {
                    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{ Protocol = [WinSCP.Protocol]::Sftp; HostName = $host1; UserName = $username; Password = $password; SshHostKeyFingerprint = $fingerprint }
                    $session = New-Object WinSCP.Session
                    $session.Open($sessionOptions)
                    $transferResult = $session.PutFiles($localFile, $remotePath)
                    $transferResult.Check()
                    Write-Host "✅ File uploaded successfully!" -ForegroundColor Green
                    Save-Log -Content "Uploaded $localFile to $($host1):$remotePath at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "sftp_upload"
                } catch {
                    Write-Host " Error uploading file: $_" -ForegroundColor Red
                    Save-Log -Content "Failed upload of $localFile to $($host1):$remotePath : $_" -DefaultFolder $logFolder -DefaultName "sftp_upload"
                } finally { if ($session) { $session.Dispose() } }
            }
            "3" {
                Write-Host "`n--- HTTP/HTTPS Upload ---" -ForegroundColor Yellow
                $url = Read-Host "Enter URL to upload the file to"
                $filePath = Read-Host "Enter full path of the file to upload"
                try {
                    if ($PSVersionTable.PSVersion.Major -ge 7) {
                        $form = @{ file = Get-Item $filePath }
                        Invoke-RestMethod -Uri $url -Method Post -Form $form
                    } else {
                        Invoke-WebRequest -Uri $url -Method Post -InFile $filePath -UseBasicParsing
                    }
                    Write-Host " File uploaded successfully!" -ForegroundColor Green
                    Save-Log -Content "Uploaded $filePath to $url at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "http_upload"
                } catch {
                    Write-Host "Error uploading file: $_" -ForegroundColor Red
                    Save-Log -Content "Failed upload of $filePath to $url : $_" -DefaultFolder $logFolder -DefaultName "http_upload"
                }
            }
            "4" {
                Write-Host "`n--- Email Attachment ---" -ForegroundColor Yellow
                $smtpServer = Read-Host "Enter SMTP server"
                $port = Read-Host "Enter SMTP port (e.g., 587)"
                $from = Read-Host "Enter sender email"
                $to = Read-Host "Enter recipient email"
                $subject = Read-Host "Enter email subject"
                $body = Read-Host "Enter email body"
                $filePath = Read-Host "Enter full path of the file to attach"
                $useSsl = (Read-Host "Use SSL? (y/n)") -eq "y"
                $username = Read-Host "SMTP username"
                $password = Read-Host "SMTP password"
                try {
                    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                    $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
                    if ($useSsl) {
                        Send-MailMessage -SmtpServer $smtpServer -Port $port -From $from -To $to -Subject $subject -Body $body -Attachments $filePath -Credential $cred -UseSsl
                    } else {
                        Send-MailMessage -SmtpServer $smtpServer -Port $port -From $from -To $to -Subject $subject -Body $body -Attachments $filePath -Credential $cred
                    }
                    Write-Host " Email sent successfully!" -ForegroundColor Green
                    Save-Log -Content "Sent $filePath via email to $($to) at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "email_attachment"
                } catch {
                    Write-Host " Error sending email: $_" -ForegroundColor Red
                    Save-Log -Content "Failed email of $filePath to $($to) : $_" -DefaultFolder $logFolder -DefaultName "email_attachment"
                }
            }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }
        Write-Host "`nPress Enter to continue..."; Read-Host
    } while ($true)
}
