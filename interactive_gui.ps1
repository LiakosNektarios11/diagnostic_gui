Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$Global:BaseLogFolder = Join-Path -Path $env:ProgramData -ChildPath "MyTool_Logs"
if (-not (Test-Path $Global:BaseLogFolder)) {
    New-Item -ItemType Directory -Path $Global:BaseLogFolder -Force | Out-Null
}
$Global:LogCategories = @(
    "Network",
    "Services",
    "Disk Usage & Health",
    "Security & Firewall",
    "Accounts & Sessions",
    "System Info",
    "Devices"
)
foreach ($cat in $Global:LogCategories) {
    $path = Join-Path $Global:BaseLogFolder $cat
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}
function Save-Result {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,   
        [Parameter(Mandatory = $true)]
        [string]$Content,   
        [string]$Prefix = "Result"  
    )

    $choice = [System.Windows.Forms.MessageBox]::Show(
        "Do you want to save '$Category'?",
        "Save Log",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
        $folder = Join-Path $Global:BaseLogFolder $Category
        $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
        $filename = "$Prefix-$timestamp.txt"
        $filepath = Join-Path $folder $filename
        $Content | Out-File -FilePath $filepath -Encoding UTF8 -Force
        [System.Windows.Forms.MessageBox]::Show("Result saved:`n$filepath","Save succeed",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)

        return
    }
}
# ---------- Main form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Interactive System - GUI"
$form.Size = New-Object System.Drawing.Size(520,520)
$form.StartPosition = "CenterScreen"

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Interactive System"
$lbl.Font = New-Object System.Drawing.Font("Segoe UI",14,[System.Drawing.FontStyle]::Bold)
$lbl.AutoSize = $true
$lbl.Location = New-Object System.Drawing.Point(12,12)
$form.Controls.Add($lbl)

# Buttons layout helper
function New-MenuButton($text, $x, $y, $width=200, $height=36, $action) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Size = New-Object System.Drawing.Size($width,$height)
    $b.Location = New-Object System.Drawing.Point($x,$y)
    if ($action) { $b.Add_Click($action) }
    return $b
}
# Row 1
$form.Controls.Add( (New-MenuButton "1 - Task Manager" 24 60 200 40 { Start-Process "taskmgr.exe" }) )
$form.Controls.Add( (New-MenuButton "2 - Network" 260 60 200 40 {
    # --- Network Submenu GUI ---
    $netWin = New-Object System.Windows.Forms.Form
    $netWin.Text = "Network Tools"
    $netWin.Size = New-Object System.Drawing.Size(800,480)
    $netWin.StartPosition = "CenterParent"
    $netWin.BackColor = [System.Drawing.Color]::White
    $netWin.ForeColor = [System.Drawing.Color]::Black

    function Show-NetOutput($title, $scriptBlock) {
        $outputWin = New-Object System.Windows.Forms.Form
        $outputWin.Text = $title
        $outputWin.Size = New-Object System.Drawing.Size(800,500)
        $outputWin.StartPosition = "CenterParent"

        $box = New-Object System.Windows.Forms.TextBox
        $box.Multiline = $true
        $box.ScrollBars = "Vertical"
        $box.ReadOnly = $true
        $box.Dock = "Fill"
        $box.Font = New-Object System.Drawing.Font("Consolas",10)
        $box.BackColor = "Black"
        $box.ForeColor = "Lime"

        try {
            $result = & $scriptBlock | Out-String
            $box.Text = $result
        } catch {
            $box.Text = "Error: $_"
        }

        $outputWin.Controls.Add($box)
        $outputWin.ShowDialog()
    }

    # --- Buttons Layout ---
    $buttons = @(
        @{Text="Local IPs"; X=20; Y=20; Action={
            try {
                $result = Get-NetIPAddress | Select-Object IPAddress, InterfaceAlias, AddressFamily
                if ($result) {
                    $resultText = $result | Format-Table -AutoSize -Wrap | Out-String
                } else {
                    $resultText = "No IP addresses found."
                }

                Show-NetOutput "Local IPs" {$resultText}
                Save-Result -Category "Network" -Content $resultText -Prefix "LocalIPs"

            } catch {
                $err = "Error retrieving local IP addresses: $($_.Exception.Message)"
                Show-NetOutput "Local IPs" $err
                Save-Result -Category "Network" -Content $err -Prefix "LocalIPs_Error"
            }
        }},
        @{Text="Public IP"; X=200; Y=20; Action={
            try {
                $public = Invoke-RestMethod -Uri "https://api.ipify.org?format=json"
                if ($public.ip) {
                    $resultText = "Your Public IP: $($public.ip)"
                } else {
                    $resultText = "No public IP retrieved."
                }

                Show-NetOutput "Public IP" {$resultText}
                Save-Result -Category "Network" -Content $resultText -Prefix "PublicIP"

            } catch {
                $err = "Error retrieving public IP: $($_.Exception.Message)"
                Show-NetOutput "Public IP" $err
                Save-Result -Category "Network" -Content $err -Prefix "PublicIP_Error"
            }
        }},
        @{Text="Ping Test"; X=380; Y=20; Action={
            Add-Type -AssemblyName Microsoft.VisualBasic
            $target = [Microsoft.VisualBasic.Interaction]::InputBox(
                "Enter host/IP to ping (e.g. 8.8.8.8)",
                "Ping Test"
            )

            if ($target) {
                try {
                    $pingResult = cmd /c "ping $target"
                    $resultText = ($pingResult -join "`r`n")
                    Show-NetOutput "Ping Test - $target" {$resultText}
                    Save-Result -Category "Network" -Content $resultText -Prefix "PingTest"
                } catch {
                    $err = "Ping failed: $($_.Exception.Message)"
                    Show-NetOutput "Ping Test - $target" $err
                    Save-Result -Category "Network" -Content $err -Prefix "PingTest_Error"
                }
            }
        }},
        @{Text="LAN Scan"; X=560; Y=20; Action={
        $resultText = & {
            try {
                $maxConcurrent = 50
                $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1 -ExpandProperty IPAddress)
                if (-not $localIP) { return "No valid IPv4 address found on this device." }
                $subnet = ($localIP -split '\.')[0..2] -join '.'
                "Detected subnet: $subnet.1-254`r`nStarting scan...`r`n"
                $ips = (1..254) | ForEach-Object { "$subnet.$_" }
                $results = [System.Collections.Generic.List[object]]::new()
                $useThreadJob = (Get-Command -Name Start-ThreadJob -ErrorAction SilentlyContinue) -ne $null
                for ($i = 0; $i -lt $ips.Count; $i += $maxConcurrent) {
                    $batch = $ips[$i..([math]::Min($i + $maxConcurrent - 1, $ips.Count - 1))]
                    $jobs = @()
                    foreach ($ip in $batch) {
                        if ($useThreadJob) {
                            $job = Start-ThreadJob -ArgumentList $ip -ScriptBlock {
                                param($ip)
                                if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                                    [PSCustomObject]@{IP=$ip;Status="Online"}
                                }
                            }
                            $jobs += $job
                        } else {
                            $job = Start-Job -ArgumentList $ip -ScriptBlock {
                                param($ip)
                                if (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                                    [PSCustomObject]@{IP=$ip;Status="Online"}
                                }
                            }
                            $jobs += $job
                        }
                    }
                    if ($jobs.Count -gt 0) {
                        $null = Wait-Job -Job $jobs
                        foreach ($j in $jobs) {
                            $r = Receive-Job -Job $j -ErrorAction SilentlyContinue
                            if ($r) {
                                if ($r -is [System.Array]) {
                                    foreach ($item in $r) { $results.Add($item) }
                                } else {
                                    $results.Add($r)
                                }
                            }
                            try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {}
                        }
                    }
                }
                if ($results.Count -eq 0) {
                    "No active hosts found on $subnet.0/24."
                } else {
                    "Active hosts found:`r`n" + ($results | Sort-Object IP | Select-Object IP, Status | Format-Table -AutoSize -Wrap | Out-String)
                }
            } catch {
                "Scan failed: $($_.Exception.Message)"
            }
        }
        Show-NetOutput "LAN Scan (Active Hosts Only)" {$resultText}
        Save-Result -Category "Network" -Content ($resultText -join "`r`n") -Prefix "LANScan"
        }},
        @{Text="Advanced Info"; X=20; Y=80; Action={
            $resultText = & {
                try {
                    $ifaces = Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed
                    $gateways = Get-NetRoute | Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | Select-Object InterfaceAlias, NextHop
                    $dns = Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses
                    "=== Interfaces ===`n" + ($ifaces | Format-Table -AutoSize -Wrap | Out-String) +
                    "`n=== Gateways ===`n" + ($gateways | Format-Table -AutoSize -Wrap | Out-String) +
                    "`n=== DNS Servers ===`n" + ($dns | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    "Error retrieving advanced network info: $($_.Exception.Message)"
                }
            }
            Show-NetOutput "Advanced Network Info" {$resultText}
            Save-Result -Category "Network" -Content ($resultText -join "`r`n") -Prefix "AdvancedInfo"
        }},
        @{Text="Traffic Stats"; X=200; Y=80; Action={
        $resultText = & {
            try {
                Get-NetAdapterStatistics | Select-Object Name,
                    @{Name='ReceivedMB'; Expression={[math]::Round($_.ReceivedBytes/1MB,2)}},
                    @{Name='SentMB'; Expression={[math]::Round($_.SentBytes/1MB,2)}},
                    @{Name='ReceivedPackets'; Expression={if ($_.ReceivedPackets){[int64]$_.ReceivedPackets}else{0}}},
                    @{Name='SentPackets'; Expression={if ($_.SentPackets){[int64]$_.SentPackets}else{0}}}
            } catch {
                "Error retrieving traffic stats: $($_.Exception.Message)"
            }
        }
        $resultText | Format-Table -AutoSize -Wrap | Out-String
        Show-NetOutput "Traffic Statistics" {$resultText}
        Save-Result -Category "Network" -Content {$resultText} -Prefix "TrafficStats"
        }},
        @{Text="TCP/UDP & Ping"; X=380; Y=80; Action={
            $resultText = & {
                try {
                    $tcp = (Get-NetTCPConnection).Count
                    $udp = (Get-NetUDPEndpoint).Count
                    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop
                    $avg = [math]::Round(($ping | Measure-Object ResponseTime -Average).Average,2)
                    [PSCustomObject]@{TCP=$tcp;UDP=$udp;Ping_Avg_ms=$avg}
                } catch {
                    "Error retrieving connection or ping data: $($_.Exception.Message)"
                }
            }
            Show-NetOutput "TCP/UDP Connections + Ping" { $resultText | Format-Table -AutoSize | Out-String }
            Save-Result -Category "Network" -Content ($resultText | Format-Table -AutoSize -Wrap | Out-String) -Prefix "TCP_UDP_Ping"
        }},
        @{Text="Wi-Fi Profiles"; X=560; Y=80; Action={
            $resultText = & {
                try {
                    $wifi = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[1].Trim() }
                    if (-not $wifi) { return "No Wi-Fi profiles found." }
                    foreach ($w in $wifi) {
                        $key = netsh wlan show profile name="$w" key=clear | Select-String "Key Content"
                        $wifiPwd = if ($key) { ($key -split ":")[1].Trim() } else { "<Hidden>" }
                        [PSCustomObject]@{SSID=$w;Password=$wifiPwd}
                    }
                } catch {
                    "Error retrieving Wi-Fi profiles: $($_.Exception.Message)"
                }
            }
            Show-NetOutput "Wi-Fi Profiles" { $resultText | Format-Table -AutoSize | Out-String }
            Save-Result -Category "Network" -Content ($resultText | Format-Table -AutoSize -Wrap | Out-String) -Prefix "WiFiProfiles"
        }},
        @{Text="Traceroute"; X=20; Y=140; Action={
        try {
            Add-Type -AssemblyName Microsoft.VisualBasic
            $traceHost = [Microsoft.VisualBasic.Interaction]::InputBox("Enter host to traceroute (e.g. google.com)", "Traceroute")
            if ($traceHost) {
                try {
                    $resultText = tracert.exe $traceHost | Out-String
                    Show-NetOutput "Traceroute $traceHost" { $resultText }
                    Save-Result -Category "Network" -Content $resultText -Prefix "Traceroute"
                } catch {
                    $err = "Traceroute failed: $($_.Exception.Message)"
                    Show-NetOutput "Traceroute $traceHost" $err
                    Save-Result -Category "Network" -Content $err -Prefix "Traceroute_Error"
                }
            }
        } catch {
            $err = "Error initializing traceroute input: $($_.Exception.Message)"
            Show-NetOutput "Traceroute" $err
            Save-Result -Category "Network" -Content $err -Prefix "Traceroute_Init_Error"
        }
        }},
        @{Text="Port Scan"; X=200; Y=140; Action={
            try {
                Add-Type -AssemblyName Microsoft.VisualBasic
                $target = [Microsoft.VisualBasic.Interaction]::InputBox("Enter target host/IP", "Port Scan")
                $ports = [Microsoft.VisualBasic.Interaction]::InputBox("Enter ports (e.g. 22,80,443,3389)", "Port Scan")
                if ($target -and $ports) {
                    try {
                        $scanResults = @()
                        foreach ($p in $ports -split ",") {
                            $p = $p.Trim()
                            if ($p -match '^\d+$') {
                                $portNum = [int]$p
                                $ok = Test-NetConnection -ComputerName $target -Port $portNum -WarningAction SilentlyContinue
                                $scanResults += [PSCustomObject]@{
                                    Port = $portNum
                                    Status = if ($ok.TcpTestSucceeded) { "Open" } else { "Closed" }
                                }
                            }
                        }
                        $resultText = $scanResults | Format-Table -AutoSize -Wrap | Out-String
                        Show-NetOutput "Port Scan $target" { $resultText }
                        Save-Result -Category "Network" -Content $resultText -Prefix "PortScan"
                    } catch {
                        $err = "Port scan failed: $($_.Exception.Message)"
                        Show-NetOutput "Port Scan $target" $err
                        Save-Result -Category "Network" -Content $err -Prefix "PortScan_Error"
                    }
                }
            } catch {
                $err = "Error initializing port scan input: $($_.Exception.Message)"
                Show-NetOutput "Port Scan" $err
                Save-Result -Category "Network" -Content $err -Prefix "PortScan_Init_Error"
            }
        }},
        @{Text="Close"; X=580; Y=380; Action={ $netWin.Close() }}
    )

    foreach ($b in $buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $b.Text
        $btn.Size = New-Object System.Drawing.Size(160,36)
        $btn.Location = New-Object System.Drawing.Point($b.X,$b.Y)
        $btn.Add_Click($b.Action)
        $netWin.Controls.Add($btn)
    }

    $netWin.ShowDialog()
}))
# Row 2
$form.Controls.Add( (New-MenuButton "3 - Services" 24 140 200 40 {
    # --- Services Submenu GUI ---
    $svcWin = New-Object System.Windows.Forms.Form
    $svcWin.Text = "Services Manager"
    $svcWin.Size = New-Object System.Drawing.Size(800,500)
    $svcWin.StartPosition = "CenterParent"

    # ListView for services
    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'
    $lv.FullRowSelect = $true
    $lv.MultiSelect = $false
    $lv.Dock = 'Top'
    $lv.Height = 350
    $lv.Columns.Add("Name",200)
    $lv.Columns.Add("Display Name",250)
    $lv.Columns.Add("Status",100)
    $lv.Columns.Add("StartType",100)

    # Function to load services
    function Get-ServicesList {
        $lv.Items.Clear()
        $services = Get-Service | Sort-Object DisplayName
        foreach ($svc in $services) {
            $item = New-Object System.Windows.Forms.ListViewItem([string]$svc.Name)
            $item.SubItems.Add([string]$svc.DisplayName)
            $item.SubItems.Add([string]$svc.Status)
            $item.SubItems.Add([string]$svc.StartType)

            # Color coding for status
            switch ($svc.Status) {
                'Running' { $item.BackColor = [System.Drawing.Color]::Green }
                'Stopped' { $item.BackColor = [System.Drawing.Color]::Red }
                default   { $item.BackColor = [System.Drawing.Color]::LightYellow }
            }

            $lv.Items.Add($item)
        }
    }

    Get-ServicesList

    # --- Buttons ---
    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text = "Start"; $btnStart.Width = 80; $btnStart.Location = New-Object System.Drawing.Point(20,370)
    $btnStart.Add_Click({
        if ($lv.SelectedItems.Count -eq 1) {
            $svcName = $lv.SelectedItems[0].Text
            $svcObj = Get-Service -Name $svcName
            if ($svcObj.Status -ne 'Running') {
                try {
                    Start-Service -Name $svcName -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show("Service '$svcName' started.","Info")
                    Get-ServicesList
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to start service: $($_.Exception.Message)","Error")
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Service '$svcName' is already running.","Info")
            }
        }
    })

    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Text = "Stop"; $btnStop.Width = 80; $btnStop.Location = New-Object System.Drawing.Point(120,370)
    $btnStop.Add_Click({
        if ($lv.SelectedItems.Count -eq 1) {
            $svcName = $lv.SelectedItems[0].Text
            $svcObj = Get-Service -Name $svcName
            if ($svcObj.CanStop -and $svcObj.Status -eq 'Running') {
                try {
                    Stop-Service -Name $svcName -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show("Service '$svcName' stopped.","Info")
                    Get-ServicesList
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to stop service: $($_.Exception.Message)","Error")
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Service '$svcName' cannot be stopped or is not running.","Warning")
            }
        }
    })

    $btnRestart = New-Object System.Windows.Forms.Button
    $btnRestart.Text = "Restart"; $btnRestart.Width = 80; $btnRestart.Location = New-Object System.Drawing.Point(220,370)
    $btnRestart.Add_Click({
        if ($lv.SelectedItems.Count -eq 1) {
            $svcName = $lv.SelectedItems[0].Text
            $svcObj = Get-Service -Name $svcName
            if ($svcObj.CanStop) {
                try {
                    Restart-Service -Name $svcName -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show("Service '$svcName' restarted.","Info")
                    Get-ServicesList
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to restart service: $($_.Exception.Message)","Error")
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("Service '$svcName' cannot be restarted.","Warning")
            }
        }
    })

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "Refresh"; $btnRefresh.Width = 80; $btnRefresh.Location = New-Object System.Drawing.Point(320,370)
    $btnRefresh.Add_Click({ Get-ServicesList })

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"; $btnClose.Width = 80; $btnClose.Location = New-Object System.Drawing.Point(420,370)
    $btnClose.Add_Click({ $svcWin.Close() })

    $svcWin.Controls.AddRange(@($lv,$btnStart,$btnStop,$btnRestart,$btnRefresh,$btnClose))
    $svcWin.ShowDialog()
}))
$form.Controls.Add( (New-MenuButton "4 - Disk Usage & Health" 260 140 200 40 {
    function Show-OutputWindow {
        param($title, $scriptBlock)

        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $win = New-Object System.Windows.Forms.Form
        $win.Text = $title
        $win.Size = New-Object System.Drawing.Size(800,600)
        $win.StartPosition = "CenterScreen"
        $win.BackColor = [System.Drawing.Color]::Black

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Multiline = $true
        $tb.ScrollBars = "Both"
        $tb.ReadOnly = $true
        $tb.Font = New-Object System.Drawing.Font("Consolas",10)
        $tb.Dock = "Fill"
        $tb.BackColor = [System.Drawing.Color]::Black
        $tb.ForeColor = [System.Drawing.Color]::Lime

        $pnl = New-Object System.Windows.Forms.Panel
        $pnl.Dock = "Top"
        $pnl.Height = 36
        $pnl.Padding = New-Object System.Windows.Forms.Padding(4)
        $pnl.BackColor = [System.Drawing.Color]::Black

        $win.Controls.Add($tb)
        $win.Controls.Add($pnl)
        $tb.Text = "Running..."

        $global:__LastResultText = ""

        $job = Start-Job -ScriptBlock {
            param($innerScript)
            try {
                $result = & ([ScriptBlock]::Create($innerScript))
                if ($result) {
                    $result | Out-String
                } else {
                    "No data returned."
                }
            } catch {
                "Error: $($_.Exception.Message)"
            }
        } -ArgumentList $scriptBlock.ToString()

        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 500
        $timer.Add_Tick({
            $state = Get-Job -Id $job.Id -ErrorAction SilentlyContinue
            if ($state -and $state.State -eq 'Completed') {
                $output = Receive-Job -Id $job.Id -ErrorAction SilentlyContinue
                $tb.Text = if ($output) { $output -join "`r`n" } else { "No output." }
                $global:__LastResultText = $tb.Text
                Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
                $timer.Stop()
            } elseif ($state -and $state.State -eq 'Failed') {
                $tb.Text = "Job failed: $($state.JobStateInfo.Reason.Message)"
                Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
                $timer.Stop()
            }
        })

        $timer.Start()

     
        $win.ShowDialog()
    }

    Show-OutputWindow "Disk & System Health" {
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage) -join ", "
        $ram = Get-CimInstance Win32_OperatingSystem | ForEach-Object { 
            "{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize) * 100)
        }
        $typeMap = @{
            0 = "Unknown"
            1 = "No Root Dir"
            2 = "Removable (USB)"
            3 = "Local Disk"
            4 = "Network Drive"
            5 = "CD/DVD"
            6 = "RAM Disk"
        }
        $disks = Get-CimInstance Win32_LogicalDisk | ForEach-Object {
            [PSCustomObject]@{
                Drive   = $_.DeviceID
                Type    = $typeMap[$_.DriveType]
                UsedGB  = "{0:N2}" -f (($_.Size - $_.FreeSpace) / 1GB)
                FreeGB  = "{0:N2}" -f ($_.FreeSpace / 1GB)
                TotalGB = "{0:N2}" -f ($_.Size / 1GB)
            }
        }
        $output = @()
        $output += "==================== SYSTEM HEALTH ===================="
        $output += "CPU Load : $cpu %"
        $output += "RAM Usage: $ram %"
        $output += ""
        $output += "===================== DISK USAGE ====================="
        $output += ($disks | Format-Table -AutoSize -Wrap | Out-String)
        $output -join "`r`n"
    }
    
    Save-Result -Category "Disk Usage & Health" -Content $global:__LastResultText -Prefix "DiskHealth"

}))
# Row 3
$form.Controls.Add( (New-MenuButton "5 - Security & Firewall" 24 220 200 40 {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    function Show-OutputWindow($title, $scriptBlock) {
        $win = New-Object System.Windows.Forms.Form
        $win.Text = $title
        $win.Size = New-Object System.Drawing.Size(800,600)
        $win.StartPosition = "CenterParent"
        $win.BackColor = [System.Drawing.Color]::White
        $win.ForeColor = [System.Drawing.Color]::Black

        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Multiline = $true
        $tb.ScrollBars = "Both"
        $tb.ReadOnly = $true
        $tb.BackColor = [System.Drawing.Color]::Black
        $tb.ForeColor = [System.Drawing.Color]::Lime
        $tb.Font = New-Object System.Drawing.Font("Consolas",9)
        $tb.Dock = "Fill"

        # Εκτέλεση script block και εμφάνιση αποτελέσματος
        try {
            $result = & $scriptBlock
            $tb.Text = $result | Out-String
        } catch {
            $tb.Text = "Error running script block: $($_.Exception.Message)"
        }

        $win.Controls.Add($tb)
        $win.ShowDialog()
    }
    $secWin = New-Object System.Windows.Forms.Form
    $secWin.Text = "Security & Firewall"
    $secWin.Size = New-Object System.Drawing.Size(700,420)
    $secWin.StartPosition = "CenterParent"
    $secWin.BackColor = [System.Drawing.Color]::White
    $secWin.ForeColor = [System.Drawing.Color]::Black

    $buttons = @(
        @{Text="Firewall Status"; X=20; Y=20; Action={
        try {
            $output = @()
            $output += "--- Windows Firewall Status ---"
            try {
                $fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
                $output += ($fwProfiles | Format-Table -AutoSize -Wrap | Out-String)
            } catch {
                $output += "Unable to retrieve Firewall status: $($_.Exception.Message)"
            }

            $resultText = $output -join "`r`n"
            Show-OutputWindow "Firewall Status" { $resultText }
            Save-Result -Category "Security & Firewall" -Content $resultText -Prefix "Firewall"
        } catch {
            $err = "Error retrieving Firewall Status: $($_.Exception.Message)"
            Show-OutputWindow "Firewall Status" $err
            Save-Result -Category "Security & Firewall" -Content $err -Prefix "Firewall_Error"
        }
        }},
        @{Text="Active Ports"; X=220; Y=20; Action={
            try {
                $output = @()
                $output += "--- Active Ports ---"
                try {
                    $netstat = netstat -ano | Select-String "LISTENING"
                    $output += ($netstat | Out-String)
                } catch {
                    $output += "Unable to retrieve active ports: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-OutputWindow "Active Ports" { $resultText }
                Save-Result -Category "Security & Firewall" -Content $resultText -Prefix "ActivePorts"
            } catch {
                $err = "Error retrieving Active Ports: $($_.Exception.Message)"
                Show-OutputWindow "Active Ports" $err
                Save-Result -Category "Security & Firewall" -Content $err -Prefix "ActivePorts_Error"
            }
        }},
        @{Text="Antivirus Status"; X=420; Y=20; Action={
            try {
                $output = @()
                $output += "--- Antivirus / Windows Defender Status ---"
                try {
                    $defender = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" |
                        Select-Object displayName, productState, pathToSignedProductExe
                    $output += ($defender | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    $output += "Unable to retrieve Antivirus status: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-OutputWindow "Antivirus Status" { $resultText }
                Save-Result -Category "Security & Firewall" -Content $resultText -Prefix "AntivirusStatus"
            } catch {
                $err = "Error retrieving Antivirus Status: $($_.Exception.Message)"
                Show-OutputWindow "Antivirus Status" $err
                Save-Result -Category "Security & Firewall" -Content $err -Prefix "AntivirusStatus_Error"
            }
        }},
        @{Text="Full Security Report"; X=20; Y=80; Action={
            try {
                $output = @()
                $output += "=== Security & Firewall ===`r`n"

                try {
                    $output += "--- Windows Firewall Status ---"
                    $fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
                    $output += ($fwProfiles | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    $output += "Unable to retrieve Firewall status: $($_.Exception.Message)"
                }

                try {
                    $output += "--- Active Ports ---"
                    $netstat = netstat -ano | Select-String "LISTENING"
                    $output += ($netstat | Out-String)
                } catch {
                    $output += "Unable to retrieve active ports: $($_.Exception.Message)"
                }

                try {
                    $output += "--- Antivirus / Windows Defender Status ---"
                    $defender = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" |
                                Select-Object displayName, productState, pathToSignedProductExe
                    $output += ($defender | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    $output += "Unable to retrieve Antivirus status: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-OutputWindow "Full Security & Firewall Report" { $resultText }
                Save-Result -Category "Security & Firewall" -Content $resultText -Prefix "FullSecurityReport"
            } catch {
                $err = "Error creating Full Security Report: $($_.Exception.Message)"
                Show-OutputWindow "Full Security & Firewall Report" $err
                Save-Result -Category "Security & Firewall" -Content $err -Prefix "FullSecurityReport_Error"
            }
        }},
        @{Text="Close"; X=420; Y=320; Action={ $secWin.Close() }}
    )

    foreach ($b in $buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $b.Text
        $btn.Size = New-Object System.Drawing.Size(180,36)
        $btn.Location = New-Object System.Drawing.Point($b.X,$b.Y)
        $btn.BackColor = [System.Drawing.Color]::White
        $btn.ForeColor = [System.Drawing.Color]::Black
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
        $btn.Add_Click($b.Action)
        $secWin.Controls.Add($btn)
    }

    $secWin.ShowDialog()
}))
$form.Controls.Add( (New-MenuButton "6 - Accounts & Sessions" 260 220 200 40 {
    if (-not ([bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator"))) {
        [System.Windows.Forms.MessageBox]::Show("You must run this as Administrator!","Permission Required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # --- Window ---
    $win = New-Object System.Windows.Forms.Form
    $win.Text = "User Accounts & Sessions"
    $win.Size = New-Object System.Drawing.Size(600,480)
    $win.StartPosition = "CenterParent"
    $win.BackColor = [System.Drawing.Color]::White 
    $win.ForeColor = [System.Drawing.Color]::Black 

    function Show-UserOutput($title, $scriptBlock) {
        $outWin = New-Object System.Windows.Forms.Form
        $outWin.Text = $title
        $outWin.Size = New-Object System.Drawing.Size(900,500)
        $outWin.StartPosition = "CenterParent"

        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Multiline = $true
        $txt.ScrollBars = "Both"
        $txt.ReadOnly = $true
        $txt.Dock = "Fill"
        $txt.Font = New-Object System.Drawing.Font("Consolas",10)
        $txt.BackColor = "Black"
        $txt.ForeColor = "Lime"
        
        # Execute script and capture output
        try {
            $result = & $scriptBlock | Out-String
            # Simple check for error/warning strings to change color
            if ($result -match "Error:" -or $result -match "Failed to connect" -or $result -match "not found" -or $result -match "Cannot log off") {
                $txt.ForeColor = "Yellow" 
            }
            $txt.Text = $result
        } catch {
            $txt.Text = "Error: $($_.Exception.Message)"
            $txt.ForeColor = "Red"
        }
        
        # Scroll to the bottom
        $txt.SelectionStart = $txt.Text.Length
        $txt.ScrollToCaret()

        $outWin.Controls.Add($txt)
        $outWin.ShowDialog()
    }
    
    # --- Buttons layout for the new GUI ---
    $buttons = @(
        @{Text="Connect Graph"; X=20; Y=20; Action={
            Show-UserOutput "Connect to Microsoft Graph" {
                try {
                    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
                        Write-Output "`r`nMicrosoft.Graph modules not found. Installing from PSGallery (this may take a few minutes)..."
                        Install-Module Microsoft.Graph -Force -AllowClobber -ErrorAction Stop
                    }
                    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
                    # request appropriate scopes for user read/write
                    Connect-MgGraph -Scopes "User.Read.All","User.ReadWrite.All" -ErrorAction Stop
                    Write-Output "`r`nConnected to Microsoft Graph."
                } catch {
                    Write-Output "`r`nFailed to connect to Microsoft Graph: $($_.Exception.Message)"
                }
            }
        }},
        @{Text="List Local Users"; X=200; Y=20; Action={
            try {
                $output = @()
                $output += "--- Local Users ---"
                try {
                    $users = Get-LocalUser -ErrorAction Stop | Select-Object Name, Enabled, Description
                    $output += ($users | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    $output += "`r`nError listing local users: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-UserOutput "Local Users" { $resultText }
                Save-Result -Category "Accounts & Sessions" -Content $resultText -Prefix "LocalUsers"
            } catch {
                $err = "Error retrieving local users: $($_.Exception.Message)"
                Show-UserOutput "Local Users" $err
                Save-Result -Category "Accounts & Sessions" -Content $err -Prefix "LocalUsers_Error"
            }
        }},
        @{Text="List AzureAD Users"; X=380; Y=20; Action={
            try {
                $output = @()
                $output += "--- AzureAD / Entra Users (Graph) ---"
                try {
                    if (-not (Get-Module Microsoft.Graph.Authentication -ListAvailable)) { 
                        throw "Not connected to Microsoft Graph. Click 'Connect Graph' first." 
                    }
                    $users = Get-MgUser -All | Select-Object DisplayName, UserPrincipalName, AccountEnabled
                    $output += ($users | Format-Table -AutoSize -Wrap | Out-String)
                } catch {
                    $output += "`r`nError listing Graph users: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-UserOutput "AzureAD / Entra Users (Graph)" { $resultText }
                Save-Result -Category "Accounts & Sessions" -Content $resultText -Prefix "AzureADUsers"
            } catch {
                $err = "Error retrieving AzureAD users: $($_.Exception.Message)"
                Show-UserOutput "AzureAD / Entra Users (Graph)" $err
                Save-Result -Category "Accounts & Sessions" -Content $err -Prefix "AzureADUsers_Error"
            }
        }},
        @{Text="List Sessions"; X=20; Y=80; Action={
            try {
                $output = @()
                $output += "--- Active Sessions ---"
                try {
                    $q = quser 2>&1
                    if ($q -and ($q -notmatch "No user exists")) {
                        $output += ($q | Out-String)
                    } else {
                        $output += "`r`n(No QUSER output - using WMI fallback...)"
                        $sessions = Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction SilentlyContinue
                        if ($sessions) {
                            $list = foreach ($session in $sessions) {
                                try {
                                    $user = ([WMI]$session.Antecedent)
                                    $login = ([WMI]$session.Dependent)
                                    [PSCustomObject]@{
                                        Domain = $user.Domain
                                        User = $user.Name
                                        LogonType = $login.LogonType
                                    }
                                } catch {}
                            }
                            if ($list) {
                                $output += ($list | Sort-Object Domain,User | Format-Table -AutoSize -Wrap | Out-String)
                            } else {
                                $output += "`r`nNo active sessions found."
                            }
                        }
                    }
                } catch {
                    $output += "`r`nError listing sessions: $($_.Exception.Message)"
                }

                $resultText = $output -join "`r`n"
                Show-UserOutput "Active Sessions" { $resultText }
                Save-Result -Category "Accounts & Sessions" -Content $resultText -Prefix "Sessions"
            } catch {
                $err = "Error retrieving session info: $($_.Exception.Message)"
                Show-UserOutput "Active Sessions" $err
                Save-Result -Category "Accounts & Sessions" -Content $err -Prefix "Sessions_Error"
            }
        }},
        @{Text="Enable/Disable User"; X=200; Y=80; Action={
            try {
                $inputName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter username (local) or user principal name (UPN) for AzureAD:", "Enable/Disable User")
                $action = [Microsoft.VisualBasic.Interaction]::InputBox("Enter action (enable or disable):", "Enable/Disable User")

                $output = @()
                if (-not ($inputName) -or -not ($action)) {
                    $output += "`r`nOperation cancelled or input empty."
                } else {
                    try {
                        $act = $action.ToLower().Trim()
                        if ($inputName -match "@") {
                            if (-not (Get-Module Microsoft.Graph.Authentication -ListAvailable)) {
                                throw "Not connected to Microsoft Graph. Click 'Connect Graph'."
                            }
                            $user = Get-MgUser -UserId $inputName -ErrorAction SilentlyContinue
                            if (-not $user) { throw "Graph user not found: $inputName" }
                            if ($act -eq "enable") { $enabledValue = $true }
                            elseif ($act -eq "disable") { $enabledValue = $false }
                            else { throw "Invalid action. Use enable or disable." }

                            Update-MgUser -UserId $user.Id -AccountEnabled:$enabledValue -ErrorAction Stop
                            $output += "`r`nGraph user '$inputName' set AccountEnabled=$enabledValue"
                        } else {
                            if ($act -eq "enable") {
                                Enable-LocalUser -Name $inputName -ErrorAction Stop
                                $output += "`r`nLocal user '$inputName' enabled."
                            } elseif ($act -eq "disable") {
                                Disable-LocalUser -Name $inputName -ErrorAction Stop
                                $output += "`r`nLocal user '$inputName' disabled."
                            } else {
                                $output += "`r`nInvalid action."
                            }
                        }
                    } catch {
                        $output += "`r`nError modifying user '$inputName': $($_.Exception.Message)"
                    }
                }

                $resultText = $output -join "`r`n"
                Show-UserOutput "Enable/Disable User: $inputName" { $resultText }
                Save-Result -Category "Accounts & Sessions" -Content $resultText -Prefix "UserModify"
            } catch {
                $err = "Error during user enable/disable: $($_.Exception.Message)"
                Show-UserOutput "Enable/Disable User" $err
                Save-Result -Category "Accounts & Sessions" -Content $err -Prefix "UserModify_Error"
            }
        }},
        @{Text="Force Logoff"; X=380; Y=80; Action={
            $sid = [Microsoft.VisualBasic.Interaction]::InputBox("Enter session ID to log off:", "Force Logoff")
            
            Show-UserOutput "Force Logoff Session $sid" {
                if (-not $sid) {
                    Write-Output "`r`nOperation cancelled or session ID empty."
                    return
                }
                try {
                    $logoffExe = "$env:SystemRoot\System32\logoff.exe"
                    if (-not (Test-Path $logoffExe)) { throw "logoff.exe not found at $logoffExe" }

                    $currentUserShort = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
                    $currentSession = (quser | ForEach-Object {
                        if ($_ -match $currentUserShort) {
                            ($_ -split '\s+')[2]
                        }
                    }) | Select-Object -First 1

                    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

                    if ("$sid" -eq "$currentSession") { # Convert to string for reliable comparison
                        # self logoff: use shutdown /l delayed in background
                        [System.Windows.Forms.MessageBox]::Show("Logging off your own session in 3 seconds...","Delayed Logoff",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
                        Start-Job -ScriptBlock {
                            Start-Sleep -Seconds 3
                            Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList "/l" -WindowStyle Hidden
                        } | Out-Null
                        Write-Output "`r`nYou will be logged off in 3 seconds..."
                    } else {
                        if (-not $isAdmin) {
                            [System.Windows.Forms.MessageBox]::Show("Run as Administrator to log off other users.","Permission Required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
                            Write-Output "`r`nCannot log off other users without admin privileges."
                        } else {
                            # run logoff directly (assuming script is already running as Admin)
                            $proc = Start-Process -FilePath $logoffExe -ArgumentList "$sid /f" -WindowStyle Hidden -PassThru -Wait
                            if ($proc.ExitCode -eq 0) {
                                Write-Output "`r`nSession $sid forcibly logged off (Exit Code 0)."
                            } else {
                                Write-Output "`r`nAttempted logoff for session $sid (Exit Code $($proc.ExitCode))."
                            }
                        }
                    }
                } catch {
                    Write-Output "`r`nError logging off session: $($_.Exception.Message)"
                }
            }
        }},
        @{Text="Close"; X=380; Y=380; Action={ $win.Close() }}
    )

    foreach ($b in $buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $b.Text
        $btn.Size = New-Object System.Drawing.Size(160,36)
        $btn.Location = New-Object System.Drawing.Point($b.X,$b.Y)
        $btn.Add_Click($b.Action)
        
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
        # Applying default button style (white/black)
        $btn.BackColor = [System.Drawing.Color]::White
        $btn.ForeColor = [System.Drawing.Color]::Black
        
       

        $win.Controls.Add($btn)
    }

    $win.ShowDialog()
}))
# Row 4
$form.Controls.Add( (New-MenuButton "7 - System Maintenance Tools" 24 300 200 40 {
    # --- System Maintenance Submenu GUI ---
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $sysWin = New-Object System.Windows.Forms.Form
    $sysWin.Text = "System Maintenance & Admin Utilities"
    $sysWin.Size = New-Object System.Drawing.Size(600,480)
    $sysWin.StartPosition = "CenterParent"
    $sysWin.BackColor = [System.Drawing.Color]::White
    $sysWin.ForeColor = [System.Drawing.Color]::Black

    # Function to show black output window with green text
    function Show-SysOutput($title, $scriptBlock) {
        $outWin = New-Object System.Windows.Forms.Form
        $outWin.Text = $title
        $outWin.Size = New-Object System.Drawing.Size(900,500)
        $outWin.StartPosition = "CenterParent"

        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Multiline = $true
        $txt.ScrollBars = "Both"
        $txt.ReadOnly = $true
        $txt.Dock = "Fill"
        $txt.Font = New-Object System.Drawing.Font("Consolas",10)
        $txt.BackColor = "Black"
        $txt.ForeColor = "Lime"

        try {
            $result = & $scriptBlock | Out-String
            $txt.Text = $result
        } catch {
            $txt.Text = "Error: $_"
        }

        $outWin.Controls.Add($txt)
        $outWin.ShowDialog()
    }
    # Buttons layout
    $buttons = @(
        @{Text="Installed Software"; X=20; Y=20; Action={
            try {
                $apps = Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
                        Where-Object { $_.DisplayName } |
                        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
                        Sort-Object DisplayName
                if ($apps) {
                    $resultText = $apps | Format-Table -AutoSize -Wrap | Out-String
                } else {
                    $resultText = "No installed software found."
                }
                Show-SysOutput "Installed Software" { $resultText }
                Save-Result -Category "System Info" -Content $resultText -Prefix "InstalledSoftware"
            } catch {
                $err = "Error retrieving installed software: $($_.Exception.Message)"
                Show-SysOutput "Installed Software" { $err }
                Save-Result -Category "System Info" -Content $err -Prefix "InstalledSoftware_Error"
            }
        }},
        @{Text="Windows Updates"; X=200; Y=20; Action={
            $output = @()
            $output += "--- Windows Updates Log (Partial) ---"
            try {
                $tempLog = Join-Path $env:TEMP "WindowsUpdate.log"
                Get-WindowsUpdateLog -LogPath $tempLog | Out-Null
                $partial = Get-Content $tempLog -ErrorAction SilentlyContinue | Select-Object -First 25
                if ($partial) {
                    $output += ($partial -join "`r`n")
                    $output += "`r`n(Log truncated - full log saved in TEMP folder)"
                } else {
                    $output += "No update log content found."
                }
            } catch {
                $output += "`r`nError retrieving Windows Update log: $($_.Exception.Message)"
            }

            $resultText = $output -join "`r`n"
            Show-SysOutput "Windows Updates" { $resultText }
            Save-Result -Category "System Info" -Content $resultText -Prefix "WindowsUpdates"
        }},
        @{Text="Clear Temp Files"; X=380; Y=20; Action={
            $output = @()
            $output += "--- Clear TEMP Files ---"
            try {
                $temp = $env:TEMP
                $count = 0
                Get-ChildItem -Path $temp -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        $count++
                    } catch {}
                }
                $output += "Removed $count items from $temp"
            } catch {
                $output += "`r`nError clearing TEMP files: $($_.Exception.Message)"
            }

            $resultText = $output -join "`r`n"
            Show-SysOutput "Clear TEMP Files" { $resultText }
            Save-Result -Category "System Info" -Content $resultText -Prefix "ClearTemp"
        }},
        @{Text="Event Viewer Logs"; X=20; Y=80; Action={
            $output = @()
            $output += "--- Event Viewer Logs ---"
            try {
                $output += "`r`n=== Application (last 15) ===`r`n"
                $appLogs = Get-WinEvent -LogName Application -MaxEvents 15 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, Id, LevelDisplayName, Message
                if ($appLogs) { 
                    $output += ($appLogs | Format-Table -AutoSize -Wrap | Out-String)
                } else {
                    $output += "`r`nNo Application events found."
                }

                $output += "`r`n=== System (last 15) ===`r`n"
                $sysLogs = Get-WinEvent -LogName System -MaxEvents 15 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, Id, LevelDisplayName, Message
                if ($sysLogs) {
                    $output += ($sysLogs | Format-Table -AutoSize -Wrap | Out-String)
                } else {
                    $output += "`r`nNo System events found."
                }
            } catch {
                $output += "`r`nError reading Event Viewer logs: $($_.Exception.Message)"
            }

            $resultText = $output -join "`r`n"
            Show-SysOutput "Event Viewer Logs" { $resultText }
            Save-Result -Category "System Info" -Content $resultText -Prefix "EventLogs"
        }},
        @{Text="Startup Programs"; X=200; Y=80; Action={
            $output = @()
            $output += "--- Startup Programs ---"
            try {
                $startup = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
                if ($startup) {
                    $entries = $startup.PSObject.Properties | ForEach-Object {
                        "{0,-30} {1}" -f $_.Name, $_.Value
                    }
                    if ($entries) {
                        $output += $entries
                    } else {
                        $output += "`r`nNo startup entries found."
                    }
                } else {
                    $output += "`r`nNo startup registry key found."
                }
            } catch {
                $output += "`r`nError reading startup programs: $($_.Exception.Message)"
            }

            $resultText = $output -join "`r`n"
            Show-SysOutput "Startup Programs" { $resultText }
            Save-Result -Category "System Info" -Content $resultText -Prefix "StartupPrograms"
        }},
        @{Text="Close"; X=400; Y=380; Action={ $sysWin.Close() }}
    )
    foreach ($b in $buttons) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $b.Text
        $btn.Size = New-Object System.Drawing.Size(160,36)
        $btn.Location = New-Object System.Drawing.Point($b.X,$b.Y)
        $btn.Add_Click($b.Action)
        $sysWin.Controls.Add($btn)
    }
    $sysWin.ShowDialog()
}))
$form.Controls.Add( (New-MenuButton "8 - Devices" 260 300 200 40 {

    $gui = New-Object System.Windows.Forms.Form
    $gui.Text = "Device Management / Peripherals"
    $gui.Size = New-Object System.Drawing.Size(800, 500)
    $gui.StartPosition = "CenterParent"
    $gui.BackColor = [System.Drawing.Color]::White
    $gui.ForeColor = [System.Drawing.Color]::Black
    $gui.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $gui.FormBorderStyle = 'Sizable'
    $gui.MaximizeBox = $true
    $gui.MinimizeBox = $true

    function Show-ConsoleWindow($title, $content) {
        $win = New-Object System.Windows.Forms.Form
        $win.Text = $title
        $win.Size = New-Object System.Drawing.Size(800, 600)
        $win.StartPosition = "CenterParent"
        $win.BackColor = [System.Drawing.Color]::Black
        $win.ForeColor = [System.Drawing.Color]::Lime
        $win.Font = New-Object System.Drawing.Font("Consolas", 10)
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Multiline = $true
        $tb.ScrollBars = "Both"
        $tb.ReadOnly = $true
        $tb.Dock = 'Fill'
        $tb.BackColor = [System.Drawing.Color]::Black
        $tb.ForeColor = [System.Drawing.Color]::Lime
        $tb.Text = $content
        $win.Controls.Add($tb)
        $win.ShowDialog()
    }

    function New-GUIButton($text, $x, $y, $action) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $text
        $btn.Width = 160
        $btn.Height = 36
        $btn.Location = New-Object System.Drawing.Point($x, $y)
        $btn.BackColor = [System.Drawing.Color]::White
        $btn.ForeColor = [System.Drawing.Color]::Black
        $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
        $btn.FlatAppearance.BorderSize = 1
        $btn.Add_Click($action)
        return $btn
    }
   $btnListAll = New-GUIButton "List All Devices" 40 40 {
    try {
        $devices = Get-PnpDevice | Select-Object Status, Class, FriendlyName, InstanceId
        if ($devices) {
            $txt = $devices | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "All Devices" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "AllDevices"
        } else {
            $msg = "No devices found."
            Show-ConsoleWindow "All Devices" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "AllDevices"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "AllDevices_Error"
    }
    }
    $btnComPorts = New-GUIButton "List COM Ports" 300 40 {
    try {
        $com = Get-WmiObject Win32_SerialPort | Select-Object DeviceID, Name, Description
        if ($com) {
            $txt = $com | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "COM Ports" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "COMPorts"
        } else {
            $msg = "No COM ports detected."
            Show-ConsoleWindow "COM Ports" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "COMPorts"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "COMPorts_Error"
    }
    }
    $btnUSB = New-GUIButton "List USB Devices" 40 120 {
    try {
        $usb = Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq "USB" } |
               Select-Object Status, FriendlyName, InstanceId
        if ($usb) {
            $txt = $usb | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "USB Devices" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "USBDevices"
        } else {
            $msg = "No USB devices found."
            Show-ConsoleWindow "USB Devices" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "USBDevices"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "USBDevices_Error"
    }
    }
    $btnPrinters = New-GUIButton "List Printers" 300 120 {
    try {
        $printers = Get-Printer | Select-Object Name, PrinterStatus, Default
        if ($printers) {
            $txt = $printers | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "Printers" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "Printers"
        } else {
            $msg = "No printers found."
            Show-ConsoleWindow "Printers" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "Printers"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "Printers_Error"
    }
    }
    $btnMonitors = New-GUIButton "List Monitors" 40 200 {
    try {
        $mon = Get-CimInstance Win32_DesktopMonitor | Select-Object Name, ScreenWidth, ScreenHeight, DeviceID
        if ($mon) {
            $txt = $mon | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "Monitors" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "Monitors"
        } else {
            $msg = "No monitors found."
            Show-ConsoleWindow "Monitors" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "Monitors"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "Monitors_Error"
    }
    }
    $btnAudio = New-GUIButton "Audio Devices" 300 200 {
    try {
        $audio = Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer, Status
        if ($audio) {
            $txt = $audio | Format-Table -AutoSize -Wrap| Out-String
            Show-ConsoleWindow "Audio Devices" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "AudioDevices"
        } else {
            $msg = "No audio devices found."
            Show-ConsoleWindow "Audio Devices" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "AudioDevices"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "AudioDevices_Error"
    }
    }
    $btnDisplay = New-GUIButton "Display Adapters" 40 280 {
    try {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM, DriverVersion
        if ($gpu) {
            $txt = $gpu | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "Display Adapters" $txt
            Save-Result -Category "Devices" -Content $txt -Prefix "DisplayAdapters"
        } else {
            $msg = "No display adapters found."
            Show-ConsoleWindow "Display Adapters" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "DisplayAdapters"
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "DisplayAdapters_Error"
    }
    }
    $btnProps = New-GUIButton "Device Properties" 300 280 {
        $id = [Microsoft.VisualBasic.Interaction]::InputBox("Enter InstanceId (copy from a list):","Device Properties")
        if (-not $id) { return }
        try {
            $props = Get-PnpDeviceProperty -InstanceId $id -ErrorAction Stop
            $txt = $props | Format-Table -AutoSize -Wrap | Out-String
            Show-ConsoleWindow "Device Properties - $id" $txt
        } catch {
            Show-ConsoleWindow "Error" $_.Exception.Message
        }
    }
    $btnEnableDisable = New-GUIButton "Enable / Disable Device" 560 40 {
    $id = [Microsoft.VisualBasic.Interaction]::InputBox("Enter InstanceId:", "Enable/Disable Device")
    if (-not $id) { return }

    $act = [Microsoft.VisualBasic.Interaction]::InputBox("Enter action (enable/disable):", "Enable/Disable Device")
    if (-not $act) { return }

    try {
        if ($act -eq 'enable') {
            Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
            $msg = "Device [$id] has been enabled successfully."
            Show-ConsoleWindow "Enable Device" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "EnableDevice"
        } elseif ($act -eq 'disable') {
            Disable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
            $msg = "Device [$id] has been disabled successfully."
            Show-ConsoleWindow "Disable Device" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "DisableDevice"
        } else {
            $msg = "Invalid action specified. Use 'enable' or 'disable'."
            Show-ConsoleWindow "Enable/Disable Device" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "InvalidAction"
            return
        }
    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "EnableDisableDevice_Error"
    }
    }
    $btnEject = New-GUIButton "Eject USB Drive" 560 120 {
    try {
        $disks = Get-Disk | Where-Object { $_.BusType -eq 'USB' } | Select-Object Number, FriendlyName, Size
        if (-not $disks) {
            $msg = "No USB drives detected."
            Show-ConsoleWindow "Eject USB" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "EjectUSB"
            return
        }

        $list = $disks | ForEach-Object { "{0}) {1} - {2} GB" -f ($disks.IndexOf($_) + 1), $_.FriendlyName, [math]::Round($_.Size/1GB,2) }
        $choice = [Microsoft.VisualBasic.Interaction]::InputBox("USB drives:`r`n$list`r`nEnter number to eject:", "Eject USB")
        if (-not $choice -or -not ($choice -match '^\d+$')) { return }

        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $disks.Count) {
            $msg = "Invalid selection."
            Show-ConsoleWindow "Eject USB" $msg
            Save-Result -Category "Devices" -Content $msg -Prefix "EjectUSB"
            return
        }

        $diskToEject = $disks[$idx]
        Set-Disk -Number $diskToEject.Number -IsOffline $true -ErrorAction Stop
        $msg = "Drive '$($diskToEject.FriendlyName)' set offline (ejected successfully)."
        Show-ConsoleWindow "Eject USB" $msg
        Save-Result -Category "Devices" -Content $msg -Prefix "EjectUSB"

    } catch {
        $err = $_.Exception.Message
        Show-ConsoleWindow "Error" $err
        Save-Result -Category "Devices" -Content $err -Prefix "EjectUSB_Error"
    }
    }
    $gui.Controls.AddRange(@($btnListAll, $btnComPorts, $btnUSB, $btnPrinters, $btnMonitors, $btnAudio, $btnDisplay, $btnProps, $btnEnableDisable, $btnEject))

    $gui.ShowDialog()

}))
$form.Controls.Add( (New-MenuButton "Exit" 150 380 220 40 { $form.Close() }) )

[void]$form.ShowDialog()
