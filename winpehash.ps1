# Define OS parameters
$OSName      = 'Windows 11 24H2 x64'
$OSEdition   = 'Education'
$OSActivation= 'Volume'
$OSLanguage  = 'en-us'

# Retrieve stored credentials from Proces environment
$TenantID   = [Environment]::GetEnvironmentVariable('OSDCloudAPTenantID','Machine')
$AppID      = [Environment]::GetEnvironmentVariable('OSDCloudAPAppID','Machine')
$AppSecret  = [Environment]::GetEnvironmentVariable('OSDCloudAPAppSecret','Machine')

$OutputFile = "X:\OSDCloud\Config\Scripts\AutopilotHash.csv"

# Echo values for verification
Write-Host "TenantID:   $TenantID"
Write-Host "AppID:      $AppID"
Write-Host "AppSecret:  $AppSecret"

# Pop up a one-column GridView with built-in filter/search
$GroupTag = "Entra-ENG-Faculty"

# Define source and target
$scriptSource = 'X:\OSDCloud\Config\Scripts'
# Copy PCPKsp.dll to the specified directory
Copy-Item -Path "$scriptSource\PCPKsp.dll" -Destination "X:\Windows\System32\PCPKsp.dll" -Force

# Create OA3 Hash
If (
    (Test-Path "X:\Windows\System32\wpeutil.exe") -and
    (Test-Path "X:\Windows\System32\PCPKsp.dll")
) {
    & rundll32.exe "X:\Windows\System32\PCPKsp.dll",DllInstall
}

# Get SN from WMI
$serial = (Get-WmiObject -Class Win32_BIOS).SerialNumber

# Run OA3Tool
&X:\OSDCloud\Config\Scripts\oa3tool.exe /Report /ConfigFile=X:\OSDCloud\Config\Scripts\OA3.cfg /NoKeyCheck

# Check if Hash was found
$hashFile = "X:\OSDCloud\Config\Scripts\OA3.xml"
If (Test-Path $hashFile) {

    [xml]$xmlhash = Get-Content -Path $hashFile
    $hash     = $xmlhash.Key.HardwareHash

    $c = [PSCustomObject]@{
        'Device Serial Number' = $serial
        'Windows Product ID'   = ''
        'Hardware Hash'        = $hash
        'Group Tag'            = $GroupTag
    }

    $c |
      Select 'Device Serial Number','Windows Product ID','Hardware Hash','Group Tag' |
      ConvertTo-Csv -NoTypeInformation |
      ForEach-Object { $_ -replace '"','' } |
      Out-File $OutputFile

    "$(Get-Date -Format o) - SUCCESS: Parsed hash and wrote to $OutputFile" |
      Out-File $LogFile -Append

} else {

    $msg = "$(Get-Date -Format o) - ERROR: Hash file not found at $hashFile"
    Write-Host $msg -ForegroundColor Yellow
    $msg | Out-File $LogFile -Append

}

# Upload the hash
Start-Sleep 30

# Install and import modules
Invoke-Expression (Invoke-RestMethod sandbox.osdcloud.com)
Install-Module WindowsAutoPilotIntune -SkipPublisherCheck -Force

# Connect to MS Graph using service principal
#Connect-MSGraphApp -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret

# Import Autopilot CSV to Tenant
#Import-AutoPilotCSV -csvFile $OutputFile

Install-Script -Name Get-WindowsAutopilotInfoCommunity -Force

Get-WindowsAutoPilotInfoCommunity.ps1 `
  -Online `
  -InputFile	$OutputFile`
  -GroupTag		$selectedTag `
  -Assign `
  -TenantID		$TenantID `
  -AppID		$AppID `
  -AppSecret	$AppSecret

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
