# Define OS parameters
$OSName      = 'Windows 11 24H2 x64'
$OSEdition   = 'Education'
$OSActivation= 'Volume'
$OSLanguage  = 'en-us'

# Retrieve stored credentials from Proces environment
$TenantID   = [Environment]::GetEnvironmentVariable('OSDCloudAPTenID','Machine')
$AppID      = [Environment]::GetEnvironmentVariable('OSDCloudAPAppID','Machine')
$AppSecret  = [Environment]::GetEnvironmentVariable('OSDCloudAPAppSecret','Machine')

# Echo values for verification
Write-Host "TenantID:   $TenantID"
Write-Host "AppID:      $AppID"
Write-Host "AppSecret:  $AppSecret"

# Pop up a one-column GridView with built-in filter/search
$GroupTag = "Entra-ENG-Faculty"

# Copy OA3 tool, config & XML from local Scripts share (with error logging)
$scriptSource = 'X:\OSDCloud\Config\Scripts'
$destRoot     = $PSScriptRoot
$filesToCopy  = @{
    'oa3tool.exe' = Join-Path $destRoot 'oa3tool.exe'
    'input.xml'   = Join-Path $destRoot 'input.xml'
    'OA3.cfg'     = Join-Path $destRoot 'OA3.cfg'
    'PCPKsp.dll'  = 'X:\Windows\System32\PCPKsp.dll'
}

foreach ($file in $filesToCopy.Keys) {
    $src  = Join-Path $scriptSource $file
    $dst  = $filesToCopy[$file]
    try {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction Stop
        Write-Host "Copied $file to $dst"
    } catch {
        Write-Host "ERROR: Could not copy $file from $src to $dst. $_" -ForegroundColor Red
    }
}

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
