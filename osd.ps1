# OSD config
Write-Host -ForegroundColor Green "Starting OSDCloud lite touch (must confirm erase disk)"

Start-OSDCloud -OSName 'Windows 11 24H2 x64' -OSLanguage en-us -OSEdition Education -OSActivation Volume -Restart

# Create C:\Windows\Setup\Scripts\SetupComplete.cmd (automatically runs in OOBE)
Write-Host -ForegroundColor Green "Create C:\Windows\Setup\Scripts\SetupComplete.cmd"
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/SetupComplete.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

Write-Host -ForegroundColor Green "Restarting"
