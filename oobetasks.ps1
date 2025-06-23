 # oobetasks

$scriptFolderPath   = "$env:SystemDrive\OSDCloud\Scripts"
$ScriptPathOOBE     = Join-Path -Path $scriptFolderPath -ChildPath "OOBE.ps1"
$ScriptPathSendKeys = Join-Path -Path $scriptFolderPath -ChildPath "SendKeys.ps1"

# Ensure script folder exists
If (!(Test-Path -Path $scriptFolderPath)) {
    New-Item -Path $scriptFolderPath -ItemType Directory -Force | Out-Null
}

# Build OOBE script content
$OOBEScript = @"
`$Global:Transcript = "`$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OOBEScripts.log"
Start-Transcript -Path (Join-Path "`$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD\" `$Global:Transcript) -ErrorAction Ignore | Out-Null

# Run Autopilot hash upload
Write-Host -ForegroundColor DarkGray "Running UploadHash-Entra.ps1"
Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\AutoPilotHash\UploadHash-Entra.ps1"' -Wait

# Cleanup scheduled tasks
Write-Host -ForegroundColor DarkGray "Unregistering Scheduled Tasks"
Unregister-ScheduledTask -TaskName "Scheduled Task for SendKeys" -Confirm:`$false
Unregister-ScheduledTask -TaskName "Scheduled Task for OSDCloud post installation" -Confirm:`$false

# Restart to continue installation
Write-Host -ForegroundColor DarkGray "Restarting Computer"
Start-Process PowerShell -ArgumentList '-NoProfile -Command "Restart-Computer -Force"' -Wait

Stop-Transcript | Out-Null
"@

# Write OOBE.ps1
Out-File -FilePath $ScriptPathOOBE -InputObject $OOBEScript -Encoding Ascii

# Build SendKeys script content
$SendKeysScript = @"
`$Global:Transcript = "`$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-SendKeys.log"
Start-Transcript -Path (Join-Path "`$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD\" `$Global:Transcript) -ErrorAction Ignore | Out-Null

Write-Host -ForegroundColor DarkGray "Stop Debug-Mode (SHIFT + F10) with WscriptShell.SendKeys"
`$WscriptShell = New-Object -ComObject Wscript.Shell

# ALT + TAB
Write-Host -ForegroundColor DarkGray "SendKeys: ALT + TAB"
`$WscriptShell.SendKeys("%({TAB})")
Start-Sleep -Seconds 1

# SHIFT + F10
Write-Host -ForegroundColor DarkGray "SendKeys: SHIFT + F10"
`$WscriptShell.SendKeys("+({F10})")

Stop-Transcript | Out-Null
"@

# Write SendKeys.ps1
Out-File -FilePath $ScriptPathSendKeys -InputObject $SendKeysScript -Encoding Ascii

# Download ServiceUI executable
Write-Host -ForegroundColor Gray "Download ServiceUI.exe from GitHub Repo"
Invoke-WebRequest -Uri "https://github.com/AkosBakos/Tools/raw/main/ServiceUI64.exe" -OutFile "C:\OSDCloud\ServiceUI.exe"

# Create Scheduled Task for SendKeys
$taskName      = "Scheduled Task for SendKeys"
$service       = New-Object -ComObject 'Schedule.Service'
$service.Connect()
$taskDef       = $service.NewTask(0)
$taskDef.RegistrationInfo.Description = $taskName
$taskDef.Settings.Enabled            = $true
$taskDef.Settings.AllowDemandStart   = $true

# Logon trigger with 15s delay
enabledTrigger = $taskDef.Triggers.Create(9)
enabledTrigger.Delay   = 'PT15S'
enabledTrigger.Enabled = $true

action = $taskDef.Actions.Create(0)
action.Path      = 'C:\OSDCloud\ServiceUI.exe'
action.Arguments = '-process:RuntimeBroker.exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -File "' + $ScriptPathSendKeys + '"'

$rootFolder = $service.GetFolder("\")
$rootFolder.RegisterTaskDefinition($taskName, $taskDef, 6, "SYSTEM", $null, 5)

# Create Scheduled Task for OSDCloud post installation
$taskName = "Scheduled Task for OSDCloud post installation"
$service  = New-Object -ComObject 'Schedule.Service'
$service.Connect()
$taskDef  = $service.NewTask(0)
$taskDef.RegistrationInfo.Description = $taskName
$taskDef.Settings.Enabled            = $true
$taskDef.Settings.AllowDemandStart   = $true

# Logon trigger with 20s delay
enabledTrigger = $taskDef.Triggers.Create(9)
enabledTrigger.Delay   = 'PT20S'
enabledTrigger.Enabled = $true

action = $taskDef.Actions.Create(0)
action.Path      = 'C:\OSDCloud\ServiceUI.exe'
action.Arguments = '-process:RuntimeBroker.exe "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -File "' + $ScriptPathOOBE + '"'

$rootFolder.RegisterTaskDefinition($taskName, $taskDef, 6, "SYSTEM", $null, 5)
 
