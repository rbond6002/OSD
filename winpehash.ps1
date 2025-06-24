# Determine script root (works whether run interactively or as .ps1)
$ScriptRoot = if ($MyInvocation.MyCommand.Path) {
    Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    (Get-Location).ProviderPath
}

# Define where to save the Autopilot hash CSV
$OutputFile = Join-Path $ScriptRoot 'AutopilotHash.csv'

# Define OS parameters
$OSName       = 'Windows 11 24H2 x64'
$OSEdition    = 'Education'
$OSActivation = 'Volume'
$OSLanguage   = 'en-us'

# Retrieve stored credentials from Machine environment (fix typo)
$TenantID   = [Environment]::GetEnvironmentVariable('OSDCloudAPTenantID','Machine')
$AppID      = [Environment]::GetEnvironmentVariable('OSDCloudAPAppID','Machine')
$AppSecret  = [Environment]::GetEnvironmentVariable('OSDCloudAPAppSecret','Machine')

# Echo values for verification
Write-Host "TenantID:  '$TenantID'"
Write-Host "AppID:     '$AppID'"
Write-Host "AppSecret: '$AppSecret'"

# Set Group Tag (skip interactive GridView in WinPE)
$GroupTag = 'Entra-ENG-Faculty'

# Copy OA3 tool, config & XML from local Scripts share (with error logging)
$scriptSource = 'X:\OSDCloud\Config\Scripts'
$filesToCopy  = @{
    'oa3tool.exe' = Join-Path $ScriptRoot 'oa3tool.exe'
    'input.xml'   = Join-Path $ScriptRoot 'input.xml'
    'OA3.cfg'     = Join-Path $ScriptRoot 'OA3.cfg'
    'PCPKsp.dll'  = 'X:\Windows\System32\PCPKsp.dll'
}

foreach ($file in $filesToCopy.Keys) {
    $src = Join-Path $scriptSource $file
    $dst = $filesToCopy[$file]

    try {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction Stop
        Write-Host "✔ Copied $file to $dst"
    } catch {
        Write-Host "✖ ERROR copying $file:`n  $_" -ForegroundColor Red
    }
}

# If both wpeutil.exe and PCPKsp.dll are present, install OA3 hash driver
if (
    (Test-Path 'X:\Windows\System32\wpeutil.exe') -and 
    (Test-Path 'X:\Windows\System32\PCPKsp.dll')
) {
    Write-Host 'Installing OA3 hash support...' -ForegroundColor Yellow
    rundll32 X:\Windows\System32\PCPKsp.dll,DllInstall
}

# Change location so OA3Tool finds the files
Set-Location $ScriptRoot

# Get serial number
$serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber
Write-Host "SerialNumber: $serial"

# Run OA3Tool to generate hardware hash
Write-Host 'Generating hardware hash...' -ForegroundColor Yellow
& (Join-Path $ScriptRoot 'oa3tool.exe') /Report /ConfigFile=(Join-Path $ScriptRoot 'OA3.cfg') /NoKeyCheck | Out-Null

# Verify and parse the resulting XML
$xmlPath = Join-Path $ScriptRoot 'OA3.xml'
if (Test-Path $xmlPath) {
    [xml]$xmlhash = Get-Content -Path $xmlPath
    $hash = $xmlhash.Key.HardwareHash

    # Build Autopilot CSV
    $c = [PSCustomObject]@{
        'Device Serial Number' = $serial
        'Windows Product ID'    = ''
        'Hardware Hash'         = $hash
        'Group Tag'             = $GroupTag
    }
    $c |
        Select-Object 'Device Serial Number','Windows Product ID','Hardware Hash','Group Tag' |
        ConvertTo-Csv -NoTypeInformation |
        ForEach-Object { $_ -replace '"','' } |
        Out-File -FilePath $OutputFile -Encoding ASCII -Force
    Write-Host "✔ Autopilot CSV written to $OutputFile"
} else {
    Write-Host "✖ OA3.xml not found at $xmlPath" -ForegroundColor Red
    exit 1
}

# Pause to ensure file is flushed
Start-Sleep -Seconds 5

# Install and import Autopilot module
Write-Host 'Installing WindowsAutoPilotIntune module...' -ForegroundColor Yellow
Invoke-Expression (Invoke-RestMethod 'https://sandbox.osdcloud.com')
Install-Module WindowsAutoPilotIntune -SkipPublisherCheck -Force -ErrorAction Stop

# Connect silently via service principal
Write-Host 'Connecting to MS Graph...' -ForegroundColor Yellow
Connect-MSGraphApp -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret -ErrorAction Stop

# Import Autopilot CSV
Write-Host 'Importing CSV into Autopilot...' -ForegroundColor Yellow
Import-AutoPilotCSV -csvFile $OutputFile -ErrorAction Stop

# Launch OSDCloud
Write-Host 'Starting OSDCloud lite touch...' -ForegroundColor Green
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

# Create SetupComplete.cmd for post-OOBE cleanup
Write-Host 'Creating SetupComplete.cmd...' -ForegroundColor Green
$SetupCompleteCMD = @'
PowerShell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
PowerShell.exe -Command "& { Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://github.com/rbond6002/OSD/raw/main/cleanup.ps1') }"
'@
$setupPath = 'C:\Windows\Setup\Scripts\SetupComplete.cmd'

# Ensure directory exists
$setupDir = Split-Path $setupPath -Parent
if (-not (Test-Path $setupDir)) {
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null
}
$SetupCompleteCMD | Out-File -FilePath $setupPath -Encoding ASCII -Force

Write-Host 'Restarting now...' -ForegroundColor Green
