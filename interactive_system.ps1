# interactive_system.ps1
#$baseFolder = "C:\Users\logs"
# Create base folder if it doesn't exist
#if (-not (Test-Path $baseFolder)) { New-Item -ItemType Directory -Path $baseFolder }
$exit = $false
## --- Function to save log with file type selection ---
#$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Base folder for logs etc.
$baseFolder = Join-Path $env:USERPROFILE "powershell"
if (-not (Test-Path $baseFolder)) { New-Item -ItemType Directory -Path $baseFolder | Out-Null }
function Save-Log {
    param(
        [Parameter(Mandatory=$true)][Object]$Content,
        [Parameter(Mandatory=$true)][string]$DefaultFolder,
        [Parameter(Mandatory=$true)][string]$DefaultName
    )

    if (-not (Test-Path $DefaultFolder)) { New-Item -ItemType Directory -Path $DefaultFolder | Out-Null }

    Write-Host "`nSelect file type for saving:" -ForegroundColor Cyan
    Write-Host "1 - TXT"
    Write-Host "2 - CSV"
    Write-Host "3 - None"
    $fileChoice = Read-Host "Enter choice (1-3)"
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    switch ($fileChoice) {
        "1" {
            $logFile = Join-Path $DefaultFolder "$DefaultName`_$timestamp.txt"
            $Content | Out-File -FilePath $logFile
            Write-Host "Log saved as TXT: $logFile" -ForegroundColor Green
        }
        "2" {
            $logFile = Join-Path $DefaultFolder "$DefaultName`_$timestamp.csv"

            # Helper function για flatten
            function ConvertTo-FlatObject {
                param([PSCustomObject]$obj)
                $flat = @{}
                foreach ($prop in $obj.PSObject.Properties) {
                    $val = $prop.Value
                    if ($val -is [System.Collections.IEnumerable] -and $val -isnot [string]) {
                        $val = ($val | ForEach-Object { $_ }) -join ", "
                    }
                    $flat[$prop.Name] = $val
                }
                return [PSCustomObject]$flat
            }

            if ($Content -is [string]) {
                $Content | ForEach-Object { [PSCustomObject]@{ Line = $_ } } | Export-Csv -Path $logFile -NoTypeInformation
            }
            elseif ($Content -is [System.Collections.IEnumerable] -and $Content -and $Content[0] -is [string]) {
                $Content | ForEach-Object { [PSCustomObject]@{ Value = $_ } } | Export-Csv -Path $logFile -NoTypeInformation
            }
            else {
                $csvContent = $Content | ForEach-Object {
                    if ($_ -is [PSCustomObject]) { ConvertTo-FlatObject $_ } else { [PSCustomObject]@{ Value = $_ } }
                }
                $csvContent | Export-Csv -Path $logFile -NoTypeInformation
            }

            Write-Host "Log saved as CSV: $logFile" -ForegroundColor Green
        }
        "3" {
            Write-Host "Log not saved." -ForegroundColor Yellow
        }
    }
}

do {
    Clear-Host
    Write-Host "=== Interactive System ===" -ForegroundColor Cyan
    Write-Host "1 - Task Manager"
    Write-Host "2 - Network"
    Write-Host "3 - Services"
    Write-Host "4 - Disk Usage & System Health"
    Write-Host "5 - Security & Firewall"
    Write-Host "6 - Accounts"
    Write-host "7 - Control Panel / System Utilities"
    Write-Host "8 - Device Management / Peripherals"
    Write-Host "0 - Exit"

    $choice = Read-Host "Enter your choice (0-8 or multiple with comma e.g. 1,4)"
    $choicesArray = $choice.Split(",") | ForEach-Object { $_.Trim() }

    foreach ($c in $choicesArray) {
        switch ($c) {
            "0" { $exit = $true }

            #  1: Open Task Manager 
        "1" {
                Write-Host "`nOpening Task Manager..." -ForegroundColor Cyan
                Start-Process "taskmgr.exe"
        }

             #  2: IP / Network Submenu 
        "2" {
                $ipExit = $false
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

                    $ipChoice = Read-Host "Enter choice (0-5)"
                    $logFolder = Join-Path $baseFolder "ip_logs"

                    switch ($ipChoice) {
                        "0" { $ipExit = $true }

                        "1" {
                            Write-Host "`n--- Local IPs ---" -ForegroundColor Yellow
                            $ipData = Get-NetIPAddress | Select-Object IPAddress, InterfaceAlias
                            Write-Host ($ipData | Format-Table -AutoSize | Out-String)
                            Save-Log -Content $ipData -DefaultFolder $logFolder -DefaultName "local_ip"
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
                                Save-Log -Content $ping -DefaultFolder $logFolder -DefaultName "ping_$target"
                            }
                        }

                        "4" {
                                Write-Host "`n--- LAN Scan (Active Hosts Only) ---" -ForegroundColor Yellow
                                Write-Host "Press 'E' to stop scanning." -ForegroundColor Red

                                $activeHosts = @()
                                $stoppedByUser = $false

                                # Παίρνουμε το IPv4 του υπολογιστή
                                $localIP = (Get-NetIPAddress -AddressFamily IPv4 |
                                            Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
                                            Select-Object -First 1 -ExpandProperty IPAddress)

                                if (-not $localIP) {
                                    Write-Host "No valid IPv4 address found." -ForegroundColor Red
                                    return
                                }

                                # Παίρνουμε το subnet (π.χ., 192.168.40)
                                $subnetParts = $localIP -split "\."
                                $subnet = "$($subnetParts[0]).$($subnetParts[1]).$($subnetParts[2])"
                                Write-Host "Detected subnet: $subnet.1-254" -ForegroundColor Cyan

                                for ($i = 1; $i -le 254; $i++) {
                                    if ([console]::KeyAvailable) {
                                        $key = [console]::ReadKey($true)
                                        if ($key.Key -eq "E") {
                                            $stoppedByUser = $true
                                            break
                                        }
                                    }

                                    $ip = "$subnet.$i"
                                    if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                                        Write-Host "Online: $ip" -ForegroundColor Green
                                        $activeHosts += $ip
                                    }
                                }

                                if ($stoppedByUser) {
                                    Write-Host "`nScan stopped by user." -ForegroundColor Red
                                } else {
                                    Write-Host "`nScan finished." -ForegroundColor Cyan
                                }

                                if ($activeHosts.Count -eq 0) {
                                    Write-Host "No active hosts found." -ForegroundColor Yellow
                                } else {
                                    Write-Host "`nActive hosts:" -ForegroundColor Green
                                    $activeHosts | ForEach-Object { Write-Host $_ -ForegroundColor Green }

                                    # Αποθήκευση log μόνο με ενεργά hosts
                                    $ipLogFolder = Join-Path $baseFolder "ip_logs"
                                    if (-not (Test-Path $ipLogFolder)) { New-Item -ItemType Directory -Path $ipLogFolder | Out-Null }
                                    Save-Log -Content $activeHosts -DefaultFolder $ipLogFolder -DefaultName "lan_scan_active"
                                }

                                Read-Host "`nPress Enter to return..."
                        }


                        "5" {
                            # --- 2.5 Advanced Network Info submenu ---
                            $advExit = $false
                            do {
                                Clear-Host
                                Write-Host "`n=== Advanced Network Info ===" -ForegroundColor Cyan
                                Write-Host "1 - Network Interfaces (IP, MAC, Gateway, DNS)"
                                Write-Host "2 - Traffic Stats (Packets/Bytes Sent & Received)"
                                Write-Host "3-  TCP & UDP Connections + Ping "
                                Write-Host "0 - Return to Network Menu"

                                $advChoice = Read-Host "Enter choice (0-2)"

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
                                        Save-Log -Content @{Interfaces=$netIfaces; Gateways=$netGateways; DNS=$netDNS} -DefaultFolder $logFolder -DefaultName "network_interfaces"
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
                                        Save-Log -Content $trafficKB -DefaultFolder $logFolder -DefaultName "network_traffic"
                                    }
                                    "3" {
                                        Write-Host "`n--- TCP & UDP Connections + Ping ---" -ForegroundColor Yellow

                                        # TCP & UDP connections
                                        $tcpConnections = (Get-NetTCPConnection).Count
                                        $udpConnections = (Get-NetUDPEndpoint).Count
                                        Write-Host "Active TCP Connections: $tcpConnections" -ForegroundColor Green
                                        Write-Host "Active UDP Connections: $udpConnections" -ForegroundColor Green

                                        # Ping 8.8.8.8
                                        $pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 4
                                        $avgLatency = [math]::Round(($pingResult | Measure-Object ResponseTime -Average).Average,2)
                                        Write-Host "Ping 8.8.8.8 Average Latency: $avgLatency ms" -ForegroundColor Cyan

                                        # Prepare log object
                                        $netSummary = [PSCustomObject]@{
                                            TCPConnections = $tcpConnections
                                            UDPConnections = $udpConnections
                                            PingAverageMs  = $avgLatency
                                        }

                                        # Save log
                                        Save-Log -Content $netSummary -DefaultFolder $logFolder -DefaultName "tcp_udp_ping"
                                    }
                                    

                                    default { Write-Host "Invalid choice." -ForegroundColor Red }
                                }

                                if (-not $advExit) {
                                    Write-Host "`nPress Enter to continue..."
                                    Read-Host
                                }

                            } while (-not $advExit)
                        }

                        "6" {
                                $toolsExit = $false
                                do {
                                    Clear-Host
                                    Write-Host "`n=== Network Tools ===" -ForegroundColor Cyan
                                    Write-Host "1 - List Wi-Fi Profiles"
                                    Write-Host "2 - Traceroute to Host"
                                    Write-Host "3 - Port Scan"
                                    Write-Host "4 - Send file"
                                    Write-Host "0 - Return to Network Menu"

                                    $toolChoice = Read-Host "Enter choice (0-3)"

                                    switch ($toolChoice) {
                                        "0" { $toolsExit = $true }

                                        "1" {
                                            Write-Host "`n--- Wi-Fi Profiles & Passwords ---" -ForegroundColor Yellow
                                            $wifiProfiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
                                                ($_ -split ":")[1].Trim()
                                            }

                                            $wifiList = @()
                                            foreach ($wifi_profile in $wifiProfiles) {
                                                $keyInfo = netsh wlan show profile name="$wifi_profile" key=clear | Select-String "Key Content"
                                                $password = if ($keyInfo) { ($keyInfo -split ":")[1].Trim() } else { "<No Password>" }
                                                $wifiList += [PSCustomObject]@{
                                                    SSID = $wifi_profile
                                                    Password = $password
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
                                                    # Εκτέλεση παραδοσιακού traceroute
                                                    $traceroute = tracert.exe $host1 | ForEach-Object { $_.Trim() }
                                                    
                                                    if ($traceroute) {
                                                        # Εμφάνιση hops με αριθμό
                                                        $i = 1
                                                        foreach ($hop in $traceroute) {
                                                            Write-Host "$i`t$hop"
                                                            $i++
                                                        }
                                                        # Αποθήκευση log
                                                        Save-Log -Content $traceroute -DefaultFolder $logFolder -DefaultName "traceroute_$host1"
                                                    } else {
                                                        Write-Host "Traceroute failed or returned no hops." -ForegroundColor Red
                                                    }
                                                } catch {
                                                    Write-Host "Error performing traceroute: $_" -ForegroundColor Red
                                                }
                                            } else {
                                                Write-Host "No host entered." -ForegroundColor Red
                                            }
                                        }


                                        "3" {
                                            Write-Host "`n--- Port Scan ---" -ForegroundColor Yellow
                                            $target = Read-Host "Enter target IP/host"
                                            $portsInput = Read-Host "Enter ports to scan (comma separated or ranges, e.g. 80,443,3389,1000-1010)"
                                            
                                            # Δημιουργία λίστας θυρών
                                            $portList = @()
                                            foreach ($p in $portsInput -split ",") {
                                                $p = $p.Trim()
                                                if ($p -match '^\d+$') {
                                                    $portList += [int]$p
                                                } elseif ($p -match '^(\d+)-(\d+)$') {
                                                    $portList += [int]$matches[1]..[int]$matches[2]
                                                }
                                            }

                                            $scanResults = @()
                                            $allClosed = $true

                                            foreach ($port in $portList) {
                                                try {
                                                    $res = Test-NetConnection -ComputerName $target -Port $port -WarningAction SilentlyContinue
                                                    $status = if ($res.TcpTestSucceeded) { "Open" } else { "Closed" }
                                                    if ($res.TcpTestSucceeded) { $allClosed = $false }
                                                    $scanResults += [PSCustomObject]@{
                                                        Port = $port
                                                        Status = $status
                                                    }
                                                } catch {
                                                    $scanResults += [PSCustomObject]@{
                                                        Port = $port
                                                        Status = "Error"
                                                    }
                                                }
                                            }

                                            if ($allClosed) {
                                                Write-Host "`nAll scanned ports are closed. Possible Firewall / Host unreachable." -ForegroundColor Red
                                            }

                                            Write-Host "`nScan Results:"
                                            $scanResults | Format-Table -AutoSize

                                            Save-Log -Content $scanResults -DefaultFolder $logFolder -DefaultName "port_scan_$target"
                                        }

                                        "4" {
                                            $sendExit = $false
                                            do {
                                                Clear-Host
                                                Write-Host "`n=== Send File ===" -ForegroundColor Cyan
                                                Write-Host "1 - Local Network (UNC / PowerShell Remoting)"
                                                Write-Host "2 - FTP/SFTP Upload"
                                                Write-Host "3 - HTTP/HTTPS Upload"
                                                Write-Host "4 - Email Attachment"
                                                Write-Host "0 - Return to Network Menu"

                                                $sendChoice = Read-Host "Enter choice (0-4)"
                                                $logFolder = Join-Path $baseFolder "network_logs"

                                                switch ($sendChoice) {
                                                    "0" { $sendExit = $true }

                                                    # --- Local Network Copy ---
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

                                                        # Προσπάθεια αυτόματης εύρεσης fingerprint με ssh-keyscan
                                                        $fingerprint = $null
                                                        try {
                                                            if (Get-Command ssh-keyscan -ErrorAction SilentlyContinue) {
                                                                Write-Host "🔍 Detecting SSH fingerprint automatically..."
                                                                $rawKey = ssh-keyscan -t rsa $host1 2>$null | Select-String "ssh-rsa"
                                                                if ($rawKey) {
                                                                    # Μετατροπή σε fingerprint (MD5 format όπως το θέλει το WinSCP)
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

            # 3: Services
        "3" {
    $servicesExit = $false
    do {
                Clear-Host
                Write-Host "`n=== Services ===" -ForegroundColor Magenta
                Write-Host "1 - List Services"
                Write-Host "2 - Manage Services (services.msc)"
                Write-Host "3 - Start-Stop-Restart Service"
                Write-Host "0 - Return to Main Menu"

                $svcChoice = Read-Host "Enter choice (0-3)"
                $logFolder = Join-Path $baseFolder "service_logs"

            switch ($svcChoice) {
                "0" { $servicesExit = $true }

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
                # Έλεγχος admin
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

        if (-not $servicesExit) {
            Write-Host "`nPress Enter to continue..."
            Read-Host
        }

    } while (-not $servicesExit)
        }

            #  4: Disk Usage & System Health 
        "4" {
                Write-Host "Disk Usage" -ForegroundColor Cyan
                $logFolder = Join-Path $baseFolder "disk_logs"

                # Disk Usage (local disks only)
              $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType <> 5" |
              ForEach-Object {
            [PSCustomObject]@{
                Name      = $_.DeviceID
                Type      = $_.DriveType
                UsedGB    = if ($_.Size) { [math]::Round(($_.Size - $_.FreeSpace)/1GB, 2) } else { 0 }
                FreeGB    = if ($_.FreeSpace) { [math]::Round($_.FreeSpace/1GB, 2) } else { 0 }
                TotalGB   = if ($_.Size) { [math]::Round($_.Size/1GB, 2) } else { 0 }
            }
    }


                foreach ($drive in $drives) {
                Write-Host ("{0} | Type: {1} | Used: {2} GB | Free: {3} GB | Total: {4} GB" -f `
                $drive.Name, $drive.Type, $drive.UsedGB, $drive.FreeGB, $drive.TotalGB) -ForegroundColor White
}

                # --- System Health Metrics ---
                # CPU Usage
                $cpuLoad = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq "_Total"}).PercentProcessorTime

                # RAM Usage
                $ramInfo = Get-CimInstance Win32_OperatingSystem
                $ramUsedPercent = [math]::Round((($ramInfo.TotalVisibleMemorySize - $ramInfo.FreePhysicalMemory)/$ramInfo.TotalVisibleMemorySize)*100,2)

                # Network I/O
                $netStats = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface
                $netTotalKBps = [math]::Round(($netStats.BytesTotalPersec | Measure-Object -Sum).Sum/1KB,2)

                # Uptime
                $uptimeSpan = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                $uptimeStr = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes

                # Page file / Virtual Memory
                $pageFile = Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage

                # Battery info (if laptop)
                $battery = Get-CimInstance Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus

                # Color alerts
                $cpuColor = if ($cpuLoad -gt 80) { "Red" } elseif ($cpuLoad -gt 50) { "Yellow" } else { "Green" }
                $ramColor = if ($ramUsedPercent -gt 80) { "Red" } elseif ($ramUsedPercent -gt 50) { "Yellow" } else { "Green" }

                Write-Host "`n=== System Health ===" -ForegroundColor Cyan
                Write-Host "CPU Usage: $cpuLoad %" -ForegroundColor $cpuColor
                Write-Host ("RAM Usage: {0:N2}%" -f $ramUsedPercent) -ForegroundColor $ramColor
                Write-Host "Network : $netTotalKBps KB/s" -ForegroundColor White
                Write-Host "Uptime: $uptimeStr" -ForegroundColor White

                if ($pageFile) {
                    Write-Host "`nPage File Usage:" -ForegroundColor Magenta
                    $pageFile | Format-Table -AutoSize | Out-String | Write-Host
                }

                if ($battery) {
                    Write-Host "`nBattery Info:" -ForegroundColor Magenta
                    $battery | Format-Table -AutoSize | Out-String | Write-Host
                }

                # Top 5 processes by CPU
                Write-Host "`nTop 5 Processes (by CPU):" -ForegroundColor Yellow
                Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 `
                    @{Name="PID";Expression={$_.Id}},
                    @{Name="Process";Expression={$_.ProcessName}},
                    @{Name="CPU Time (s)";Expression={[math]::Round($_.CPU,2)}},
                    @{Name="RAM (MB)";Expression={[math]::Round($_.WorkingSet64/1MB,2)}} |
                    Format-Table -AutoSize

                # Save combined log
                $logContent = [PSCustomObject]@{
                    Disks            = $drives
                    CPU_UsagePercent = $cpuLoad
                    RAM_UsagePercent = $ramUsedPercent
                    Network_KBps     = $netTotalKBps
                    Uptime           = $uptimeStr
                    PageFile         = $pageFile
                    Battery          = $battery
                    TopProcesses     = $top5
                }
                Save-Log -Content $logContent -DefaultFolder $logFolder -DefaultName "disk_and_health"
        }

            #  5: Security & Firewall 
        "5" {
            $secExit = $false
            $logFolder = Join-Path $baseFolder "security_logs"

            do {
                Clear-Host
                Write-Host "`n=== Security & Firewall ===" -ForegroundColor Cyan
                Write-Host "1 - Windows Firewall Status"
                Write-Host "2 - Active Ports"
                Write-Host "3 - Antivirus / Windows Defender Status"
                Write-Host "0 - Return to Main Menu"

                $secChoice = Read-Host "Enter choice (0-3)"

                switch ($secChoice) {
                    "0" { $secExit = $true }

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

                if (-not $secExit) {
                    Write-Host "`nPress Enter to continue..."
                    Read-Host
                }

            } while (-not $secExit)
        }
        
            #  6: User Accounts & Sessions 
        "6" {
            $userExit = $false
            $logFolder = Join-Path $baseFolder "user_logs"
            # Έλεγχος αν τρέχει ως Administrator
            if (-not ([bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator"))) {
            Write-Host "You must run this script as Administrator!" -ForegroundColor Red
            continue 
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
                    "0" { $userExit = $true }

                    "1" {
                        Write-Host "`n--- All User Accounts ---" -ForegroundColor Yellow
                        $allUsers = Get-LocalUser | Select-Object Name, Enabled, Description
                        Write-Host ($allUsers | Format-Table -AutoSize | Out-String)
                        Save-Log -Content $allUsers -DefaultFolder $logFolder -DefaultName "all_users"
                    }

                    "2" {
                        Write-Host "`n--- Currently Logged-On Users ---" -ForegroundColor Yellow
                        $loggedUsers = quser 2>&1 | ForEach-Object { $_ } # quser may fail if run in non-elevated session
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
                
                if ([string]::IsNullOrWhiteSpace($sessionId)) {
                    Write-Host "No session ID entered. Aborting logoff." -ForegroundColor Red
                } else {
                    try {
                        logoff $sessionId
                        Write-Host "Session $sessionId logged off." -ForegroundColor Green
                        Save-Log -Content "Session $sessionId logged off at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "user_logoff"
                    } catch {
                        Write-Host "Error logging off session: $_" -ForegroundColor Red
                    }
                }
            }


                    default { Write-Host "Invalid choice." -ForegroundColor Red }
                }

                if (-not $userExit) {
                    Write-Host "`nPress Enter to continue..."
                    Read-Host
                }

                } while (-not $userExit)
        }
            #  7: Control Panel / System Utilities 
        "7" {
            $cpExit = $false
            $logFolder = Join-Path $baseFolder "control_panel_logs"

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
                    "0" { $cpExit = $true }


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
                    # Δημιουργία του φακέλου αν δεν υπάρχει
                    if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder | Out-Null }

                    # Δημιουργία προσωρινού log με Get-WindowsUpdateLog
                    $tempLog = Join-Path $env:TEMP "WindowsUpdate.log"
                    Get-WindowsUpdateLog -LogPath $tempLog

                    # Μεταφορά στο $logFolder
                    $finalLogPath = Join-Path $logFolder "WindowsUpdate.log"
                    Move-Item -Path $tempLog -Destination $finalLogPath -Force

                    Write-Host "WindowsUpdate.log written to $finalLogPath" -ForegroundColor Green

                    # Αν θέλεις, κρατάμε περιεχόμενο στη Save-Log
                    $updates = Get-Content $finalLogPath
                    Save-Log -Content $updates -DefaultFolder $logFolder -DefaultName "windows_updates"

                } catch {
                    Write-Host "Unable to retrieve updates." -ForegroundColor Red
                }
            }


                    "3" {
                Write-Host "`n--- System Restore Points ---" -ForegroundColor Yellow

                # Έλεγχος αν τρέχει ως Admin
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

                if (-not $isAdmin) {
                    Write-Host "You must run this script as Administrator!" -ForegroundColor Red
                } else {
                    try {
                        $restorePoints = Get-ComputerRestorePoint | 
                            Select-Object @{Name="Index";Expression={$_.SequenceNumber}},
                                        @{Name="Description";Expression={$_.Description}},
                                        @{Name="CreationTime";Expression={$_.CreationTime}},
                                        @{Name="Type";Expression={$_.EventType}}

                        if ($restorePoints) {
                            $restorePoints | Format-Table -AutoSize
                        } else {
                            Write-Host "No restore points found." -ForegroundColor Cyan
                        }
                    } catch {
                        Write-Host "Unable to retrieve restore points: $_" -ForegroundColor Red
                    }
                }

                Write-Host "`nPress Enter to continue..." 
                Read-Host
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
                        try {
                        $defenderSvc = Get-Service -Name "WinDefend"
                        if ($defenderSvc.Status -ne 'Running') {
                            Write-Host "Windows Defender service is not running. Cannot start scan!" -ForegroundColor Red
                        } else {
                            Start-MpScan -ScanType QuickScan
                            Write-Host "Quick scan initiated." -ForegroundColor Green
                        }
                        } catch {
                        Write-Host "Error starting scan: $_" -ForegroundColor Red
                        }

                    }

                    default { Write-Host "Invalid choice." -ForegroundColor Red }
                }

                if (-not $cpExit) {
                    Write-Host "`nPress Enter to continue..."
                    Read-Host
                }

            } while (-not $cpExit)
        }
            # 8: Device Management / Peripherals 
        "8" {
            $deviceExit = $false
            $logFolder = Join-Path $baseFolder "device_logs"

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
                    "0" { $deviceExit = $true }

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
                            Write-Host "No COM ports detected." -ForegroundColor Red
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
                        $deviceId = (Read-Host "Enter Device Instance ID (from List All Devices)").Trim()
                        $action = Read-Host "Enter action (enable/disable)"
                        try {
                            # Έλεγχος αν είναι USB drive
                            $disk = Get-Disk | Where-Object { $_.UniqueId -eq $deviceId -or $_.FriendlyName -eq $deviceId }
                            if ($disk) {
                                if ($action -eq "disable") {
                                    # Ασφαλές offline για USB
                                    Set-Disk -Number $disk.Number -IsOffline $true -ErrorAction Stop
                                    Write-Host "USB drive '$($disk.FriendlyName)' safely disabled/offline." -ForegroundColor Green
                                    Save-Log -Content "USB drive '$($disk.FriendlyName)' set offline at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                                } elseif ($action -eq "enable") {
                                    Set-Disk -Number $disk.Number -IsOffline $false -ErrorAction Stop
                                    Write-Host "USB drive '$($disk.FriendlyName)' set online." -ForegroundColor Green
                                    Save-Log -Content "USB drive '$($disk.FriendlyName)' set online at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                                } else {
                                    Write-Host "Invalid action." -ForegroundColor Red
                                }
                            } else {
                                # Για άλλες συσκευές PnP
                                if ($action -eq "enable") {
                                    Enable-PnpDevice -InstanceId $deviceId -Confirm:$false -ErrorAction Stop
                                    Write-Host "Device enabled." -ForegroundColor Green
                                    Save-Log -Content "Device $deviceId enabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                                } elseif ($action -eq "disable") {
                                    Disable-PnpDevice -InstanceId $deviceId -Confirm:$false -ErrorAction Stop
                                    Write-Host "Device disabled." -ForegroundColor Green
                                    Save-Log -Content "Device $deviceId disabled at $(Get-Date)" -DefaultFolder $logFolder -DefaultName "device_control"
                                } else {
                                    Write-Host "Invalid action." -ForegroundColor Red
                                }
                            }
                        } catch {
                            Write-Host "Error managing device: $_" -ForegroundColor Red
                        }
                    }


                        "6" {
                            Write-Host "`n--- Eject / Safely Remove USB Device ---" -ForegroundColor Yellow

                            # Παίρνουμε μόνο τα USB drives που είναι removable
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
                                        # Κατεβάζουμε το drive (offline) για ασφαλή αποσύνδεση
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
                        $deviceId = (Read-Host "Enter Device Instance ID").Trim()
                        try {
                            $devProps = Get-PnpDeviceProperty -InstanceId $deviceId
                            Write-Host ($devProps | Format-Table -AutoSize | Out-String)
                            Save-Log -Content $devProps -DefaultFolder $logFolder -DefaultName "device_properties"
                        } catch {
                            Write-Host "Error retrieving properties: $_" -ForegroundColor Red
                        }
                    }

                    default { Write-Host "Invalid choice." -ForegroundColor Red }
                }

                if (-not $deviceExit) {
                    Write-Host "`nPress Enter to continue..."
                    Read-Host
                }

            } while (-not $deviceExit)
        }
}    
    }

    if (-not $exit) {
        Write-Host "`nPress Enter to return to menu..."
        Read-Host
    }

} while (-not $exit)

Write-Host "`nExiting script. Thank you!" -ForegroundColor Cyan
