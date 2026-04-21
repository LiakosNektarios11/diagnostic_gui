# disk.ps1 - Disk Usage & System Health submenu
param([string]$BaseFolder)

function Show-DiskMenu {
    param([string]$BaseFolder)
    Clear-Host
    Write-Host "Disk Usage" -ForegroundColor Cyan
    $logFolder = Join-Path $BaseFolder "disk_logs"

    # Disk Usage (local disks only)
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object @{Name="Name";Expression={$_.DeviceID}},
                      @{Name="Used(GB)";Expression={"{0:N2}" -f (($_.Size - $_.FreeSpace)/1GB)}},
                      @{Name="Free(GB)";Expression={"{0:N2}" -f ($_.FreeSpace/1GB)}},
                      @{Name="Total(GB)";Expression={"{0:N2}" -f ($_.Size/1GB)}}

    foreach ($drive in $drives) {
        Write-Host ("{0} | Used: {1} GB | Free: {2} GB | Total: {3} GB" -f $drive.Name, $drive.'Used(GB)', $drive.'Free(GB)', $drive.'Total(GB)') -ForegroundColor White
    }

    # --- System Health Metrics ---
    $cpuLoad = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq "_Total"}).PercentProcessorTime
    $ramInfo = Get-CimInstance Win32_OperatingSystem
    $ramUsedPercent = [math]::Round((($ramInfo.TotalVisibleMemorySize - $ramInfo.FreePhysicalMemory)/$ramInfo.TotalVisibleMemorySize)*100,2)
    $netStats = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface
    $netTotalKBps = [math]::Round(($netStats.BytesTotalPersec | Measure-Object -Sum).Sum/1KB,2)
    $uptimeSpan = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
    $pageFile = Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage
    $battery = Get-CimInstance Win32_Battery | Select-Object EstimatedChargeRemaining, BatteryStatus

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

    Write-Host "`nTop 5 Processes (by CPU):" -ForegroundColor Yellow
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 `
        @{Name="PID";Expression={$_.Id}},
        @{Name="Process";Expression={$_.ProcessName}},
        @{Name="CPU Time (s)";Expression={[math]::Round($_.CPU,2)}},
        @{Name="RAM (MB)";Expression={[math]::Round($_.WorkingSet64/1MB,2)}} |
        Format-Table -AutoSize

    $logContent = [PSCustomObject]@{
        Disks            = $drives
        CPU_UsagePercent = $cpuLoad
        RAM_UsagePercent = $ramUsedPercent
        Network_KBps     = $netTotalKBps
        Uptime           = $uptimeStr
        PageFile         = $pageFile
        Battery          = $battery
    }
    Save-Log -Content $logContent -DefaultFolder $logFolder -DefaultName "disk_and_health"

    Read-Host "`nPress Enter to return..."
}
