#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Education'
$OSActivation = 'Volume'
$OSLanguage = 'en-us'

Write-Host $GroupTag

$Win32ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -Property *
Write-Host 'Manufacturer:' $Win32ComputerSystem.Manufacturer
Write-Host 'Model:' $Win32ComputerSystem.Model

# Create SetupComplete.cmd
Write-Host "Create X:\OSDCloud\Config\Scripts\SetupComplete\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "%~dp0SetupComplete.ps1"
'@
$SetupCompleteCMD | Out-File -FilePath 'X:\OSDCloud\Config\Scripts\SetupComplete\SetupComplete.cmd' -Encoding ascii -Force

if ($Win32ComputerSystem.Manufacturer -like "*Microsoft*") {
# Create SetupComplete.ps1
$SetupCompletePSContent = @'
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
'@

}
else{
# Create SetupComplete.ps1
$SetupCompletePSContent = @'
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
'@
}

# Create SetupComplete.ps1
$SetupCompletePSdestPath = "X:\OSDCloud\Config\Scripts\SetupComplete\SetupComplete.ps1"
$SetupCompletePSContent | Out-File -FilePath $SetupCompletePSdestPath -Encoding ascii -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

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

Write-Host "Restarting" -ForegroundColor Green
