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
Set-Location -Path "X:\OSDCloud\Config\Scripts"
& "X:\OSDCloud\Config\Scripts\oa3tool.exe" /Report /ConfigFile="X:\OSDCloud\Config\Scripts\OA3.cfg" /NoKeyCheck

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
} else {

    $msg = "$(Get-Date -Format o) - ERROR: Hash file not found at $hashFile"
    Write-Host $msg -ForegroundColor Yellow
}

# Pure PowerShell NTP query against time.windows.com and set system time
function Get-NtpTime {
    param(
        [string] $Server = 'time.windows.com'
    )
    # NTP runs on UDP port 123
    $endpoint = New-Object Net.IPEndPoint ([Net.IPAddress]::Parse((Resolve-DnsName $Server -Type A).IPAddress)), 123
    $socket   = New-Object Net.Sockets.UdpClient
    $socket.Connect($endpoint)
    $socket.Client.ReceiveTimeout = 3000
    
    # Build request packet (48 bytes, with first byte 0x1B)
    $ntpData = New-Object byte[] 48
    $ntpData[0] = 0x1B
    $socket.Send($ntpData, $ntpData.Length) | Out-Null
    
    # Receive response
    $response = $socket.Receive([ref]$endpoint)
    $socket.Close()
    
    # Extract transmit timestamp (bytes 40-47)
    [Array]::Reverse($response, 40, 4)
    [Array]::Reverse($response, 44, 4)
    $intPart  = [BitConverter]::ToUInt32($response, 40)
    $fracPart = [BitConverter]::ToUInt32($response, 44)
    $milliseconds = ($intPart * 1000) + (($fracPart * 1000) / 0x100000000)
    
    # Convert to DateTime (NTP epoch is 1900-01-01)
    return (Get-Date '1900-01-01').AddMilliseconds($milliseconds)
}

# Upload the hash
Start-Sleep 3

# Retrieve NTP time and set system clock
Write-Host "Fetching time from time.windows.com..."  -ForegroundColor Green
$DateTime = Get-NtpTime -Server 'time.windows.com'
Write-Host "NTP time: $DateTime"  -ForegroundColor Green
Set-Date -Date $DateTime
Write-Host "System clock updated."  -ForegroundColor Green

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
