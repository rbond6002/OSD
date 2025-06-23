# Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName       = 'Windows 11 24H2 x64'
$OSEdition    = 'Education'
$OSActivation = 'Volume'
$OSLanguage   = 'en-us'

# Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

# Copy the hash script to C:\AutoPilotHash
Write-Host "Copying Hash Script" -ForegroundColor Green

$src    = 'X:\OSDCloud\Config\Scripts\UploadHash-Entra.ps1'
$dstDir = 'C:\AutoPilotHash'
$dst    = "$dstDir\UploadHash-Entra.ps1"

if (Test-Path $src) {
    if (-not (Test-Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "Copied UploadHash-Entra.ps1 to $dstDir" -ForegroundColor Green
}
else {
    Write-Host "No UploadHash-Entra.ps1 found at $src – skipping copy." -ForegroundColor Green
}

# Create SetupComplete.cmd (runs at OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/SetupComplete.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

Write-Host "Restarting" -ForegroundColor Green
