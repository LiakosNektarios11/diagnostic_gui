            # network.ps1 - Interactive Network Menu

            # --- Network Main Menu ---
            function Show-NetworkMenu {
                param([string]$BaseFolder)

                $ipExit = $false
                $logFolder = Join-Path $BaseFolder "network_logs"
                if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder | Out-Null }

                do {
                    Clear-Host
                    Write-Host "`n=== Network ===" -ForegroundColor Cyan
                    Write-Host "1 - Local IPs"
                    Write-Host "2 - Public IP"
                    Write-Host "3 - Ping Test"
                    Write-Host "4 - LAN Scan (10.130.10.1-255)"
                    Write-Host "5 - Advanced Network Info"
                    Write-Host "6 - Network Tools"
                    Write-Host "0 - Return to Main Menu"

                    $ipChoice = Read-Host "Enter choice (0-6)"

                    switch ($ipChoice) {
                        "0" { $ipExit = $true }

                        "1" {
                            Write-Host "`n--- Local IPs ---" -ForegroundColor Yellow
                            $ipData = Get-NetIPAddress | Select-Object IPAddress, InterfaceAlias
                            Write-Host ($ipData | Format-Table -AutoSize | Out-String)
                            if ($ipData) { Save-Log -Content $ipData -DefaultFolder $logFolder -DefaultName "local_ip" }
                        }

                        "2" {
                            Write-Host "`n--- Public IP ---" -ForegroundColor Yellow
                            try {
                                $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=json"
                                Write-Host "Your public IP is: $($publicIP.ip)" -ForegroundColor Green
                                Save-Log -Content ("Public IP: $($publicIP.ip)") -DefaultFolder $logFolder -DefaultName "public_ip"
                            } catch {
                                Write-Host "Error retrieving public IP" -ForegroundColor Red
                            }
                        }

                        "3" {
                            Write-Host "`n--- Ping Test ---" -ForegroundColor Yellow
                            $target = Read-Host "Enter host/IP to ping (e.g. 8.8.8.8)"
                            if ($target) {
                                $ping = Test-Connection -ComputerName $target -Count 4
                                Write-Host ($ping | Out-String)
                                if ($ping) { Save-Log -Content $ping -DefaultFolder $logFolder -DefaultName "ping_$target" }
                            }
                        }

                        "4" {
                            Write-Host "`n--- LAN Scan 10.130.10.1-255 ---" -ForegroundColor Yellow
                            Write-Host "Press 'E' to stop scanning." -ForegroundColor Red
                            $lanResults = @()
                            $stoppedByUser = $false

                            for ($i=1; $i -le 255; $i++) {
                                if ([console]::KeyAvailable) {
                                    $key = [console]::ReadKey($true)
                                    if ($key.Key -eq "E") { $stoppedByUser = $true; break }
                                }
                                $ip = "10.130.10.$i"
                                if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                                    Write-Host "Online: $ip" -ForegroundColor Green
                                    $lanResults += $ip
                                } else { Write-Host "Offline: $ip" -ForegroundColor DarkGray }
                            }

                            if ($stoppedByUser) { Write-Host "`nScan stopped by user." -ForegroundColor Red }
                            else { Write-Host "`nScan finished." -ForegroundColor Cyan }

                            if ($lanResults) { Save-Log -Content $lanResults -DefaultFolder $logFolder -DefaultName "lan_scan" }
                        }

                        "5" {
                        # --- 2.5 Advanced Network Info submenu ---
                        $advExit = $false
                        do {
                            Clear-Host
                            Write-Host "`n=== Advanced Network Info ===" -ForegroundColor Cyan
                            Write-Host "1 - Network Interfaces (IP, MAC, Gateway, DNS)"
                            Write-Host "2 - Traffic Stats (Packets/Bytes)"
                            Write-Host "3 - TCP & UDP Connections + Ping"
                            Write-Host "0 - Return to Network Menu"

                            $advChoice = Read-Host "Enter choice (0-3)"

                            switch ($advChoice) {
                                "0" { $advExit = $true }

                                "1" {
                                    Write-Host "`n--- Network Interfaces ---" -ForegroundColor Yellow
                                    $netIfaces = Get-NetAdapter | Select-Object Name, MacAddress, Status, LinkSpeed
                                    $netGateways = Get-NetRoute | Where-Object {$_.DestinationPrefix -eq "0.0.0.0/0"} | Select-Object InterfaceAlias, NextHop
                                    $netDNS = Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses
                                    Write-Host ($netIfaces | Format-Table -AutoSize | Out-String)
                                    Write-Host ($netGateways | Format-Table -AutoSize | Out-String)
                                    Write-Host ($netDNS | Format-Table -AutoSize | Out-String)
                                    Save-Log -Content @{Interfaces=$netIfaces; Gateways=$netGateways; DNS=$netDNS} -DefaultFolder $LogFolder -DefaultName "network_interfaces"
                                }

                                "2" {
                                    Write-Host "`n--- Traffic Statistics ---" -ForegroundColor Yellow
                                    $traffic = Get-NetAdapterStatistics | Select-Object Name, ReceivedBytes, SentBytes, ReceivedPackets, SentPackets
                                    $trafficKB = $traffic | ForEach-Object {
                                        [PSCustomObject]@{
                                            Name = $_.Name
                                            ReceivedKB = [math]::Round($_.ReceivedBytes / 1KB,2)
                                            SentKB     = [math]::Round($_.SentBytes / 1KB,2)
                                            ReceivedPackets = $_.ReceivedPackets
                                            SentPackets     = $_.SentPackets
                                        }
                                    }
                                    Write-Host ($trafficKB | Format-Table -AutoSize | Out-String)
                                    Save-Log -Content $trafficKB -DefaultFolder $LogFolder -DefaultName "network_traffic"
                                }

                                "3" {
                                    Write-Host "`n--- TCP & UDP Connections + Ping ---" -ForegroundColor Yellow
                                    $tcpConnections = (Get-NetTCPConnection).Count
                                    $udpConnections = (Get-NetUDPEndpoint).Count
                                    Write-Host "Active TCP Connections: $tcpConnections" -ForegroundColor Green
                                    Write-Host "Active UDP Connections: $udpConnections" -ForegroundColor Green

                                    $pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 4
                                    $avgLatency = [math]::Round(($pingResult | Measure-Object ResponseTime -Average).Average,2)
                                    Write-Host "Ping 8.8.8.8 Average Latency: $avgLatency ms" -ForegroundColor Cyan

                                    $netSummary = [PSCustomObject]@{
                                        TCPConnections = $tcpConnections
                                        UDPConnections = $udpConnections
                                        PingAverageMs  = $avgLatency
                                    }
                                    Save-Log -Content $netSummary -DefaultFolder $LogFolder -DefaultName "tcp_udp_ping"
                                }

                                default { Write-Host "Invalid choice." -ForegroundColor Red }
                            }

                            if (-not $advExit) { Write-Host "`nPress Enter to continue..."; Read-Host }

                        } while (-not $advExit)
                        }

                       "6" {
                            $toolsExit = $false
                            $logFolder = Join-Path $BaseFolder "network_logs"

                            do {
                                Clear-Host
                                Write-Host "`n=== Network Tools ===" -ForegroundColor Cyan
                                Write-Host "1 - List Wi-Fi Profiles"
                                Write-Host "2 - Traceroute to Host"
                                Write-Host "3 - Port Scan"
                                Write-Host "4 - Send File"
                                Write-Host "0 - Return to Network Menu"

                                $toolChoice = Read-Host "Enter choice (0-4)"
                                switch ($toolChoice) {
                                    "0" { $toolsExit = $true }

                                    "1" {
                                        Write-Host "`n--- Wi-Fi Profiles & Passwords ---" -ForegroundColor Yellow
                                        $wifiProfiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[1].Trim() }
                                        $wifiList = $wifiProfiles | ForEach-Object {
                                            $keyInfo = netsh wlan show profile name="$_" key=clear | Select-String "Key Content"
                                            [PSCustomObject]@{
                                                SSID     = $_
                                                Password = if ($keyInfo) { ($keyInfo -split ":")[1].Trim() } else { "<No Password>" }
                                            }
                                        }
                                        Write-Host ($wifiList | Format-Table -AutoSize | Out-String)
                                        Save-Log -Content $wifiList -DefaultFolder $logFolder -DefaultName "wifi_profiles_with_passwords"
                                    }

                                    "2" {
                                        Write-Host "`n--- Traceroute ---" -ForegroundColor Yellow
                                        $host1 = Read-Host "Enter host to traceroute (e.g. google.com)"
                                        if ($host1) {
                                            try {
                                                $traceroute = tracert.exe $host1 | ForEach-Object { $_.Trim() }
                                                if ($traceroute) {
                                                    $i = 1
                                                    foreach ($hop in $traceroute) { Write-Host "$i`t$hop"; $i++ }
                                                    Save-Log -Content $traceroute -DefaultFolder $logFolder -DefaultName "traceroute_$host1"
                                                } else {
                                                    Write-Host "Traceroute failed or returned no hops." -ForegroundColor Red
                                                }
                                            } catch { Write-Host "Error performing traceroute: $_" -ForegroundColor Red }
                                        } else { Write-Host "No host entered." -ForegroundColor Red }
                                    }

                                    "3" {
                                        Write-Host "`n--- Port Scan ---" -ForegroundColor Yellow
                                        $target = Read-Host "Enter target IP/host"
                                        $portsInput = Read-Host "Enter ports (comma or ranges, e.g. 80,443,1000-1010)"
                                        $portList = @()
                                        foreach ($p in $portsInput -split ",") {
                                            $p = $p.Trim()
                                            if ($p -match '^\d+$') { $portList += [int]$p }
                                            elseif ($p -match '^(\d+)-(\d+)$') { $portList += [int]$matches[1]..[int]$matches[2] }
                                        }

                                        $scanResults = @(); $allClosed = $true
                                        foreach ($port in $portList) {
                                            try {
                                                $res = Test-NetConnection -ComputerName $target -Port $port -WarningAction SilentlyContinue
                                                $status = if ($res.TcpTestSucceeded) { "Open" } else { "Closed" }
                                                if ($res.TcpTestSucceeded) { $allClosed = $false }
                                                $scanResults += [PSCustomObject]@{ Port = $port; Status = $status }
                                            } catch { $scanResults += [PSCustomObject]@{ Port = $port; Status = "Error" } }
                                        }

                                        if ($allClosed) { Write-Host "`nAll scanned ports are closed. Firewall or host unreachable?" -ForegroundColor Red }
                                        Write-Host "`nScan Results:"; $scanResults | Format-Table -AutoSize
                                        Save-Log -Content $scanResults -DefaultFolder $logFolder -DefaultName "port_scan_$target"
                                    }


                                    "4" {
                                        $sendExit = $false
                                        $logFolder = Join-Path $BaseFolder "network_logs"

                                        do {
                                            Clear-Host
                                            Write-Host "`n=== Send File ===" -ForegroundColor Cyan
                                            Write-Host "1 - Local Network (UNC / PowerShell Remoting)"
                                            Write-Host "2 - FTP/SFTP Upload"
                                            Write-Host "3 - HTTP/HTTPS Upload"
                                            Write-Host "4 - Email Attachment"
                                            Write-Host "0 - Return to Network Menu"

                                            $sendChoice = Read-Host "Enter choice (0-4)"
                                            switch ($sendChoice) {
                                                "0" { $sendExit = $true }

                                                # --- Local Network Copy ---
                                                "1" {
                                                    Write-Host "`n--- Local Network File Transfer ---" -ForegroundColor Yellow
                                                    $filePath = Read-Host "Enter full path of the file to send"
                                                    $destHost = Read-Host "Enter target computer name or IP"
                                                    $destPath = Read-Host "Enter destination folder path (UNC or remote)"
                                                    $username = Read-Host "Enter username (leave blank if not needed)"
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
                                                        Save-Log -Content "Sent $filePath to $fullDest at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "file_transfer_local"
                                                    } catch {
                                                        Write-Host "❌ Error sending file: $_" -ForegroundColor Red
                                                        Save-Log -Content "Failed to send $filePath to $fullDest : $_" -DefaultFolder $logFolder -DefaultName "file_transfer_local"
                                                    }
                                                }

                                                # --- FTP/SFTP Upload ---
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
                                                            Write-Host "🔍 Detecting SSH fingerprint automatically..."
                                                            $rawKey = ssh-keyscan -t rsa $host1 2>$null | Select-String "ssh-rsa"
                                                            if ($rawKey) {
                                                                $bytes = [System.Text.Encoding]::ASCII.GetBytes(($rawKey -split " ")[2])
                                                                $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
                                                                $fingerprint = "ssh-rsa 2048 " + ($hash | ForEach-Object { $_.ToString("x2") }) -join ":"
                                                                Write-Host "✅ Fingerprint detected: $fingerprint"
                                                            }
                                                        }
                                                    } catch {
                                                        Write-Host "⚠️ Automatic fingerprint detection failed, will ask manually." -ForegroundColor Yellow
                                                    }

                                                    if (-not $fingerprint) {
                                                        $fingerprint = Read-Host "Enter SSH Host Key Fingerprint (e.g., ssh-rsa 2048 xx:xx:xx...)"
                                                    }

                                                    $dllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
                                                    if (-Not (Test-Path $dllPath)) { 
                                                        Write-Host "WinSCP .NET assembly not found at $dllPath" -ForegroundColor Red
                                                        break
                                                    }
                                                    Add-Type -Path $dllPath

                                                    try {
                                                        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                                                            Protocol = [WinSCP.Protocol]::Sftp
                                                            HostName = $host1
                                                            UserName = $username
                                                            Password = $password
                                                            SshHostKeyFingerprint = $fingerprint
                                                        }
                                                        $session = New-Object WinSCP.Session
                                                        $session.Open($sessionOptions)
                                                        $transferResult = $session.PutFiles($localFile, $remotePath)
                                                        $transferResult.Check()

                                                        Write-Host "✅ File uploaded successfully!" -ForegroundColor Green
                                                        Save-Log -Content "Uploaded $localFile to $($host1):$remotePath at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "sftp_upload"
                                                    } catch {
                                                        Write-Host "❌ Error uploading file: $_" -ForegroundColor Red
                                                        Save-Log -Content "Failed upload of $localFile to $($host1):$remotePath : $_" -DefaultFolder $logFolder -DefaultName "sftp_upload"
                                                    } finally {
                                                        if ($session) { $session.Dispose() }
                                                    }
                                                }

                                                # --- HTTP/HTTPS Upload ---
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
                                                        Write-Host "✅ File uploaded successfully!" -ForegroundColor Green
                                                        Save-Log -Content "Uploaded $filePath to $url at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "http_upload"
                                                    } catch {
                                                        Write-Host "❌ Error uploading file: $_" -ForegroundColor Red
                                                        Save-Log -Content "Failed upload of $filePath to $url : $_" -DefaultFolder $logFolder -DefaultName "http_upload"
                                                    }
                                                }

                                                # --- Email Attachment ---
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
                                                            Send-MailMessage -SmtpServer $smtpServer -Port $port -From $from -To $to `
                                                                -Subject $subject -Body $body -Attachments $filePath -Credential $cred -UseSsl
                                                        } else {
                                                            Send-MailMessage -SmtpServer $smtpServer -Port $port -From $from -To $to `
                                                                -Subject $subject -Body $body -Attachments $filePath -Credential $cred
                                                        }

                                                        Write-Host "✅ Email sent successfully!" -ForegroundColor Green
                                                        Save-Log -Content "Sent $filePath via email to $to at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "email_attachment"
                                                    } catch {
                                                        Write-Host "❌ Error sending email: $_" -ForegroundColor Red
                                                        Save-Log -Content "Failed email of $filePath to $($to) : $_" -DefaultFolder $logFolder -DefaultName "email_attachment"
                                                    }
                                                }

                                                default { Write-Host "Invalid choice." -ForegroundColor Red }
                                            }

                                            if (-not $sendExit) { Read-Host "`nPress Enter to continue..." }

                                        } while (-not $sendExit)
                                    }







                                        default { Write-Host "Invalid choice." -ForegroundColor Red }
                                    }

                                    if (-not $toolsExit) { Read-Host "`nPress Enter to continue..." }

                                } while (-not $toolsExit)
                            }


                        default { Write-Host "Invalid choice." -ForegroundColor Red }
                    }

                    if (-not $ipExit) {
                        Write-Host "`nPress Enter to continue..."
                        Read-Host
                    }

                } while (-not $ipExit)
            }
