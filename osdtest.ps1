# Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$OSName       = 'Windows 11 24H2 x64'
$OSEdition    = 'Education'
$OSActivation = 'Volume'
$OSLanguage   = 'en-us'

# Launch OSDCloud
Write-Host "Starting OSDCloud lite touch (must confirm erase disk)" -ForegroundColor Green
Write-Host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart"
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -Restart

Write-Host "Restarting" -ForegroundColor Green
