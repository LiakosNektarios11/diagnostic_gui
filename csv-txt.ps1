$btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save to CSV/TXT..."
    $btnSave.Width = 160
    $btnSave.Height = 26
    $btnSave.Anchor = "Top,Right"
    $btnSave.BackColor = [System.Drawing.Color]::DarkGreen
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "CSV (*.csv)|*.csv|Text (*.txt)|*.txt|All files (*.*)|*.*"
        $sfd.FileName = ($title -replace '[^\w\- ]','') + "_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
        if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $tb.Text | Out-File -FilePath $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Saved to $($sfd.FileName)","Saved",
                [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })


    # Κουμπί Save
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save to CSV/TXT..."
    $btnSave.Width = 140
    $btnSave.Height = 26
    $btnSave.Anchor = "Top,Right"
    $btnSave.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "CSV (*.csv)|*.csv|Text (*.txt)|*.txt|All files (*.*)|*.*"
        $sfd.FileName = ($title -replace '[^\w\- ]','') + "_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
        if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $tb.Text | Out-File -FilePath $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Saved to $($sfd.FileName)","Saved",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })