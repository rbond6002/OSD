#OSDCloud Variables
$OSName      = 'Windows 11 24H2 x64'
$OSEdition   = 'Education'
$OSActivation= 'Volume'
$OSLanguage  = 'en-us'

$GroupTag = [Environment]::GetEnvironmentVariable('GrouptagID','Machine') 

Write-Host $GroupTag

Write-Host 'Manufacturer:' $Win32ComputerSystem.Manufacturer
Write-Host 'Model:' $Win32ComputerSystem.Model

# Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Afterwards, it will add the device to Autopilot, Group Tag it ($GroupTag), and wait for a deployment profile to be assigned." -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart


$Win32ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property *

if ($Win32ComputerSystem.Manufacturer -like "*Microsoft*") {
    Write-Host "Move drivers for Surface"
    $target = "C:\OSDCloud\Drivers"

    Try {
        # Ensure the target directory exists
        if (!(Test-Path -Path $target)) {
            New-Item -Path $target -ItemType Directory -Force | Out-Null
            Write-Host "Target directory created: $target"
        }

        # Move all .msi files from source to target
        Move-Item -Path "C:\Drivers\*.msi" -Destination $target -Force -ErrorAction Stop
        Write-Host "Driver package(s) successfully moved to: $target"
    } Catch {
        Write-Warning "Failed to move driver package(s): $_"
    }
}

Write-Host "Copying PFX file & the import script"
Copy-Item X:\OSDCloud\Config\Scripts C:\OSDCloud\ -Recurse -Force

# Cleanup Content
$cleanupContent = @'
# Start logging
Start-Transcript -Path "$env:ProgramData\Logs\Management\$(Get-Date -Format yyyy-MM-dd-HHmm)-Deploy-OOBE.log"

# Move OSDCloud Logs
If (Test-Path -Path 'C:\OSDCloud\Logs') {
    Move-Item 'C:\OSDCloud\Logs\*' -Destination "$env:ProgramData\Logs\Management" -Force -Verbose
}

# Cleanup directories
If (Test-Path -Path 'C:\OSDCloud') {
    Remove-Item -Path 'C:\OSDCloud' -Recurse -Force -Verbose
}
If (Test-Path -Path 'C:\Drivers') {
    Remove-Item -Path 'C:\Drivers' -Recurse -Force -Verbose
}

# Stop logging
Stop-Transcript
'@

# Destination for the Cleanup script
$destPath = "C:\Windows\Setup\Scripts\cleanup.ps1"
$cleanupContent | Out-File -FilePath $destPath -Encoding ascii -Force

# Surface Driver Content
$surfaceDriverContent = @'
$driverFolder = "C:\OSDCloud\Drivers"
$logPath      = "C:\OSDCloud\DriverPack.log"

# Attempt to locate the first .msi driver package
$driverPackage = Get-ChildItem -Path "$driverFolder\*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($driverPackage) {
    $driverPath = $driverPackage.FullName

    Write-Host "Driver package found: $driverPath"
    Write-Host "Starting installation via ServiceUI. Log file: $logPath"

    try {
        Start-Process -FilePath "msiexec.exe" `
                      -ArgumentList "/i `"$driverPath`" /qn /norestart /l*v `"$logPath`"" `
                      -Wait -ErrorAction Stop

        Write-Host "Driver package installed successfully."
    } catch {
        Write-Warning "Driver installation failed: $_"
    }
} else {
    Write-Host "No driver package found in $driverFolder."
}
'@

# Destination for the Surface Driver script
$surfaceDriverdestPath = "C:\Windows\Setup\Scripts\surfaceDriverInstall.ps1"
$surfaceDriverContent | Out-File -FilePath $surfaceDriverdestPath -Encoding ascii -Force

# Create SetupComplete.cmd (runs at OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\cleanup.ps1
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

# Build Unattend.xml with static path import & cleanup, with group tag variable
$UnattendXml = @"
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
          <Description>Try Surface Driver Install</Description>
          <Path>PowerShell -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\surfaceDriverInstall.ps1</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Description>Start Hash Import</Description>
          <Path>PowerShell -ExecutionPolicy Bypass -File C:\OSDCloud\Scripts\AutoHash-var.ps1 -GroupTag $GroupTag</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Description>Run SetupComplete Command</Description>
          <Path>cmd /c C:\Windows\Setup\Scripts\SetupComplete.cmd</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
"@

# Ensure Panther folder and write Unattend.xml
if (-not (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther' -ItemType Directory -Force | Out-Null
}
$Panther      = 'C:\Windows\Panther'
$UnattendPath = Join-Path $Panther 'Unattend.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

Write-Host "Restarting" -ForegroundColor Green
