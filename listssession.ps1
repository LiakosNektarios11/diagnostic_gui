try {
        $out = @("--- Active Sessions ---")

        # Try with QUSER first
        $q = quser 2>&1
        if ($q -and ($q -notmatch "No user exists")) {
            $out += ($q | Out-String)
        } else {
            # If QUSER fails or is empty, use WMI fallback
            $out += "`r`n(No QUSER output - using WMI fallback...)"
            $sessions = Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction SilentlyContinue
            if ($sessions) {
                $list = foreach ($session in $sessions) {
                    try {
                        $user = ([WMI]$session.Antecedent)
                        $login = ([WMI]$session.Dependent)
                        [PSCustomObject]@{
                            Domain = $user.Domain
                            User   = $user.Name
                            LogonType = $login.LogonType
                        }
                    } catch {}
                }
                if ($list) {
                    $out += ($list | Sort-Object Domain,User | Format-Table -AutoSize | Out-String)
                } else {
                    $out += "`r`nNo active sessions found (WMI returned empty)."
                }
            } else {
                $out += "`r`nNo active sessions found."
            }
        }
    } catch {
        $out += "`r`nError retrieving session list: $($_.Exception.Message)"
    }
    