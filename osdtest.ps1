#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Education'
$OSActivation = 'Volume'
$OSLanguage = 'en-us'

#Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

Write-Host "Copying Hash Script" -ForegroundColor Green

$src = 'X:\OSDCloud\Config\Scripts\UploadHash-Entra.ps1'
$dst = 'C:\OSDCloud\UploadHash-Entra.ps1'

if (Test-Path $src) {
    Copy-Item $src $dst -Force
    Write-Host "Copied UploadHash-Entra.ps1"  -ForegroundColor Green
}
else {
	Write-Host "No UploadHash-Entra.ps1 found at $src – skipping copy."  -ForegroundColor Green
}

# Create C:\Windows\Setup\Scripts\SetupComplete.cmd (automatically runs in OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/SetupComplete.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Start Autopilot Import & Assignment Process</Description>
                    <Path>PowerShell -ExecutionPolicy Bypass C:\OSDCloud\UploadHash-Entra.ps1</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@ 

if (-NOT (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther'-ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$Panther = 'C:\Windows\Panther'
$UnattendPath = "$Panther\Unattend.xml"
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

Write-Host "Restarting" -ForegroundColor Green
