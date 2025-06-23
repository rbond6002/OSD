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
# Cleanup AutoPilotHash folder
If (Test-Path -Path 'C:\AutoPilotHash') {
    Remove-Item -Path 'C:\AutoPilotHash' -Recurse -Force -Verbose
}

# Stop logging
Stop-Transcript
