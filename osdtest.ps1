# Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName       = 'Windows 11 24H2 x64'
$OSEdition    = 'Education'
$OSActivation = 'Volume'
$OSLanguage   = 'en-us'

# Launch OSDCloud\Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

# Copy the hash script to C:\AutoPilotHash
Write-Host "Copying Hash Script" -ForegroundColor Green
$src    = 'X:\OSDCloud\Config\Scripts\UploadHash-Entra.ps1'
$dstDir = 'C:\AutoPilotHash'
$dst    = "${dstDir}\UploadHash-Entra.ps1"

if (Test-Path $src) {
    if (-not (Test-Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "Copied UploadHash-Entra.ps1 to $dstDir" -ForegroundColor Green
} else {
    Write-Host "No UploadHash-Entra.ps1 found at $src – skipping copy." -ForegroundColor Green
}

# Create C:\Windows\Setup\Scripts\SetupComplete.cmd (automatically runs in OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/SetupComplete.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

# Build Unattend.xml with two RunSynchronous steps: import & cleanup
$UnattendXml = @"
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<unattend xmlns=\"urn:schemas-microsoft-com:unattend\">
  <settings pass=\"specialize\">
    <component name=\"Microsoft-Windows-Deployment\"
               processorArchitecture=\"amd64\"
               publicKeyToken=\"31bf3856ad364e35\"
               language=\"neutral\"
               versionScope=\"nonSxS\"
               xmlns:wcm=\"http://schemas.microsoft.com/WMIConfig/2002/State\"
               xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action=\"add\">
          <Order>1</Order>
          <Description>Start Hash Import</Description>
          <Path>PowerShell.exe -ExecutionPolicy Bypass -File \"C:\\AutoPilotHash\\UploadHash-Entra.ps1\"</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action=\"add\">
          <Order>2</Order>
          <Description>Remove AutoPilotHash Folder</Description>
          <Path>PowerShell.exe -ExecutionPolicy Bypass -Command \"Remove-Item -Path 'C:\\AutoPilotHash' -Recurse -Force\"</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
"@

# Ensure Panther folder exists
if (-not (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther' -ItemType Directory -Force | Out-Null
}

$Panther      = 'C:\Windows\Panther'
$UnattendPath = Join-Path $Panther 'Unattend.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

# Restart
Write-Host "Restarting" -ForegroundColor Green
