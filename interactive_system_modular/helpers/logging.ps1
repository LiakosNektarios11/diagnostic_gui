# logging.ps1 - Save-Log helper (modular)
function Save-Log {
    param(
        [Parameter(Mandatory=$true)][Object]$Content,
        [Parameter(Mandatory=$true)][string]$DefaultFolder,
        [Parameter(Mandatory=$true)][string]$DefaultName
    )
    if (-not (Test-Path $DefaultFolder)) { New-Item -ItemType Directory -Path $DefaultFolder | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    Write-Host "`nSelect file type for saving:" -ForegroundColor Cyan
    Write-Host "1 - TXT"
    Write-Host "2 - CSV"
    Write-Host "3 - None"
    $fileChoice = Read-Host "Enter choice (1-3)"
    switch ($fileChoice) {
        "1" {
            $logFile = Join-Path $DefaultFolder "$DefaultName`_$timestamp.txt"
            $Content | Out-File -FilePath $logFile
            Write-Host "Log saved as TXT: $logFile" -ForegroundColor Green
        }
        "2" {
            $logFile = Join-Path $DefaultFolder "$DefaultName`_$timestamp.csv"
            if ($Content -is [string]) {
                $lines = $Content -split "`n" | ForEach-Object { [PSCustomObject]@{Line=$_} }
                $lines | Export-Csv -Path $logFile -NoTypeInformation
            } else {
                $Content | Export-Csv -Path $logFile -NoTypeInformation
            }
            Write-Host "Log saved as CSV: $logFile" -ForegroundColor Green
        }
        default {
            Write-Host "Log not saved." -ForegroundColor Yellow
        }
    }
}
