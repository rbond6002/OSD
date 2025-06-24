# Define OS parameters
$OSName      = 'Windows 11 24H2 x64'
$OSEdition   = 'Education'
$OSActivation= 'Volume'
$OSLanguage  = 'en-us'

# Retrieve stored credentials from Machine environment
$TenantID   = [Environment]::GetEnvironmentVariable('OSDCloudAPTenantID','Machine')  # $env:OSDCloudAPTenantID doesn't work within WinPE
$AppID      = [Environment]::GetEnvironmentVariable('OSDCloudAPAppID','Machine')
$AppSecret  = [Environment]::GetEnvironmentVariable('OSDCloudAPAppSecret','Machine')

# Echo values for verification
Write-Host "TenantID:   $TenantID"
Write-Host "AppID:      $AppID"
Write-Host "AppSecret:  $AppSecret"

# Define your tags
$groupTags = @(
    'Entra-ENG-Faculty',
    'Entra-000-Faculty',
    'Entra-010-Faculty',
    'Entra-013-Faculty'
)

# Pop up a one-column GridView with built-in filter/search
$GroupTag = $groupTags |
    Out-GridView `
      -Title 'Select Autopilot Group Tag' `
      -OutputMode Single

# Change to skip uploading hash if no tag selected
if (-not $GroupTag) {
    Write-Warning 'No Group Tag selected. Exiting.'
    Stop-Transcript
    exit 1
}

# Remaining script operations...
$oa3tool = 'https://github.com/rbond6002/OSD/raw/refs/heads/main/oa3tool.exe'
$pcpksp  = 'https://github.com/rbond6002/OSD/raw/refs/heads/main/PCPKsp.dll'
$inputxml= 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/input.xml'
$oa3cfg  = 'https://raw.githubusercontent.com/rbond6002/OSD/refs/heads/main/OA3.cfg'

Invoke-WebRequest $oa3tool  -OutFile "$PSScriptRoot\oa3tool.exe"
Invoke-WebRequest $pcpksp   -OutFile "X:\Windows\System32\PCPKsp.dll"
Invoke-WebRequest $inputxml -OutFile "$PSScriptRoot\input.xml"
Invoke-WebRequest $oa3cfg   -OutFile "$PSScriptRoot\OA3.cfg"

# Create OA3 Hash
If (Test-Path X:\Windows\System32\wpeutil.exe -and Test-Path X:\Windows\System32\PCPKsp.dll) {
    rundll32 X:\Windows\System32\PCPKsp.dll,DllInstall
}

# Change Directory so OA3Tool finds the files
Set-Location $PSScriptRoot

# Get SN from WMI
$serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber

# Run OA3Tool
& "$PSScriptRoot\oa3tool.exe" /Report /ConfigFile="$PSScriptRoot\OA3.cfg" /NoKeyCheck

# Check if Hash was found
If (Test-Path "$PSScriptRoot\OA3.xml") {
    [xml]$xmlhash = Get-Content -Path "$PSScriptRoot\OA3.xml"
    $hash     = $xmlhash.Key.HardwareHash
    $computers = @()
    $c = [PSCustomObject]@{
        'Device Serial Number' = $serial
        'Windows Product ID'     = ''
        'Hardware Hash'          = $hash
        'Group Tag'              = $GroupTag
    }
    $computers += $c
    $computers |
        Select 'Device Serial Number','Windows Product ID','Hardware Hash','Group Tag' |
        ConvertTo-Csv -NoTypeInformation |
        ForEach-Object { $_ -replace '"','' } |
        Out-File $OutputFile
}

# Upload the hash
Start-Sleep 30

# Install and import modules
Invoke-Expression (Invoke-RestMethod sandbox.osdcloud.com)
Install-Module WindowsAutoPilotIntune -SkipPublisherCheck -Force

# Connect to MS Graph using service principal
Connect-MSGraphApp -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret

# Import Autopilot CSV to Tenant
Import-AutoPilotCSV -csvFile $OutputFile

# Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

# Create SetupComplete.cmd (runs at OOBE)
Write-Host "Create C:\Windows\Setup\Scripts\SetupComplete.cmd" -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://github.com/rbond6002/OSD/blob/main/cleanup.ps1') }"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

Write-Host "Restarting" -ForegroundColor Green
