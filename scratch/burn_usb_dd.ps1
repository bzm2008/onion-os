# Onion OS Power Burn Script (DD Mode)
$IsoPath = "E:\llinux os\onion-os\output\onion-os-26.0.3-home-amd64.iso"
$DiskNumber = 2
$PhysicalDrive = "\\.\PhysicalDrive$DiskNumber"

Write-Host "Preparing to burn: $IsoPath" -ForegroundColor Cyan
Write-Host "Target Disk: Disk $DiskNumber ($PhysicalDrive)" -ForegroundColor Yellow
Write-Host "WARNING: All data will be destroyed!" -ForegroundColor Red

# 1. Clean disk using diskpart
Write-Host "Cleaning disk partition table..." -ForegroundColor Cyan
$diskpartScript = @"
select disk $DiskNumber
clean
exit
"@
$diskpartScript | diskpart | Out-Null

# 2. Perform raw block write (DD mode)
Write-Host "Starting raw burn (DD Mode)... This will take a few minutes..." -ForegroundColor Cyan

try {
    $isoStream = [System.IO.File]::OpenRead($IsoPath)
    $diskStream = [System.IO.File]::Open($PhysicalDrive, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    
    $buffer = New-Object byte[] 4MB
    $totalSize = $isoStream.Length
    $written = 0
    
    while (($bytesRead = $isoStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $diskStream.Write($buffer, 0, $bytesRead)
        $written += $bytesRead
        $percent = [math]::Round(($written / $totalSize) * 100, 1)
        if ($written % 100MB -lt 4MB) {
            Write-Host "Progress: $percent% ($([math]::Round($written/1MB, 0)) MB / $([math]::Round($totalSize/1MB, 0)) MB)"
        }
    }
    
    $isoStream.Close()
    $diskStream.Flush()
    $diskStream.Close()
    
    Write-Host "`nDONE! Burn successful." -ForegroundColor Green
    Write-Host "You can now try to boot from this USB." -ForegroundColor Cyan
}
catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Hint: Ensure no other programs are using the USB drive." -ForegroundColor Yellow
}
