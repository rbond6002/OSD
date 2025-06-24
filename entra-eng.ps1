#OSDCloud Variables
$OSName      = 'Windows 11 24H2 x64'
$OSEdition   = 'Education'
$OSActivation= 'Volume'
$OSLanguage  = 'en-us'

# Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Afterwards, it will add the device to Autopilot with Grouptag Entra-ENG-Faculty" -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

# Copy the hash script and Auth script to C:\AutoPilotHash
Write-Host "Copying scripts to C:\AutoPilotHash" -ForegroundColor Green
$dstDir = 'C:\AutoPilotHash'
if (-not (Test-Path $dstDir)) { New-Item -Path $dstDir -ItemType Directory -Force | Out-Null }

# Copy AutoPilot.ps1
$autoSrc = 'X:\OSDCloud\Config\Scripts\AutoPilot.ps1'
$autoDst = Join-Path $dstDir (Split-Path $autoSrc -Leaf)
if (Test-Path $autoSrc) {
    Copy-Item -Path $autoSrc -Destination $autoDst -Force
    Write-Host "Copied AutoPilot.ps1 to $dstDir" -ForegroundColor Green
} else {
    Write-Host "No AutoPilot.ps1 found at $autoSrc, skipping copy." -ForegroundColor Yellow
}

# Copy Auth.ps1
$auth        = 'X:\OSDCloud\Config\Scripts\Auth.ps1'
$authDst = Join-Path $dstDir (Split-Path $auth -Leaf)
if (Test-Path $auth) {
    Copy-Item -Path $auth -Destination $authDst -Force
    Write-Host "Copied Auth.ps1 to $dstDir" -ForegroundColor Green
} else {
    Write-Host "No Auth.ps1 found at $auth, skipping copy." -ForegroundColor Yellow
}

# Create SetupComplete.cmd (runs at OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://github.com/rbond6002/OSD/blob/main/cleanup.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

# Build Unattend.xml with static path import & cleanup, with group tag variable
$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Start Hash Import</Description>
          <Path>PowerShell -ExecutionPolicy Bypass -File C:\AutoPilotHash\AutoPilot.ps1 -AuthFile C:\AutoPilotHash\Auth.ps1 -GroupTag "Entra-ENG-Faculty"</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Remove AutoPilotHash Folder</Description>
          <Path>PowerShell -ExecutionPolicy Bypass -Command "Remove-Item -Path 'C:\AutoPilotHash' -Recurse -Force"</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
'@

# Ensure Panther folder and write Unattend.xml
if (-not (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther' -ItemType Directory -Force | Out-Null
}
$Panther      = 'C:\Windows\Panther'
$UnattendPath = Join-Path $Panther 'Unattend.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

Write-Host "Restarting" -ForegroundColor Green
