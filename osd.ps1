# OSD config

Write-Host -ForegroundColor Green "Starting OSDCloud lite touch (confirm erase disk)"

Start-OSDCloud -OSName 'Windows 11 24H2' -OSLanguage en-us -OSEdition Education -OSActivation Volume -Restart
